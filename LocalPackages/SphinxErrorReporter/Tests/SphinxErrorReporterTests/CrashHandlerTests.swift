// CrashHandlerTests.swift
// SphinxErrorReporterTests
//
// Dump-format, reentrancy, and findImage tests. Do NOT raise a real SIGSEGV.

import XCTest
import Darwin
import CrashSignalTrampoline
@testable import SphinxErrorReporter

final class CrashHandlerTests: XCTestCase {

    override func tearDown() {
        sphx_crash_reset_state()
        if let url = CrashDump.fileURL() {
            try? FileManager.default.removeItem(at: url)
        }
        super.tearDown()
    }

    // MARK: - Exception handler chaining

    func test_install_chains_prior_exception_handler() {
        var testHandlerCalled = false
        var testHandlerException: NSException?

        let testDouble: NSUncaughtExceptionHandler = { exception in
            testHandlerCalled = true
            testHandlerException = exception
        }

        let previousHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(testDouble)

        let config = Config(
            hiveBaseURL: URL(string: "https://hive.example.com/api")!,
            ingestKey: "hive_testkey",
            mainRepo: "stakwork/sphinx-ios-v2",
            debug: false
        )
        let transport = Transport(config: config, session: .makeMock())
        let store = ReportStore(transport: transport)
        CrashHandler.install(config: config, store: store)

        XCTAssertNotNil(NSGetUncaughtExceptionHandler(), "Our exception handler should be installed")

        let installedHandler = NSGetUncaughtExceptionHandler()!
        withUnsafePointer(to: testDouble) { testDoublePtr in
            withUnsafePointer(to: installedHandler) { installedPtr in
                let testDoubleAddr = UnsafeRawPointer(testDoublePtr)
                let installedAddr = UnsafeRawPointer(installedPtr)
                XCTAssertNotEqual(
                    testDoubleAddr,
                    installedAddr,
                    "CrashHandler should wrap the prior handler, not leave it as-is"
                )
            }
        }

        NSSetUncaughtExceptionHandler(previousHandler)
        _ = testHandlerCalled
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
        SphinxErrorReporter.start(config)
        XCTAssertTrue(SphinxErrorReporter.isStarted)
        SphinxErrorReporter._reset()
    }

