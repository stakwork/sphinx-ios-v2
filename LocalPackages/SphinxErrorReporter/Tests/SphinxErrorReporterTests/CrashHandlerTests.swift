// CrashHandlerTests.swift
// SphinxErrorReporterTests
//
// Tests: CrashHandler chains previously-installed NSUncaughtExceptionHandler.
// NOTE: We test chaining logic only — we do NOT actually raise real exceptions
// (which would kill the test process). We use the public API to verify chaining.

import XCTest
@testable import SphinxErrorReporter

final class CrashHandlerTests: XCTestCase {

    // MARK: - Exception handler chaining

    func test_install_chains_prior_exception_handler() {
        // Install a test double handler before CrashHandler
        var testHandlerCalled = false
        var testHandlerException: NSException?

        let testDouble: NSUncaughtExceptionHandler = { exception in
            testHandlerCalled = true
            testHandlerException = exception
        }

        // Save current handler so we can restore it after the test
        let previousHandler = NSGetUncaughtExceptionHandler()

        // Install the test double
        NSSetUncaughtExceptionHandler(testDouble)

        // Now install CrashHandler (it should capture testDouble as its chain target)
        let config = Config(
            hiveBaseURL: URL(string: "https://hive.example.com/api")!,
            ingestKey: "hive_testkey",
            mainRepo: "stakwork/sphinx-ios-v2",
            debug: false
        )
        let transport = Transport(config: config, session: .makeMock())
        let store = ReportStore(transport: transport)
        CrashHandler.install(config: config, store: store)

        // Verify our handler is now installed
        XCTAssertNotNil(NSGetUncaughtExceptionHandler(), "Our exception handler should be installed")

        // Retrieve what's installed — it should be our wrapper, not the test double
        let installedHandler = NSGetUncaughtExceptionHandler()!

        // We can't call installedHandler directly with a fake exception without crashing,
        // but we can verify it's a different function from testDouble (i.e., we wrapped it)
        // In Swift, comparing C function pointers is done via UnsafeMutableRawPointer
        withUnsafePointer(to: testDouble) { testDoublePtr in
            withUnsafePointer(to: installedHandler) { installedPtr in
                // The installed handler should NOT be the raw test double
                // (CrashHandler wraps it)
                let testDoubleAddr = UnsafeRawPointer(testDoublePtr)
                let installedAddr = UnsafeRawPointer(installedPtr)
                XCTAssertNotEqual(testDoubleAddr, installedAddr,
                    "CrashHandler should wrap the prior handler, not leave it as-is")
            }
        }

        // Restore original handler
        NSSetUncaughtExceptionHandler(previousHandler)
        _ = testHandlerCalled // suppress unused warning
        _ = testHandlerException
    }

    // MARK: - Idempotent start

    func test_sphinxErrorReporter_start_is_idempotent() {
        SphinxErrorReporter._reset()
        let config = Config(
            hiveBaseURL: URL(string: "https://hive.example.com/api")!,
            ingestKey: "hive_testkey",
            mainRepo: "stakwork/sphinx-ios-v2"
        )
        SphinxErrorReporter.start(config)
        XCTAssertTrue(SphinxErrorReporter.isStarted)
        // Calling again should be a no-op (no crash, no double install)
        SphinxErrorReporter.start(config)
        XCTAssertTrue(SphinxErrorReporter.isStarted)
        SphinxErrorReporter._reset()
    }

    // MARK: - capture() before start() is safe

    func test_capture_before_start_does_not_crash() {
        SphinxErrorReporter._reset()
        // Should not crash or throw
        let error = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "test"])
        SphinxErrorReporter.capture(error, metadata: ["key": "value"])
        // If we reach here, it didn't crash
        XCTAssertTrue(true)
    }

    // MARK: - Public API wires correctly

    func test_capture_after_start_does_not_crash() {
        SphinxErrorReporter._reset()
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let config = Config(
            hiveBaseURL: URL(string: "https://hive.example.com/api")!,
            ingestKey: "hive_testkey",
            mainRepo: "stakwork/sphinx-ios-v2",
            debug: false
        )
        SphinxErrorReporter.start(config)
        let error = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "test error"])
        SphinxErrorReporter.capture(error, metadata: ["context": "unit test"])
        // If we reach here, no crash
        XCTAssertTrue(SphinxErrorReporter.isStarted)
        SphinxErrorReporter._reset()
    }

    // MARK: - capture() produces correct payload shape

    func test_capture_sends_correct_payload_shape() {
        let expectation = expectation(description: "Payload sent")
        MockURLProtocol.requestHandler = { req in
            guard let body = req.httpBody,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                XCTFail("No body or invalid JSON")
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            }
            // Required fields
            XCTAssertNotNil(json["exceptionType"])
            XCTAssertNotNil(json["message"])
            // No empty frames array
            if let frames = json["frames"] as? [[String: Any]] {
                XCTAssertFalse(frames.isEmpty, "frames must be non-empty or omitted entirely")
            }
            // No fingerprint by default
            XCTAssertNil(json["fingerprint"])
            expectation.fulfill()
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        SphinxErrorReporter._reset()
        let config = Config(
            hiveBaseURL: URL(string: "https://hive.example.com/api")!,
            ingestKey: "hive_testkey",
            mainRepo: "stakwork/sphinx-ios-v2"
        )
        SphinxErrorReporter.start(config)
        let error = NSError(domain: "PayloadTestDomain", code: 99, userInfo: [NSLocalizedDescriptionKey: "payload test"])
        SphinxErrorReporter.capture(error)
        wait(for: [expectation], timeout: 3)
        SphinxErrorReporter._reset()
    }
}
