// FrameBuilderTests.swift
// SphinxErrorReporterTests
//
// Tests: FrameBuilder parses debug + stripped stacks correctly.

import XCTest
@testable import SphinxErrorReporter

final class FrameBuilderTests: XCTestCase {

    let builder = FrameBuilder(appModuleName: "sphinx", mainRepo: "stakwork/sphinx-ios-v2")

    // MARK: - Debug symbolicated stack

    func test_debug_stack_classifies_app_frames_as_inApp() {
        let symbols = loadFixture("debug_stack")
        let frames = builder.build(from: symbols)
        XCTAssertNotNil(frames, "Expected non-nil frames from debug stack")
        let appFrames = frames!.filter { $0.inApp == true }
        XCTAssertFalse(appFrames.isEmpty, "Expected at least one in-app frame")
    }

    func test_debug_stack_classifies_system_frames_as_not_inApp() {
        let symbols = loadFixture("debug_stack")
        let frames = builder.build(from: symbols)!
        // UIKit, libdispatch, CoreFoundation frames should be inApp: false
        let systemFrames = frames.filter { $0.inApp == false }
        XCTAssertFalse(systemFrames.isEmpty, "Expected at least one system frame")
    }

    func test_debug_stack_app_frame_has_function_name() {
        let symbols = loadFixture("debug_stack")
        let frames = builder.build(from: symbols)!
        let appFrames = frames.filter { $0.inApp == true }
        for frame in appFrames {
            XCTAssertNotNil(frame.function, "App frame should have a function name in debug build")
        }
    }

    func test_debug_stack_app_frame_filename_is_relative() {
        let symbols = loadFixture("debug_stack")
        let frames = builder.build(from: symbols)!
        let appFrames = frames.filter { $0.inApp == true }
        for frame in appFrames {
            // Should NOT start with the full module prefix "sphinx."
            XCTAssertFalse(
                frame.filename.hasPrefix("sphinx."),
                "Filename '\(frame.filename)' should be repo-relative (no 'sphinx.' prefix)"
            )
        }
    }

    func test_debug_stack_no_invented_fields() {
        let symbols = loadFixture("debug_stack")
        let frames = builder.build(from: symbols)!
        let encoder = JSONEncoder()
        for frame in frames {
            let data = try! encoder.encode(frame)
            let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            let allowedKeys = Set(["filename", "function", "lineno", "inApp"])
            let extraKeys = Set(json.keys).subtracting(allowedKeys)
            XCTAssertTrue(extraKeys.isEmpty, "Frame has unexpected keys: \(extraKeys)")
        }
    }

    // MARK: - Stripped / release stack

    func test_stripped_stack_returns_frames() {
        // Even stripped stacks should produce frames (with raw addresses)
        let symbols = loadFixture("stripped_stack")
        let frames = builder.build(from: symbols)
        XCTAssertNotNil(frames, "Expected non-nil frames even from stripped stack")
    }

    func test_stripped_stack_app_frames_have_no_invented_function() {
        let symbols = loadFixture("stripped_stack")
        let frames = builder.build(from: symbols)!
        let appFrames = frames.filter { $0.inApp == true }
        for frame in appFrames {
            // In stripped stacks, function should be nil (we don't invent names)
            XCTAssertNil(frame.function, "Stripped frame should not have an invented function name")
        }
    }

    // MARK: - Empty input

    func test_empty_stack_returns_nil() {
        let frames = builder.build(from: [])
        XCTAssertNil(frames, "Empty stack should return nil so caller omits frames")
    }

    func test_malformed_lines_return_nil() {
        let frames = builder.build(from: ["bad line", "   "])
        XCTAssertNil(frames)
    }

    // MARK: - Direct parsing

    func test_single_debug_line() {
        let line = "0   sphinx   0x0000000100abc123 sphinx.AppDelegate.doThing() + 42"
        let frames = builder.build(from: [line])
        XCTAssertNotNil(frames)
        XCTAssertEqual(frames!.first?.inApp, true)
        XCTAssertEqual(frames!.first?.function, "sphinx.AppDelegate.doThing()")
    }

    func test_single_system_line() {
        let line = "5   UIKit    0x00000001a0abc456 UIApplicationMain + 136"
        let frames = builder.build(from: [line])
        XCTAssertNotNil(frames)
        XCTAssertEqual(frames!.first?.inApp, false)
    }

    // MARK: - Helpers

    private func loadFixture(_ name: String) -> [String] {
        guard let url = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "txt"),
              let content = try? String(contentsOf: url) else {
            // Fallback: inline fixtures when Bundle.module resources aren't available
            return inlineFixture(name)
        }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func inlineFixture(_ name: String) -> [String] {
        switch name {
        case "debug_stack":
            return [
                "0   sphinx   0x0000000100abc123 sphinx.AppDelegate.application(_:didFinishLaunchingWithOptions:) + 42",
                "1   sphinx   0x0000000100bcd234 sphinx.SomeManager.doWork() + 12",
                "2   UIKit    0x00000001a0abc456 UIApplicationMain + 136",
                "3   libdispatch.dylib   0x00000001a1bc5678 _dispatch_main_queue_callback_4CF + 44",
                "4   CoreFoundation   0x00000001a2cd6789 CFRunLoopRunSpecific + 600"
            ]
        case "stripped_stack":
            return [
                "0   sphinx   0x0000000100abc123 0x100000000 + 11299",
                "1   sphinx   0x0000000100bcd234 0x100000000 + 12340",
                "2   UIKit    0x00000001a0abc456 0x1a0000000 + 11354326",
                "3   libdispatch.dylib   0x00000001a1bc5678 0x1a1000000 + 12341880"
            ]
        default:
            return []
        }
    }
}