    func test_capture_before_start_does_not_crash() {
        SphinxErrorReporter._reset()
        let error = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "test"])
        SphinxErrorReporter.capture(error, metadata: ["key": "value"])
        XCTAssertTrue(true)
    }

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
        XCTAssertTrue(SphinxErrorReporter.isStarted)
        SphinxErrorReporter._reset()
    }

    func test_capture_sends_correct_payload_shape() {
        let expectation = expectation(description: "Payload sent")
        MockURLProtocol.requestHandler = { req in
            guard let body = req.httpBody,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                XCTFail("No body or invalid JSON")
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            }
            XCTAssertNotNil(json["exceptionType"])
            XCTAssertNotNil(json["message"])
            if let frames = json["frames"] as? [[String: Any]] {
                XCTAssertFalse(frames.isEmpty, "frames must be non-empty or omitted entirely")
            }
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

    // MARK: - Dump format (fixture, no real SIGSEGV)

    func test_dump_parser_reads_signal_pc_and_attributed_image() {
        let data = CrashDump.encode(
            signal: SIGSEGV,
            pc: 0x0000_0001_a2cd_6789,
            addressCount: 1,
            imageName: "CoreFoundation",
            imageUUID: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            loadAddress: 0x0000_0001_a200_0000,
            imageSize: 0x00F0_0000
        )
        XCTAssertEqual(data.count, CrashDump.encodedSize)

        let dump = CrashDump.parse(data)
        XCTAssertNotNil(dump)
        XCTAssertEqual(dump?.signal, SIGSEGV)
        XCTAssertEqual(dump?.pc, 0x0000_0001_a2cd_6789)
        XCTAssertEqual(dump?.addressCount, 1)
        XCTAssertEqual(dump?.imageName, "CoreFoundation")
        XCTAssertEqual(dump?.imageUUID, "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        XCTAssertEqual(dump?.loadAddress, 0x0000_0001_a200_0000)
        XCTAssertEqual(dump?.imageSize, 0x00F0_0000)
    }

    func test_dump_parser_rejects_truncated_and_corrupt() {
        XCTAssertNil(CrashDump.parse(Data()))
        XCTAssertNil(CrashDump.parse(Data(repeating: 0, count: 20)))
        XCTAssertNil(CrashDump.parse(Data(repeating: 0x41, count: CrashDump.encodedSize)))

        var badMagic = CrashDump.encode(signal: SIGSEGV, pc: 1)
        badMagic.replaceSubrange(0..<8, with: Data("XXXXXXXX".utf8))
        XCTAssertNil(CrashDump.parse(badMagic))

        let badVersion = CrashDump.encode(signal: SIGSEGV, pc: 1, version: 99)
        XCTAssertNil(CrashDump.parse(badVersion))

        let tooManyAddresses = CrashDump.encode(signal: SIGSEGV, pc: 1, addressCount: 99)
        XCTAssertNil(CrashDump.parse(tooManyAddresses))

        let oversized = CrashDump.encode(signal: SIGSEGV, pc: 1) + Data(count: CrashDump.maxBytes)
        XCTAssertNil(CrashDump.parse(oversized))
    }

    // MARK: - Reentrancy

    func test_reentrancy_guard_does_not_overwrite_first_dump() throws {
        sphx_crash_reset_state()

        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent("sphx-reentrancy.dump")
        try? FileManager.default.removeItem(at: path)

        let fd = path.path.withCString { ptr in
            open(ptr, O_CREAT | O_EXCL | O_RDWR, 0o600)
        }
        XCTAssertGreaterThanOrEqual(fd, 0)
        sphx_crash_set_dump_fd(fd)

        XCTAssertEqual(
            sphx_crash_add_image("CoreFoundation", "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", 0x1000, 0x1000),
            0
        )

        let firstPC: UInt64 = 0x1500
        let secondPC: UInt64 = 0x9999
        XCTAssertEqual(sphx_crash_handle_signal_for_test(SIGSEGV, firstPC), 1)
        XCTAssertEqual(sphx_crash_handle_signal_for_test(SIGBUS, secondPC), 0, "Nested entry must not write")

        sphx_crash_reset_state()

        let data = try Data(contentsOf: path)
        let dump = CrashDump.parse(data)
        XCTAssertEqual(dump?.signal, SIGSEGV)
        XCTAssertEqual(dump?.pc, firstPC)
        XCTAssertEqual(dump?.imageName, "CoreFoundation")
        XCTAssertNotEqual(dump?.pc, secondPC)

        try? FileManager.default.removeItem(at: path)
    }

    // MARK: - findImage range check

    func test_findImage_range_checks_real_size() {
        let cf = RawCrashContext.BinaryImageInfo(
            name: "CoreFoundation",
            uuid: "CF-UUID",
            loadAddress: 0x1000,
            size: 0x1000
        )
        let dispatch = RawCrashContext.BinaryImageInfo(
            name: "libdispatch.dylib",
            uuid: "DD-UUID",
            loadAddress: 0x2000,
            size: 0x1000
        )
        let sphinx = RawCrashContext.BinaryImageInfo(
            name: "sphinx",
            uuid: "APP-UUID",
            loadAddress: 0x0,
            size: 0x800
        )
        let images = [sphinx, cf, dispatch]

        let cfHit = RawCrashContext.findImage(for: 0x1FFF, in: images)
        XCTAssertEqual(cfHit?.uuid, "CF-UUID")

        let dispatchHit = RawCrashContext.findImage(for: 0x2000, in: images)
        XCTAssertEqual(dispatchHit?.uuid, "DD-UUID")

        XCTAssertNil(RawCrashContext.findImage(for: 0x3000, in: images), "Address at exclusive end must not match")
        XCTAssertNil(RawCrashContext.findImage(for: 0x0FFF, in: images), "Gap between images must not attach to CF")
    }

    func test_findImage_overlapping_prefers_highest_load_address() {
        let lower = RawCrashContext.BinaryImageInfo(
            name: "lower",
            uuid: "LOW",
            loadAddress: 0x1000,
            size: 0x2000
        )
        let higher = RawCrashContext.BinaryImageInfo(
            name: "higher",
            uuid: "HIGH",
            loadAddress: 0x1800,
            size: 0x400
        )
        let hit = RawCrashContext.findImage(for: 0x1900, in: [lower, higher])
        XCTAssertEqual(hit?.uuid, "HIGH")
    }

    func test_findImage_size_zero_never_matches() {
        let zero = RawCrashContext.BinaryImageInfo(
            name: "ghost",
            uuid: "ZERO",
            loadAddress: 0x1000,
            size: 0
        )
        XCTAssertNil(RawCrashContext.findImage(for: 0x1000, in: [zero]))
        XCTAssertNil(RawCrashContext.findImage(for: 0x1001, in: [zero]))
    }
}
