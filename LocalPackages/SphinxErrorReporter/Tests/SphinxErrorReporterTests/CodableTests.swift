// CodableTests.swift
// SphinxErrorReporterTests
//
// Tests: Frame and ErrorReport Codable round-trips, camelCase keys,
// frames/fingerprint omitted when nil, exactly 4 keys in Frame JSON.

import XCTest
@testable import SphinxErrorReporter

final class CodableTests: XCTestCase {

    // MARK: - Frame

    func test_frame_encodes_exactly_4_possible_keys() throws {
        let frame = Frame(filename: "AppDelegate.swift", function: "application(_:didFinishLaunchingWithOptions:)", lineno: 42, inApp: true)
        let data = try JSONEncoder().encode(frame)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(Set(json.keys), Set(["filename", "function", "lineno", "inApp"]))
    }

    func test_frame_omits_optional_keys_when_nil() throws {
        let frame = Frame(filename: "SomeFile.swift")
        let data = try JSONEncoder().encode(frame)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json.keys.count, 1)
        XCTAssertEqual(json["filename"] as? String, "SomeFile.swift")
    }

    func test_frame_round_trip() throws {
        let original = Frame(filename: "Chat.swift", function: "sendMessage()", lineno: 99, inApp: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Frame.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_frame_camelCase_keys() throws {
        let frame = Frame(filename: "Test.swift", inApp: true)
        let data = try JSONEncoder().encode(frame)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // inApp must be camelCase (not "in_app")
        XCTAssertNotNil(json["inApp"])
        XCTAssertNil(json["in_app"])
    }

    // MARK: - ErrorReport

    func test_errorReport_required_fields_only() throws {
        let report = ErrorReport(exceptionType: "NSException", message: "boom")
        let data = try JSONEncoder().encode(report)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["exceptionType"] as? String, "NSException")
        XCTAssertEqual(json["message"] as? String, "boom")
        // Optional fields must be absent
        XCTAssertNil(json["frames"])
        XCTAssertNil(json["fingerprint"])
        XCTAssertNil(json["stackTrace"])
        XCTAssertNil(json["environment"])
        XCTAssertNil(json["commitSha"])
    }

    func test_errorReport_frames_present_when_set() throws {
        let frames = [Frame(filename: "A.swift", inApp: true)]
        let report = ErrorReport(exceptionType: "SomeError", message: "oops", frames: frames)
        let data = try JSONEncoder().encode(report)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["frames"])
        let framesArr = json["frames"] as! [[String: Any]]
        XCTAssertEqual(framesArr.count, 1)
        XCTAssertEqual(framesArr[0]["filename"] as? String, "A.swift")
    }

    func test_errorReport_fingerprint_omitted_by_default() throws {
        let report = ErrorReport(exceptionType: "E", message: "m")
        let data = try JSONEncoder().encode(report)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(json["fingerprint"])
    }

    func test_errorReport_fingerprint_present_when_set() throws {
        let report = ErrorReport(exceptionType: "E", message: "m", fingerprint: "abc123")
        let data = try JSONEncoder().encode(report)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["fingerprint"] as? String, "abc123")
    }

    func test_errorReport_camelCase_keys() throws {
        let report = ErrorReport(
            exceptionType: "E",
            message: "m",
            stackTrace: "trace",
            commitSha: "abc",
            requestContext: ["url": "/api/foo"]
        )
        let data = try JSONEncoder().encode(report)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["stackTrace"])
        XCTAssertNotNil(json["commitSha"])
        XCTAssertNotNil(json["requestContext"])
        // Ensure no snake_case keys leaked
        XCTAssertNil(json["stack_trace"])
        XCTAssertNil(json["commit_sha"])
        XCTAssertNil(json["request_context"])
    }

    func test_errorReport_metadata_encodes_as_object() throws {
        let report = ErrorReport(exceptionType: "E", message: "m", metadata: ["key": "value", "count": 3])
        let data = try JSONEncoder().encode(report)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let meta = json["metadata"] as? [String: Any]
        XCTAssertNotNil(meta)
        XCTAssertEqual(meta?["key"] as? String, "value")
        XCTAssertEqual(meta?["count"] as? Int, 3)
    }

    func test_errorReport_decode() throws {
        let json = """
        {
            "exceptionType": "NSRangeException",
            "message": "index out of range",
            "environment": "production",
            "repository": "stakwork/sphinx-ios-v2"
        }
        """
        let data = json.data(using: .utf8)!
        let report = try JSONDecoder().decode(ErrorReport.self, from: data)
        XCTAssertEqual(report.exceptionType, "NSRangeException")
        XCTAssertEqual(report.message, "index out of range")
        XCTAssertEqual(report.environment, "production")
        XCTAssertNil(report.frames)
        XCTAssertNil(report.fingerprint)
    }
}
