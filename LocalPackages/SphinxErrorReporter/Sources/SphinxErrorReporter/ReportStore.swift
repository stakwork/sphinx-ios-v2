// ReportStore.swift
// SphinxErrorReporter
//
// Persists ErrorReports to disk and flushes them to Transport.
// Uses a serial background queue for all operations.
// Monitors network reachability via NWPathMonitor for auto-flush on reconnect.
// Fails silently — never throws or crashes the host app.

import Foundation
import Network

final class ReportStore {

    // MARK: - Configuration

    /// Maximum delivery attempts per report before it is abandoned.
    private static let maxRetries = 5
    /// Base delay for exponential back-off between retries (seconds).
    private static let baseRetryDelay: Double = 2.0
    /// Subdirectory name under Application Support for persisted reports.
    private static let storageSubdirectory = "com.sphinx.error-reporter/pending"

    // MARK: - State

    private let transport: Transport
    private let queue = DispatchQueue(label: "com.sphinx.error-reporter.store", qos: .utility)
    private let monitor = NWPathMonitor()
    private var isOnline: Bool = false

    // MARK: - Init

    init(transport: Transport) {
        self.transport = transport
    }

    // MARK: - Public API

    /// Enqueues a report: persists it to disk then immediately attempts delivery.
    func enqueue(_ report: ErrorReport) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let url = try self.persist(report)
                DebugLogger.log("ReportStore: enqueued report at \(url.lastPathComponent)")
                self.attemptDelivery(reportURL: url, report: report, attempt: 1)
            } catch {
                DebugLogger.log("ReportStore: failed to persist report — \(error.localizedDescription)")
            }
        }
    }

    /// Synchronously persists a report to disk. Used by CrashHandler (signal context).
    /// Returns the URL of the persisted file.
    @discardableResult
    func persistSync(_ report: ErrorReport) throws -> URL {
        return try persist(report)
    }

    /// Starts the network monitor and flushes any pending reports.
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let wasOnline = self.isOnline
            self.isOnline = (path.status == .satisfied)
            if self.isOnline && !wasOnline {
                DebugLogger.log("ReportStore: network reconnected — flushing pending reports")
                self.flushPending()
            }
        }
        monitor.start(queue: queue)

        // Also flush any reports left over from previous sessions.
        queue.async { [weak self] in
            self?.flushPending()
        }
    }

    // MARK: - Persistence helpers

    private func storageDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent(ReportStore.storageSubdirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func persist(_ report: ErrorReport) throws -> URL {
        let dir = try storageDirectory()
        let filename = "\(UUID().uuidString).json"
        let url = dir.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        let data = try encoder.encode(report)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func loadReport(from url: URL) -> ErrorReport? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ErrorReport.self, from: data)
    }

    private func pendingReportURLs() -> [URL] {
        guard let dir = try? storageDirectory() else { return [] }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []
        return urls.filter { $0.pathExtension == "json" }
    }

    // MARK: - Delivery

    private func flushPending() {
        let urls = pendingReportURLs()
        DebugLogger.log("ReportStore: flushing \(urls.count) pending report(s)")
        for url in urls {
            guard let report = loadReport(from: url) else {
                // Corrupted file — delete it
                try? FileManager.default.removeItem(at: url)
                continue
            }
            attemptDelivery(reportURL: url, report: report, attempt: 1)
        }
    }

    private func attemptDelivery(reportURL: URL, report: ErrorReport, attempt: Int) {
        transport.send(report) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                // Delete persisted file only after confirmed 2xx
                try? FileManager.default.removeItem(at: reportURL)
                DebugLogger.log("ReportStore: report delivered and removed")

            case .failure(let statusCode, _):
                // 4xx (except 429) are permanent failures — don't retry
                if let code = statusCode, (400..<500).contains(code), code != 429 {
                    try? FileManager.default.removeItem(at: reportURL)
                    DebugLogger.log("ReportStore: permanent failure (HTTP \(code)) — discarding report")
                    return
                }
                // Retry with exponential back-off, up to maxRetries
                if attempt < ReportStore.maxRetries {
                    let delay = ReportStore.baseRetryDelay * pow(2.0, Double(attempt - 1))
                    DebugLogger.log("ReportStore: retry \(attempt)/\(ReportStore.maxRetries) in \(Int(delay))s")
                    self.queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.attemptDelivery(reportURL: reportURL, report: report, attempt: attempt + 1)
                    }
                } else {
                    // Cap reached — leave on disk for next launch/reconnect flush
                    DebugLogger.log("ReportStore: retry cap reached — leaving on disk for next flush")
                }
            }
        }
    }
}
