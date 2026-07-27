// CrashHandler.swift
// SphinxErrorReporter
//
// Installs NSSetUncaughtExceptionHandler and signal handlers.
// Chains any previously-installed handlers to coexist with Bugsnag and others.
// On crash: builds ErrorReport, persists synchronously, then re-raises/chains.

import Foundation

// MARK: - Helpers

// Function types can't conform to Equatable in Swift, so compare C signal
// handler pointers by their raw bit pattern instead of using == / !=.
private func signalPtrEqual(
    _ lhs: (@convention(c) (Int32) -> Void)?,
    _ rhs: (@convention(c) (Int32) -> Void)?
) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none): return true
    case (.some(let l), .some(let r)):
        return unsafeBitCast(l, to: UInt.self) == unsafeBitCast(r, to: UInt.self)
    default: return false
    }
}

// MARK: - Signal handler C context (signal-handler safe — no heap allocation)

private struct SignalContext {
    // C function pointer to previously installed handler for each signal
    static var previousSIGABRT: (@convention(c) (Int32) -> Void)? = nil
    static var previousSIGILL:  (@convention(c) (Int32) -> Void)? = nil
    static var previousSIGSEGV: (@convention(c) (Int32) -> Void)? = nil
    static var previousSIGFPE:  (@convention(c) (Int32) -> Void)? = nil
    static var previousSIGBUS:  (@convention(c) (Int32) -> Void)? = nil
    static var previousSIGTRAP: (@convention(c) (Int32) -> Void)? = nil
}

// MARK: - CrashHandler

final class CrashHandler {

    // Static references — signal handlers can't capture self
    private static var sharedStore: ReportStore?
    private static var sharedConfig: Config?
    private static var previousExceptionHandler: NSUncaughtExceptionHandler?

    // MARK: - Install

    static func install(config: Config, store: ReportStore) {
        sharedConfig = config
        sharedStore = store

        // Capture existing handlers before overwriting
        previousExceptionHandler = NSGetUncaughtExceptionHandler()

        // Install our exception handler
        NSSetUncaughtExceptionHandler { exception in
            CrashHandler.handleException(exception)
        }

        // Install signal handlers
        installSignalHandler(SIGABRT, previous: &SignalContext.previousSIGABRT)
        installSignalHandler(SIGILL,  previous: &SignalContext.previousSIGILL)
        installSignalHandler(SIGSEGV, previous: &SignalContext.previousSIGSEGV)
        installSignalHandler(SIGFPE,  previous: &SignalContext.previousSIGFPE)
        installSignalHandler(SIGBUS,  previous: &SignalContext.previousSIGBUS)
        installSignalHandler(SIGTRAP, previous: &SignalContext.previousSIGTRAP)

        DebugLogger.log("CrashHandler: installed (chaining \(previousExceptionHandler != nil ? "existing" : "no") prior exception handler)")
    }

    // MARK: - Exception handler

    private static func handleException(_ exception: NSException) {
        DebugLogger.log("CrashHandler: caught uncaught exception '\(exception.name.rawValue)'")

        if let config = sharedConfig, let store = sharedStore {
            let callStackSymbols = exception.callStackSymbols
            let callStackAddresses = exception.callStackReturnAddresses

            let frameBuilder = FrameBuilder(
                appModuleName: appModuleName(),
                mainRepo: config.mainRepo
            )
            let frames = frameBuilder.build(from: callStackSymbols)
            let rawContext = RawCrashContext.capture(
                callStackReturnAddresses: callStackAddresses,
                rawSymbols: callStackSymbols
            )

            var stackTrace = callStackSymbols.joined(separator: "\n")
            stackTrace += "\n\n" + rawContext.asReadableStackTrace()

            var metadata = rawContext.asMetadata()
            metadata["exceptionUserInfo"] = exception.userInfo?.description ?? ""

            let report = ErrorReport(
                exceptionType: exception.name.rawValue,
                message: exception.reason ?? exception.name.rawValue,
                stackTrace: stackTrace,
                frames: frames,
                environment: config.environment,
                release: config.release,
                commitSha: config.commitSha,
                repository: config.mainRepo,
                metadata: metadata
            )

            // Synchronous persist — we are about to die
            try? store.persistSync(report)
            DebugLogger.log("CrashHandler: crash report persisted to disk")
        }

        // Chain to previously-installed handler (e.g. Bugsnag)
        previousExceptionHandler?(exception)
    }

    // MARK: - Signal handlers

    private static func installSignalHandler(
        _ sig: Int32,
        previous: inout (@convention(c) (Int32) -> Void)?
    ) {
        let old = signal(sig, handleSignal)
        if !signalPtrEqual(old, SIG_DFL) && !signalPtrEqual(old, SIG_IGN) && !signalPtrEqual(old, SIG_ERR) {
            previous = old
        }
    }

    // C-compatible signal handler
    private static let handleSignal: @convention(c) (Int32) -> Void = { sig in
        DebugLogger.log("CrashHandler: caught signal \(sig)")

        if let config = sharedConfig, let store = sharedStore {
            let callStackSymbols = Thread.callStackSymbols
            let callStackAddresses = Thread.callStackReturnAddresses

            let frameBuilder = FrameBuilder(
                appModuleName: appModuleName(),
                mainRepo: config.mainRepo
            )
            let frames = frameBuilder.build(from: callStackSymbols)
            let rawContext = RawCrashContext.capture(
                callStackReturnAddresses: callStackAddresses as [NSNumber],
                rawSymbols: callStackSymbols
            )

            let sigName = signalName(sig)
            var stackTrace = callStackSymbols.joined(separator: "\n")
            stackTrace += "\n\n" + rawContext.asReadableStackTrace()

            let report = ErrorReport(
                exceptionType: "Signal/\(sigName)",
                message: "Fatal signal \(sigName) (\(sig))",
                stackTrace: stackTrace,
                frames: frames,
                environment: config.environment,
                release: config.release,
                commitSha: config.commitSha,
                repository: config.mainRepo,
                metadata: rawContext.asMetadata()
            )

            try? store.persistSync(report)
        }

        // Re-raise to let the OS + chained handlers (Bugsnag) do their work
        // First restore default handler, then re-raise so the process terminates normally
        chainSignal(sig)
    }

    private static func chainSignal(_ sig: Int32) {
        var action = sigaction()
        action.__sigaction_u.__sa_handler = SIG_DFL
        sigemptyset(&action.sa_mask)
        action.sa_flags = 0
        sigaction(sig, &action, nil)

        // Call previous C handler if one existed
        let previous: (@convention(c) (Int32) -> Void)?
        switch sig {
        case SIGABRT: previous = SignalContext.previousSIGABRT
        case SIGILL:  previous = SignalContext.previousSIGILL
        case SIGSEGV: previous = SignalContext.previousSIGSEGV
        case SIGFPE:  previous = SignalContext.previousSIGFPE
        case SIGBUS:  previous = SignalContext.previousSIGBUS
        case SIGTRAP: previous = SignalContext.previousSIGTRAP
        default:      previous = nil
        }
        if let prev = previous {
            prev(sig)
        } else {
            kill(getpid(), sig)
        }
    }

    // MARK: - Helpers

    private static func appModuleName() -> String {
        return Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "sphinx"
    }

    private static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGILL:  return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE:  return "SIGFPE"
        case SIGBUS:  return "SIGBUS"
        case SIGTRAP: return "SIGTRAP"
        default:      return "SIG\(sig)"
        }
    }
}
