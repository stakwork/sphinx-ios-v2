//
//  PinTimeoutClampTests.swift
//  sphinxTests
//
//  Synced pin_timeout parsing and clamping.
//

import XCTest
@testable import sphinx

final class PinTimeoutClampTests: XCTestCase {

    func testClampsBelowZeroToZero() {
        XCTAssertEqual(UserData.clampedPinTimeout(-5), 0)
        XCTAssertEqual(UserData.clampedPinTimeout(fromRaw: "-1"), 0)
    }

    func testClampsAboveMaxToMax() {
        XCTAssertEqual(UserData.clampedPinTimeout(100), Constants.kMaxPinTimeoutValue)
        XCTAssertEqual(UserData.clampedPinTimeout(fromRaw: "26"), 25)
    }

    func testBoundariesAndMidValues() {
        XCTAssertEqual(UserData.clampedPinTimeout(fromRaw: "0"), 0)
        XCTAssertEqual(UserData.clampedPinTimeout(fromRaw: "25"), 25)
        XCTAssertEqual(UserData.clampedPinTimeout(fromRaw: "12"), 12)
    }

    func testToleratesWhitespaceAndIntegralDoubles() {
        XCTAssertEqual(UserData.clampedPinTimeout(fromRaw: " 12 \n"), 12)
        XCTAssertEqual(UserData.clampedPinTimeout(fromRaw: "25.0"), 25)
        XCTAssertEqual(UserData.clampedPinTimeout(fromRaw: "0.0"), 0)
    }

    func testGarbageReturnsNil() {
        for raw in ["", "   ", "abc", "NaN", "inf", "-inf", "1.5", "12abc", "1e999"] {
            XCTAssertNil(UserData.clampedPinTimeout(fromRaw: raw), "'\(raw)' should be nil")
        }
    }
}
