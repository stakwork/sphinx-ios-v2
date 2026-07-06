// SphinxErrorReporter.swift
// SphinxErrorReporter
//
// Public entry point.
// Thread-safe singleton — start() is idempotent.

import Foundation

/// Drop-in error and crash reporting SDK for Sphinx Apple apps.
///
/// Usage:
/// ```swift
/// let config = Config(
///     hiveBaseURL: URL(string: "https://hive.sphinx.chat/api")!,
///     ingestKey: "hive_...",
///     mainRepo: "stakwork/sphinx-ios-v2"
/// )
/// SphinxErrorReporter.start(config)
///
/// // Manual capture:
/// SphinxErrorReporter.capture(someError, metadata: ["key": "value"])
/// ```
public final class SphinxErrorReporter {

    // Expose Config as a member of this class so callers can write
    // `SphinxErrorReporter.Config(...)` without ambiguity between the
    // module name and this class name.
    public typealias Config = SphinxErrorReporterConfig

    // MARK: - Private state

    private static let lock = NSLock()
    private static var _config: Config?
    private static var _store: ReportStore?
    private static var _transport: Transport?

    /// Returns `true` after `start(_:)` has been called.
    public static var isStarted: Bool {
        lock.lock(); defer { lock.unlock() }
        return _config != nil
    }

    // MARK: - Public API

    /// Installs the crash handler, starts the network monitor, and flushes any
    /// reports persisted from previous sessions.
    ///
    /// Must be called **after** any existing crash reporters (e.g. Bugsnag)
    /// so that we capture and chain their handlers correctly.
    ///
    /// Calling `start` more than once is a no-op.
    public static func start(_ config: Config) {
        lock.lock()
        guard _config == nil else {
            lock.unlock()
            return
        }
        DebugLogger.isEnabled = config.debug
        _config = config
        let transport = Transport(config: config)
        let store = ReportStore(transport: transport)
        _transport = transport
        _store = store
        lock.unlock()

        DebugLogger.log("SphinxErrorReporter: starting (repo: \(config.mainRepo))")

        // Install crash handler (chains any existing handler like Bugsnag)
        CrashHandler.install(config: config, store: store)

        // Start network monitor and flush reports from previous sessions
        store.startMonitoring()

        DebugLogger.log("SphinxErrorReporter: started")
    }

    /// Manually captures a caught error and sends it to Hive.
    ///
    /// - Parameters:
    ///   - error: The error to report.
    ///   - repository: Override the default repository (org/name). Uses `Config.mainRepo` when nil.
    ///   - metadata: Optional structured metadata dictionary.
    ///   - requestContext: Optional request context dictionary.
    public static func capture(
        _ error: Error,
        repository: String? = nil,
        metadata: [String: Any]? = nil,
        requestContext: [String: Any]? = nil
    ) {
        lock.lock()
        let config = _config
        let store = _store
        lock.unlock()

        guard let config = config, let store = store else {
            DebugLogger.log("SphinxErrorReporter: capture() called before start() — ignoring")
            return
        }

        DebugLogger.log("SphinxErrorReporter: capture received")

        let callStackSymbols = Thread.callStackSymbols
        let frameBuilder = FrameBuilder(
            appModuleName: Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "sphinx",
            mainRepo: config.mainRepo
        )
        let frames = frameBuilder.build(from: callStackSymbols)

        let nsError = error as NSError
        let report = ErrorReport(
            exceptionType: nsError.domain,
            message: error.localizedDescription,
            stackTrace: callStackSymbols.joined(separator: "\n"),
            frames: frames,
            environment: config.environment,
            release: config.release,
            commitSha: config.commitSha,
            repository: repository ?? config.mainRepo,
            requestContext: requestContext,
            metadata: metadata
        )

        store.enqueue(report)
        DebugLogger.log("SphinxErrorReporter: report enqueued")
    }

    // MARK: - Internal (for testing)

    /// Resets internal state. For unit tests only.
    static func _reset() {
        lock.lock(); defer { lock.unlock() }
        _config = nil
        _store = nil
        _transport = nil
    }

    /// Returns an instance configured with a custom URLSession (for Transport mock tests).
    static func _makeStore(config: Config, session: URLSession) -> ReportStore {
        let transport = Transport(config: config, session: session)
        return ReportStore(transport: transport)
    }
}
