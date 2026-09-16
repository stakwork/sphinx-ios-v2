// CrashHandler.swift
// SphinxErrorReporter
//
// NSException handler remains Swift (not a signal). Fatal signals are owned by
// the C trampoline (CrashSignalTrampoline) installed via sigaction.
// The trampoline writes only the interrupted PC to a pre-opened dump fd.

import Foundation
import CrashSignalTrampoline

#if canImport(Darwin)
import Darwin
#endif

final class CrashHandler {

    private static var sharedStore: ReportStore?
    private static var sharedConfig: Config?
    private static var previousExceptionHandler: NSUncaughtExceptionHandler?

    // MARK: - Install

    static func install(config: Config, store: ReportStore) {
        sharedConfig = config
        sharedStore = store

        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            CrashHandler.handleException(exception)
        }

        // Preallocate image table + dump fd BEFORE installing the C handler.
        // Do not chain any previously-installed Swift `signal()` closures
        // (AppLogger). CrashHandler owns these signals exclusively.
        prepareDumpFileAndImageTable()
        sphx_crash_install_handlers()

        DebugLogger.log("CrashHandler: installed C trampoline via sigaction")
    }

    // MARK: - Exception handler (not a signal — Foundation is legal)

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

            try? store.persistSync(report)
            DebugLogger.log("CrashHandler: crash report persisted to disk")
        }

        previousExceptionHandler?(exception)
    }

    // MARK: - Signal-safe setup (process context, not the handler)

    private static func prepareDumpFileAndImageTable() {
        sphx_crash_reset_state()
        sphx_crash_clear_images()

        let images = RawCrashContext.captureLoadedImages()
        for image in images {
            let baseName = RawCrashContext.binaryBaseName(image.name)
            _ = baseName.withCString { namePtr in
                image.uuid.withCString { uuidPtr in
                    sphx_crash_add_image(
                        namePtr,
                        uuidPtr,
                        UInt64(image.loadAddress),
                        UInt64(image.size)
                    )
                }
            }
        }

        guard let url = CrashDump.fileURL() else { return }
        // Recovery already consumed any previous-session dump. Unlink leftovers
        // (e.g. empty dump from the last install) so O_EXCL can succeed.
        try? FileManager.default.removeItem(at: url)
        let fd = url.path.withCString { pathPtr in
            open(pathPtr, O_CREAT | O_EXCL | O_RDWR, 0o600)
        }
        if fd >= 0 {
            sphx_crash_set_dump_fd(fd)
        }
    }

    static func appModuleName() -> String {
        Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "sphinx"
    }
}
