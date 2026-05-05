//
//  AppLogger.swift
//  sphinx
//
//  Created by Sphinx on 2026-05-05.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import Foundation

// MARK: - Constants

private let kLogRetentionHours: Double = 24

// MARK: - LogLevel

enum LogLevel: String, Codable {
    case debug   = "DEBUG"
    case info    = "INFO"
    case warning = "WARNING"
    case error   = "ERROR"
}

// MARK: - LogEntry

struct LogEntry: Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String
}

// MARK: - AppLogger

final class AppLogger {
    
    static let shared = AppLogger()
    
    /// All retained log entries (last kLogRetentionHours hours)
    private(set) var entries: [LogEntry] = []
    
    /// Called on main thread whenever a new entry is added
    var onNewEntry: ((LogEntry) -> Void)?
    
    private let queue = DispatchQueue(label: "com.sphinx.applogger", qos: .utility)
    private var isStarted = false
    
    // Pipe storage (must stay alive for the lifetime of the app)
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    
    // Original file descriptors so we can still write to Xcode console
    private var originalStdout: Int32 = -1
    private var originalStderr: Int32 = -1
    
    private let logFileName = "sphinx_logs.txt"
    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Call as the very first thing in application(_:didFinishLaunchingWithOptions:)
    func start() {
        guard !isStarted else { return }
        isStarted = true
        
        loadAndPrunePersistedEntries()
        redirectStdStreams()
        registerSignalHandlers()
    }
    
    /// Write current buffer to disk — call on background/terminate
    func flush() {
        queue.async { [weak self] in
            self?.persistEntriesToDisk()
        }
    }
    
    /// Synchronous flush — safe to call from app lifecycle hooks that need immediate write
    func flushSync() {
        queue.sync {
            persistEntriesToDisk()
        }
    }
    
