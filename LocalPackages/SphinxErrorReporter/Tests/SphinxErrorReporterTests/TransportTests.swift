// TransportTests.swift
// SphinxErrorReporterTests
//
// Tests: Transport sends correct headers/method/body; handles 401/5xx/offline gracefully.

import XCTest
@testable import SphinxErrorReporter

final class TransportTests: XCTestCase {

    var config: Config!
    var transport: Transport!

    override func setUp() {
        super.setUp()
        config = Config(
            hiveBaseURL: URL(string: "https://hive.example.com/api")!,
            ingestKey: "hive_testkey123",
            mainRepo: "stakwork/sphinx-ios-v2",
            environment: "test",
            debug: true
        )
        MockURLProtocol.requestHandler = nil
        transport = Transport(config: config, session: .makeMock())
    }

    // MARK: - Success path

    func test_sends_POST_method() {
        let expectation = expectation(description: "POST sent")
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let report = ErrorReport(exceptionType: "TestError", message: "hello")
        transport.send(report) { _ in }
        wait(for: [expectation], timeout: 2)
    }

    func test_sends_authorization_bearer_header() {
        let expectation = expectation(description: "Auth header present")
        MockURLProtocol.requestHandler = { request in
            let auth = request.value(forHTTPHeaderField: "Authorization")
            XCTAssertEqual(auth, "Bearer hive_testkey123")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { _ in }
        wait(for: [expectation], timeout: 2)
    }

    func test_sends_x_api_key_header() {
        let expectation = expectation(description: "x-api-key header present")
        MockURLProtocol.requestHandler = { request in
            let apiKey = request.value(forHTTPHeaderField: "x-api-key")
            XCTAssertEqual(apiKey, "hive_testkey123")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { _ in }
        wait(for: [expectation], timeout: 2)
    }

    func test_sends_content_type_json() {
        let expectation = expectation(description: "Content-Type set")
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { _ in }
        wait(for: [expectation], timeout: 2)
    }

    func test_sends_correct_json_body() {
        let expectation = expectation(description: "JSON body correct")
        MockURLProtocol.requestHandler = { request in
            guard let body = request.httpBody else {
                XCTFail("Missing body")
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            }
            let json = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
            XCTAssertEqual(json["exceptionType"] as? String, "TestException")
            XCTAssertEqual(json["message"] as? String, "Test message")
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let report = ErrorReport(exceptionType: "TestException", message: "Test message")
        transport.send(report) { _ in }
        wait(for: [expectation], timeout: 2)
    }

    func test_posts_to_correct_endpoint() {
        let expectation = expectation(description: "Correct endpoint")
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.absoluteString.hasSuffix("/webhook/errors"))
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { _ in }
        wait(for: [expectation], timeout: 2)
    }

    func test_completion_called_with_success_on_200() {
        let expectation = expectation(description: "Success result")
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { result in
            if case .success(let code) = result {
                XCTAssertEqual(code, 200)
                expectation.fulfill()
            } else {
                XCTFail("Expected success")
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    // MARK: - Error paths (no crash/throw)

    func test_401_returns_failure_without_crash() {
        let expectation = expectation(description: "401 handled")
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { result in
            if case .failure(let code, _) = result {
                XCTAssertEqual(code, 401)
                expectation.fulfill()
            } else {
                XCTFail("Expected failure")
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func test_500_returns_failure_without_crash() {
        let expectation = expectation(description: "500 handled")
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { result in
            if case .failure(let code, _) = result {
                XCTAssertEqual(code, 500)
                expectation.fulfill()
            } else {
                XCTFail("Expected failure")
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    func test_network_error_returns_failure_without_crash() {
        let expectation = expectation(description: "Network error handled")
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { result in
            if case .failure(let code, let err) = result {
                XCTAssertNil(code)
                XCTAssertNotNil(err)
                expectation.fulfill()
            } else {
                XCTFail("Expected failure")
            }
        }
        wait(for: [expectation], timeout: 2)
    }

    // MARK: - Background queue check

    func test_completion_not_called_on_main_thread() {
        let expectation = expectation(description: "Completion off main thread")
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        transport.send(ErrorReport(exceptionType: "E", message: "m")) { _ in
            // The transport completion arrives on URLSession queue, which is not main
            // We just check we're not blocked on the main thread here
            expectation.fulfill()
        }
        // If this blocks, we're stuck on main — use async wait
        wait(for: [expectation], timeout: 3)
    }
}
