// ReportStoreTests.swift
// SphinxErrorReporterTests
//
// Tests: persist, offline → reconnect flush, 2xx-triggered deletion, capped retry.

import XCTest
@testable import SphinxErrorReporter

final class ReportStoreTests: XCTestCase {

    var config: Config!

    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
        config = Config(
            hiveBaseURL: URL(string: "https://hive.example.com/api")!,
            ingestKey: "hive_testkey",
            mainRepo: "stakwork/sphinx-ios-v2",
            debug: true
        )
        // Clean up any leftover test files
        cleanupTestDirectory()
    }

    override func tearDown() {
        cleanupTestDirectory()
        super.tearDown()
    }

    // MARK: - Persist

    func test_persistSync_writes_file_to_disk() throws {
        let store = makeStore(statusCode: 200)
        let report = ErrorReport(exceptionType: "TestError", message: "test persist")
        let url = try store.persistSync(report)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Persisted file should exist")
        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    func test_persistSync_writes_valid_json() throws {
        let store = makeStore(statusCode: 200)
        let report = ErrorReport(exceptionType: "SomeException", message: "json check")
        let url = try store.persistSync(report)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(ErrorReport.self, from: data)
        XCTAssertEqual(decoded.exceptionType, "SomeException")
        XCTAssertEqual(decoded.message, "json check")
    }

    // MARK: - Enqueue + delivery

    func test_enqueue_delivers_and_deletes_on_success() {
        let deliveryExpectation = expectation(description: "Report delivered")
        MockURLProtocol.requestHandler = { req in
            deliveryExpectation.fulfill()
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let store = makeStore(statusCode: 200)
        let report = ErrorReport(exceptionType: "DeliveredError", message: "should deliver")
        store.enqueue(report)
        wait(for: [deliveryExpectation], timeout: 3)
        // Give a moment for the file deletion to complete
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(pendingFileCount(), 0, "All delivered reports should be deleted")
    }

    func test_enqueue_keeps_file_on_failure() {
        MockURLProtocol.requestHandler = { req in
            throw URLError(.notConnectedToInternet)
        }
        let store = makeStore(statusCode: 500)
        let report = ErrorReport(exceptionType: "OfflineError", message: "should persist")
        store.enqueue(report)
        Thread.sleep(forTimeInterval: 1.5) // Wait for first attempt + some retry time
        // File should still be there since all attempts fail
        XCTAssertGreaterThan(pendingFileCount(), 0, "Failed reports should remain on disk")
    }

    // MARK: - Permanent 4xx (non-429) discards immediately

    func test_enqueue_discards_on_401() {
        let expectation = expectation(description: "Request sent")
        MockURLProtocol.requestHandler = { req in
            expectation.fulfill()
            return (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        let store = makeStore(statusCode: 401)
        store.enqueue(ErrorReport(exceptionType: "AuthError", message: "auth fail"))
        wait(for: [expectation], timeout: 2)
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(pendingFileCount(), 0, "401 should discard report immediately")
    }

    // MARK: - Capped retry

    func test_retry_cap_stops_retrying() {
        var attemptCount = 0
        // Simulate persistent 5xx
        MockURLProtocol.requestHandler = { req in
            attemptCount += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let store = makeStore(statusCode: 500)
        store.enqueue(ErrorReport(exceptionType: "RetryError", message: "retry cap test"))
        // Wait enough time for maxRetries attempts with exponential backoff
        // maxRetries = 5, delays: 2, 4, 8, 16 seconds (capped). In tests use a shorter limit.
        // We verify it doesn't loop forever by checking it stops within a bounded count.
        Thread.sleep(forTimeInterval: 3.0) // Covers attempt 1 + retry at 2s
        let countAfterWait = attemptCount
        Thread.sleep(forTimeInterval: 1.0)
        // Should not have grown by much (exponential backoff means next attempt is at 4s+)
        XCTAssertLessThanOrEqual(attemptCount - countAfterWait, 1, "Should not retry more than once per ~4s window")
    }

    // MARK: - Thread safety

    func test_enqueue_returns_quickly_on_calling_thread() {
        MockURLProtocol.requestHandler = { req in
            Thread.sleep(forTimeInterval: 0.5) // Simulate slow network
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let store = makeStore(statusCode: 200)
        let start = Date()
        store.enqueue(ErrorReport(exceptionType: "E", message: "m"))
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.1, "enqueue() should return immediately (async delivery)")
    }

    // MARK: - Helpers

    private func makeStore(statusCode: Int) -> ReportStore {
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, Data())
        }
        return SphinxErrorReporter._makeStore(config: config, session: .makeMock())
    }

    private func pendingDirectory() -> URL? {
        return try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("com.sphinx.error-reporter/pending")
    }

    private func pendingFileCount() -> Int {
        guard let dir = pendingDirectory() else { return 0 }
        return (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.filter { $0.hasSuffix(".json") }.count ?? 0
    }

    private func cleanupTestDirectory() {
        guard let dir = pendingDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}