    /// Write current buffer to a timestamped temp file and return its URL
    func exportedFileURL() -> URL? {
        var result: URL? = nil
        queue.sync {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let stamp = formatter.string(from: Date())
            let fileName = "sphinx_logs_\(stamp).txt"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            let content = entries.map { formatEntry($0) }.joined(separator: "\n")
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                result = url
            } catch {
                // Can't use AppLogger here to avoid recursion
                print("[AppLogger] exportedFileURL write error: \(error)")
            }
        }
        return result
    }
    
    /// Clear in-memory buffer and delete the on-disk log file
    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.entries.removeAll()
            let url = self.logFileURL()
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Private: Entry Management
    
    private func append(message: String, level: LogLevel = .info) {
        let entry = LogEntry(id: UUID(), timestamp: Date(), level: level, message: message)
        entries.append(entry)
        DispatchQueue.main.async { [weak self] in
            self?.onNewEntry?(entry)
        }
    }
    
    private func formatEntry(_ entry: LogEntry) -> String {
        let ts = iso8601.string(from: entry.timestamp)
        return "[\(ts)] [\(entry.level.rawValue)] \(entry.message)"
    }
    
    // MARK: - Private: Persistence
    
    private func logFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent(logFileName)
    }
    
    private func loadAndPrunePersistedEntries() {
        queue.sync {
            let url = logFileURL()
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            let cutoff = Date().addingTimeInterval(-kLogRetentionHours * 3600)
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            let retained: [LogEntry] = lines.compactMap { parseLine($0) }.filter { $0.timestamp >= cutoff }
            entries = retained
        }
    }
    
    private func persistEntriesToDisk() {
        let url = logFileURL()
        let content = entries.map { formatEntry($0) }.joined(separator: "\n")
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Parse a formatted log line back into a LogEntry (best-effort)
    private func parseLine(_ line: String) -> LogEntry? {
        // Format: [2025-01-15T14:32:01Z] [INFO] <message>
        guard line.hasPrefix("[") else { return nil }
        let parts = line.components(separatedBy: "] [")
        guard parts.count >= 2 else { return nil }
        let tsStr = String(parts[0].dropFirst()) // remove leading "["
        guard let date = iso8601.date(from: tsStr) else { return nil }
        
        // Second part is "LEVEL] rest of message"
        let levelAndRest = parts[1]
        guard let closingBracket = levelAndRest.firstIndex(of: "]") else { return nil }
        let levelStr = String(levelAndRest[levelAndRest.startIndex..<closingBracket])
        let level = LogLevel(rawValue: levelStr) ?? .info
        
        // Message follows "] " after the level bracket
        let afterLevel = line.range(of: "[\(levelStr)] ")
        let message: String
        if let range = afterLevel, let lastRange = line.range(of: "[\(levelStr)] ", options: .backwards) {
            message = String(line[lastRange.upperBound...])
        } else {
            message = ""
        }
        
        return LogEntry(id: UUID(), timestamp: date, level: level, message: message)
    }
    
    // MARK: - Private: stdout/stderr Redirect
    
    private func redirectStdStreams() {
        // Save originals so we can still forward to Xcode console
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)
        
        setupPipe(for: STDOUT_FILENO, storedPipe: &stdoutPipe, original: originalStdout)
        setupPipe(for: STDERR_FILENO, storedPipe: &stderrPipe, original: originalStderr)
    }
    
    private func setupPipe(for fd: Int32, storedPipe: inout Pipe?, original: Int32) {
        let pipe = Pipe()
        storedPipe = pipe
        
        // Replace the file descriptor with the write end of the pipe
        dup2(pipe.fileHandleForWriting.fileDescriptor, fd)
        
        // Read from the read end on a background thread
        let readHandle = pipe.fileHandleForReading
        let originalFD = original
        readHandle.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            
            // Forward to original fd (Xcode console) if available
            if originalFD >= 0 {
                _ = text.withCString { ptr in
                    Darwin.write(originalFD, ptr, strlen(ptr))
                }
            }
            
            // Split into individual lines and log each
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines {
                self.queue.async {
                    self.append(message: line, level: .info)
                }
            }
        }
    }
    
    // MARK: - Private: Signal Handlers
    
    private func registerSignalHandlers() {
        // Store the log file path as a C string in a global so the signal handler can use it
        let url = logFileURL()
        AppLoggerSignalBridge.logFilePath = url.path
        
        let handler: @convention(c) (Int32) -> Void = { signum in
            AppLoggerSignalBridge.writeCrashSentinel(signal: signum)
            // Reset to default and re-raise so the OS can handle it normally
            signal(signum, SIG_DFL)
            raise(signum)
        }
        
        signal(SIGSEGV, handler)
        signal(SIGABRT, handler)
        signal(SIGILL,  handler)
        signal(SIGBUS,  handler)
        signal(SIGFPE,  handler)
    }
}

// MARK: - Signal-Safe Bridge

/// C-compatible bridge for signal handlers (no Swift runtime calls allowed inside a signal handler)
enum AppLoggerSignalBridge {
    // File path stored as a static C string — set once before any crash can happen
    static var logFilePath: String = ""
    
    /// Writes a crash sentinel line using only async-signal-safe syscalls
    static func writeCrashSentinel(signal signum: Int32) {
        let name: String
        switch signum {
        case SIGSEGV: name = "SIGSEGV"
        case SIGABRT: name = "SIGABRT"
        case SIGILL:  name = "SIGILL"
        case SIGBUS:  name = "SIGBUS"
        case SIGFPE:  name = "SIGFPE"
        default:      name = "SIG\(signum)"
        }
        
        // Build sentinel string — avoid Swift stdlib where possible
        let sentinel = "💥 CRASH — signal \(name) at \(ISO8601DateFormatter().string(from: Date()))\n"
        
        // Open the log file in append mode using POSIX open (async-signal-safe)
        let fd = logFilePath.withCString { path in
            Darwin.open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        }
        guard fd >= 0 else { return }
        sentinel.withCString { ptr in
            _ = Darwin.write(fd, ptr, strlen(ptr))
        }
        Darwin.close(fd)
    }
}
