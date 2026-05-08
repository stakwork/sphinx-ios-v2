//
//  AppLogger.swift
//  sphinx
//
//  Created by Sphinx on 2026-05-05.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import Foundation

// MARK: - Constants

private let kLogRetentionHours: Double = 72

// MARK: - LogLevel

enum LogLevel: String, Codable, Sendable {
    case debug   = "DEBUG"
    case info    = "INFO"
    case warning = "WARNING"
    case error   = "ERROR"
}

// MARK: - LogEntry

struct LogEntry: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String

    /// Human-readable formatted string, e.g. "[2025-05-08T07:02:13Z] [ERROR] Payment failed"
    var formatted: String {
        let ts = AppLogger.isoFormatter.string(from: timestamp)
        return "[\(ts)] [\(level.rawValue)] \(message)"
    }
}

// MARK: - AppLogger

/// Thread safety: all mutations to `entries` and file I/O are serialised on `queue`.
/// We declare `@unchecked Sendable` because we enforce the invariant ourselves.
final class AppLogger: @unchecked Sendable {

    static let shared = AppLogger()

    /// Shared ISO8601 formatter — used externally by tools that need to format/parse dates.
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// All retained log entries (last kLogRetentionHours hours).
    /// Read only from the main thread after initial load; mutated only on `queue`.
    private(set) var entries: [LogEntry] = []

    private var entryObservers: [UUID: (LogEntry) -> Void] = [:]

    private let queue = DispatchQueue(label: "com.sphinx.applogger", qos: .utility)
    private var isStarted = false

    // Pipe storage (must stay alive for the lifetime of the app)
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    // Original file descriptors so we can still write to the Xcode console
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

    /// Register a callback invoked on the main thread for every new log entry.
    /// Returns a token that must be passed to `removeObserver` to unsubscribe.
    func addObserver(_ handler: @escaping (LogEntry) -> Void) -> UUID {
        let id = UUID()
        queue.async { [weak self] in
            self?.entryObservers[id] = handler
        }
        return id
    }

    func removeObserver(_ id: UUID) {
        queue.async { [weak self] in
            self?.entryObservers.removeValue(forKey: id)
        }
    }

    /// Call as the very first thing in application(_:didFinishLaunchingWithOptions:)
    func start() {
        guard !isStarted else { return }
        isStarted = true

        loadAndPrunePersistedEntries()
        redirectStdStreams()
        registerSignalHandlers()
    }

    /// Asynchronously write the current buffer to disk — call on background/terminate.
    func flush() {
        queue.async { [weak self] in
            self?.persistEntriesToDisk()
        }
    }

    /// Synchronously write the current buffer to disk.
    func flushSync() {
        queue.sync {
            persistEntriesToDisk()
        }
    }

    /// Write the current buffer to a timestamped temp file and return its URL.
    func exportedFileURL() -> URL? {
        var result: URL?
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
                // Avoid recursion — do not call AppLogger here
                fputs("[AppLogger] exportedFileURL write error: \(error)\n", stderr)
            }
        }
        return result
    }

    /// Clear the in-memory buffer and delete the on-disk log file.
    func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            self.entries.removeAll()
            let url = self.logFileURL()
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private: Entry Management

    private func append(message: String, level: LogLevel = .info) {
        let entry = LogEntry(id: UUID(), timestamp: Date(), level: level, message: message)
        entries.append(entry)
        let observers = entryObservers
        DispatchQueue.main.async {
            observers.values.forEach { $0(entry) }
        }
    }

    private func formatEntry(_ entry: LogEntry) -> String {
        let ts = iso8601.string(from: entry.timestamp)
        return "[\(ts)] [\(entry.level.rawValue)] \(entry.message)"
    }

    // MARK: - Private: Persistence

    private func logFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent(logFileName)
    }

    private func loadAndPrunePersistedEntries() {
        queue.sync {
            let url = logFileURL()
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            let cutoff = Date().addingTimeInterval(-kLogRetentionHours * 3600)
            let retained: [LogEntry] = content
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .compactMap { parseLine($0) }
                .filter { $0.timestamp >= cutoff }
            entries = retained
        }
    }

    private func persistEntriesToDisk() {
        let url = logFileURL()
        let content = entries.map { formatEntry($0) }.joined(separator: "\n")
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Parse a formatted log line back into a `LogEntry` (best-effort).
    private func parseLine(_ line: String) -> LogEntry? {
        // Format: [2025-01-15T14:32:01Z] [INFO] <message>
        guard line.hasPrefix("[") else { return nil }
        let parts = line.components(separatedBy: "] [")
        guard parts.count >= 2 else { return nil }

        let tsStr = String(parts[0].dropFirst()) // strip leading "["
        guard let date = iso8601.date(from: tsStr) else { return nil }

        let levelAndRest = parts[1]
        guard let closingBracket = levelAndRest.firstIndex(of: "]") else { return nil }
        let levelStr = String(levelAndRest[levelAndRest.startIndex..<closingBracket])
        let level = LogLevel(rawValue: levelStr) ?? .info

        let prefix = "[\(levelStr)] "
        let message: String
        if let lastRange = line.range(of: prefix, options: .backwards) {
            message = String(line[lastRange.upperBound...])
        } else {
            message = ""
        }

        return LogEntry(id: UUID(), timestamp: date, level: level, message: message)
    }

    // MARK: - Private: stdout / stderr Redirect

    private func redirectStdStreams() {
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)

        setupPipe(for: STDOUT_FILENO, storedPipe: &stdoutPipe, original: originalStdout)
        setupPipe(for: STDERR_FILENO, storedPipe: &stderrPipe, original: originalStderr)
    }

    private func setupPipe(for fd: Int32, storedPipe: inout Pipe?, original: Int32) {
        let pipe = Pipe()
        storedPipe = pipe

        dup2(pipe.fileHandleForWriting.fileDescriptor, fd)

        let readHandle = pipe.fileHandleForReading
        let originalFD = original

        readHandle.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            // Forward to original fd so Xcode console still works
            if originalFD >= 0 {
                text.withCString { ptr in
                    _ = Darwin.write(originalFD, ptr, strlen(ptr))
                }
            }

            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            self.queue.async {
                for line in lines {
                    self.append(message: line, level: .info)
                }
            }
        }
    }

    // MARK: - Private: Signal Handlers

    private func registerSignalHandlers() {
        AppLoggerSignalBridge.logFilePath = logFileURL().path

        let handler: @convention(c) (Int32) -> Void = { signum in
            AppLoggerSignalBridge.writeCrashSentinel(signal: signum)
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

/// C-compatible helpers for signal handlers.
/// `nonisolated(unsafe)` opts the static var out of Swift 6's global-actor isolation
/// checking — it is set exactly once (at start) before any signal can fire.
enum AppLoggerSignalBridge {
    nonisolated(unsafe) static var logFilePath: String = ""

    /// Writes a crash-sentinel line using only async-signal-safe POSIX calls.
    static func writeCrashSentinel(signal signum: Int32) {
        let name: StaticString
        switch signum {
        case SIGSEGV: name = "SIGSEGV"
        case SIGABRT: name = "SIGABRT"
        case SIGILL:  name = "SIGILL"
        case SIGBUS:  name = "SIGBUS"
        case SIGFPE:  name = "SIGFPE"
        default:      name = "SIGUNKNOWN"
        }

        let sentinel = "💥 CRASH — signal \(name) (signal-safe write)\n"
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
