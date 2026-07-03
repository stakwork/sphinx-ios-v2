// FrameBuilder.swift
// SphinxErrorReporter
//
// Parses Thread.callStackSymbols into [Frame].
// Classifies inApp by comparing binary image names against the main executable.
// Produces repo-relative filename for app frames.

import Foundation

/// Parses symbolicated or unsymbolicated call stack strings into `[Frame]`.
struct FrameBuilder {

    /// The module name of the host application's main executable (e.g. "sphinx").
    let appModuleName: String
    /// The repository name used to strip source-root prefixes from filenames (e.g. "sphinx-ios-v2").
    let mainRepo: String

    // MARK: - Public API

    /// Parses `Thread.callStackSymbols` and returns frames, or `nil` if no frames could be resolved.
    /// Caller MUST omit `frames` from the report when this returns nil or empty.
    func build(from callStackSymbols: [String]) -> [Frame]? {
        let frames = callStackSymbols.compactMap { parseSymbol($0) }
        return frames.isEmpty ? nil : frames
    }

    // MARK: - Parsing

    /// Parses a single line from `Thread.callStackSymbols`.
    ///
    /// Debug format:  `0   sphinx   0x0000000100abc123 -[SomeClass method:] + 42`
    /// Stripped:      `0   sphinx   0x0000000100abc123 0x100000000 + 12345`
    private func parseSymbol(_ line: String) -> Frame? {
        // Split on 2+ spaces to get: [frameIndex, binaryName, address, symbolParts...]
        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 4 else { return nil }

        let binaryName = parts[1]
        let symbolParts = parts.dropFirst(3).joined(separator: " ")

        // Determine if this is an app frame
        let isAppFrame = binaryName == appModuleName

        // Try to parse a debug-symbolicated symbol: contains non-hex function name
        let isSymbolicated = isSymbolicatedSymbol(symbolParts)

        if isSymbolicated {
            // Extract function name (everything before " + offset")
            let functionName = extractFunctionName(from: symbolParts)
            // For app frames, attempt filename/line extraction (rare in callStackSymbols but handle if present)
            return Frame(
                filename: isAppFrame ? repoRelativeFilename(for: functionName) : binaryName,
                function: functionName,
                lineno: nil,
                inApp: isAppFrame ? true : false
            )
        } else {
            // Unsymbolicated / stripped — raw address only
            // Still emit a frame so RawCrashContext can capture the address
            let address = parts[2]
            return Frame(
                filename: isAppFrame ? "\(appModuleName)/\(address)" : "\(binaryName)/\(address)",
                function: nil,
                lineno: nil,
                inApp: isAppFrame ? true : false
            )
        }
    }

    /// Returns `true` when the symbol string appears to contain a real function name
    /// (not just a raw hex address like `0x100000000`).
    private func isSymbolicatedSymbol(_ symbol: String) -> Bool {
        // A raw (unsymbolicated) frame looks like: "0x100abc123 + 12345"
        // A symbolicated frame contains actual function/method names
        let trimmed = symbol.trimmingCharacters(in: .whitespaces)
        // If the first token is a pure hex number, it's unsymbolicated
        let firstToken = trimmed.components(separatedBy: .whitespaces).first ?? ""
        let hexPattern = "^0x[0-9a-fA-F]+$"
        if let _ = firstToken.range(of: hexPattern, options: .regularExpression) {
            return false
        }
        return !trimmed.isEmpty
    }

    /// Extracts the function name by stripping the " + offset" suffix.
    private func extractFunctionName(from symbol: String) -> String {
        // Pattern: "SomeName + 42" or just "SomeName"
        if let plusRange = symbol.range(of: " + ", options: .backwards) {
            return String(symbol[symbol.startIndex..<plusRange.lowerBound])
        }
        return symbol
    }

    /// Converts a function name or symbol to a best-effort repo-relative path.
    /// For debug builds, `callStackSymbols` doesn't include source file paths —
    /// we produce a module-relative reference from the function name.
    private func repoRelativeFilename(for functionName: String) -> String {
        // In debug builds we have mangled/demangled names like:
        //   "sphinx.ClassName.methodName() -> ()"
        // Strip the module prefix if present
        let modulePrefix = "\(appModuleName)."
        if functionName.hasPrefix(modulePrefix) {
            return String(functionName.dropFirst(modulePrefix.count))
        }
        return functionName
    }
}

// MARK: - System image classification helper

extension FrameBuilder {
    /// Known system/framework binary name prefixes. Frames from these are `inApp: false`.
    private static let systemPrefixes: [String] = [
        "libswift", "libdispatch", "libsystem", "libobjc",
        "CoreFoundation", "Foundation", "UIKit", "AppKit",
        "CFNetwork", "Security", "QuartzCore", "libBacktraceRecording"
    ]

    static func isSystemBinary(_ name: String) -> Bool {
        systemPrefixes.contains(where: { name.hasPrefix($0) })
    }
}
