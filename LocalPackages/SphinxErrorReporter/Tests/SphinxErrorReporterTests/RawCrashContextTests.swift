// RawCrashContextTests.swift
// SphinxErrorReporterTests
//
// Tests: RawCrashContext binary image capture and metadata serialization.

import XCTest
@testable import SphinxErrorReporter

final class RawCrashContextTests: XCTestCase {

    // MARK: - Capture

    func test_capture_produces_metadata_with_rawCrash_key() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let metadata = context.asMetadata()
        XCTAssertNotNil(metadata["rawCrash"], "metadata must contain 'rawCrash' key")
    }

    func test_capture_metadata_contains_arch() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let metadata = context.asMetadata()
        let rawCrash = metadata["rawCrash"] as? [String: Any]
        let arch = rawCrash?["arch"] as? String
        XCTAssertNotNil(arch)
        XCTAssertFalse(arch!.isEmpty)
        // Should be arm64 or x86_64
        XCTAssertTrue(arch == "arm64" || arch == "x86_64", "Unexpected arch: \(arch!)")
    }

    func test_capture_metadata_contains_osVersion() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let metadata = context.asMetadata()
        let rawCrash = metadata["rawCrash"] as? [String: Any]
        let osVersion = rawCrash?["osVersion"] as? String
        XCTAssertNotNil(osVersion)
        XCTAssertFalse(osVersion!.isEmpty)
    }

    func test_capture_metadata_contains_frames_array() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let metadata = context.asMetadata()
        let rawCrash = metadata["rawCrash"] as? [String: Any]
        let frames = rawCrash?["frames"] as? [[String: Any]]
        XCTAssertNotNil(frames)
    }

    func test_capture_metadata_contains_binaryImages_array() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let metadata = context.asMetadata()
        let rawCrash = metadata["rawCrash"] as? [String: Any]
        let images = rawCrash?["binaryImages"] as? [[String: Any]]
        XCTAssertNotNil(images)
        // Must have at least one binary image (the test runner)
        XCTAssertFalse(images!.isEmpty, "Expected at least one binary image entry")
    }

    func test_capture_binary_images_have_uuid_and_loadAddress() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let metadata = context.asMetadata()
        let rawCrash = metadata["rawCrash"] as? [String: Any]
        let images = rawCrash?["binaryImages"] as? [[String: Any]] ?? []
        // At least one image should have a UUID (the main executable)
        let hasUUID = images.contains { img in
            let uuid = img["uuid"] as? String
            return uuid != nil && !uuid!.isEmpty
        }
        XCTAssertTrue(hasUUID, "At least one binary image should have a non-empty UUID")

        // All images should have a loadAddress starting with "0x"
        for img in images {
            let addr = img["loadAddress"] as? String
            XCTAssertNotNil(addr)
            XCTAssertTrue(addr!.hasPrefix("0x"), "loadAddress should be hex: \(addr ?? "nil")")
        }
    }

    // MARK: - Readable stack trace

    func test_readable_stack_trace_contains_arch() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let trace = context.asReadableStackTrace()
        XCTAssertTrue(trace.contains("Arch:"), "Readable trace should contain 'Arch:' label")
    }

    func test_readable_stack_trace_contains_binary_images_section() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let trace = context.asReadableStackTrace()
        XCTAssertTrue(trace.contains("Binary Images:"))
    }

    // MARK: - Metadata is serializable to JSON

    func test_metadata_is_json_serializable() {
        let context = RawCrashContext.capture(
            callStackReturnAddresses: Thread.callStackReturnAddresses as [NSNumber],
            rawSymbols: Thread.callStackSymbols
        )
        let metadata = context.asMetadata()
        XCTAssertTrue(JSONSerialization.isValidJSONObject(metadata), "metadata must be JSON-serializable")
    }
}
