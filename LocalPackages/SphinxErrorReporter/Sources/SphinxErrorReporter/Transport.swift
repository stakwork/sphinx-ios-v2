// Transport.swift
// SphinxErrorReporter
//
// Handles async POST delivery to Hive's /api/webhook/errors endpoint.
// URLSession is injectable for testing.
// Never touches the main thread.

import Foundation

/// Result of a single delivery attempt.
enum TransportResult {
    case success(statusCode: Int)
    case failure(statusCode: Int?, error: Error?)
}

/// Internal transport layer wrapping URLSession.
final class Transport {

    private let session: URLSession
    private let config: Config
    private static let queue = DispatchQueue(label: "com.sphinx.error-reporter.transport", qos: .utility)

    init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Public

    /// Sends an `ErrorReport` to Hive asynchronously on a background queue.
    /// Calls `completion` with the result — never throws, never crashes.
    func send(_ report: ErrorReport, completion: @escaping (TransportResult) -> Void) {
        Transport.queue.async { [weak self] in
            guard let self = self else { return }
            self.performSend(report, completion: completion)
        }
    }

    // MARK: - Private

    private func performSend(_ report: ErrorReport, completion: @escaping (TransportResult) -> Void) {
        // Build endpoint URL: <hiveBaseURL>/webhook/errors
        let endpointURL = config.hiveBaseURL.appendingPathComponent("webhook/errors")

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth: Bearer first, x-api-key as fallback (send both so server can try either)
        request.setValue("Bearer \(config.ingestKey)", forHTTPHeaderField: "Authorization")
        request.setValue(config.ingestKey, forHTTPHeaderField: "x-api-key")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            request.httpBody = try encoder.encode(report)
        } catch {
            DebugLogger.log("Transport: JSON encode failed — \(error.localizedDescription)")
            completion(.failure(statusCode: nil, error: error))
            return
        }

        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                DebugLogger.log("Transport: network error — \(error.localizedDescription)")
                completion(.failure(statusCode: nil, error: error))
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(statusCode) {
                DebugLogger.log("Transport: send success (\(statusCode))")
                completion(.success(statusCode: statusCode))
            } else {
                DebugLogger.log("Transport: send failed (HTTP \(statusCode))")
                completion(.failure(statusCode: statusCode, error: nil))
            }
        }
        task.resume()
    }
}
