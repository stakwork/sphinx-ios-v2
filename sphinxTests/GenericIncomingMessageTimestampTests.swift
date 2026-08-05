//
//  GenericIncomingMessageTimestampTests.swift
//  sphinxTests
//
//  Tests the tribe/DM timestamp gate in GenericIncomingMessage.init.
//  PR #591 regressed this once by removing the isTribe guard; these four
//  cases lock the correct branch behaviour to prevent a repeat.
//

import XCTest
@testable import sphinx

class GenericIncomingMessageTimestampTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal Msg with the given relay timestamp (nil == absent).
    private func makeMsg(timestamp: UInt64?) -> Msg {
        return Msg(
            message: nil,
            type: UInt8(TransactionMessage.TransactionMessageType.message.rawValue),
            uuid: nil,
            tag: nil,
            index: nil,
            sender: nil,
            msat: nil,
            timestamp: timestamp,
            sentTo: nil,
            fromMe: nil,
            paymentHash: nil,
            error: nil
        )
    }

    /// Builds a minimal MessageInnerContent with the given sender-embedded date.
    private func makeInnerContent(date: Int) -> MessageInnerContent {
        var ic = MessageInnerContent(JSONString: "{}")!
        ic.date = date
        return ic
    }

    // MARK: - Tribe message, msg.timestamp present
    // Tribe messages must always use innerContent.date regardless of relay timestamp.

    func testTribeMessage_withRelayTimestamp_usesInnerContentDate() {
        let relayTimestamp: UInt64 = 9_999_999
        let innerDate = 1_000_000

        let msg = makeMsg(timestamp: relayTimestamp)
        let inner = makeInnerContent(date: innerDate)

        let sut = GenericIncomingMessage(
            msg: msg,
            csr: nil,
            innerContent: inner,
            isTribeMessage: true
        )

        XCTAssertEqual(
            sut?.timestamp, innerDate,
            "Tribe message must use innerContent.date, not the relay timestamp"
        )
        XCTAssertNotEqual(
            sut?.timestamp, Int(relayTimestamp),
            "Tribe message must NOT use msg.timestamp"
        )
    }

    // MARK: - Tribe message, msg.timestamp nil
    // Must fall back to innerContent.date without crashing or logging.

    func testTribeMessage_nilRelayTimestamp_usesInnerContentDate() {
        let innerDate = 1_234_567

        let msg = makeMsg(timestamp: nil)
        let inner = makeInnerContent(date: innerDate)

        let sut = GenericIncomingMessage(
            msg: msg,
            csr: nil,
            innerContent: inner,
            isTribeMessage: true
        )

        XCTAssertEqual(
            sut?.timestamp, innerDate,
            "Tribe message with nil relay timestamp must use innerContent.date"
        )
    }

    // MARK: - DM, msg.timestamp present
    // DMs prefer the relay timestamp when it is present.

    func testDMMessage_withRelayTimestamp_usesRelayTimestamp() {
        let relayTimestamp: UInt64 = 8_888_888
        let innerDate = 1_111_111

        let msg = makeMsg(timestamp: relayTimestamp)
        let inner = makeInnerContent(date: innerDate)

        let sut = GenericIncomingMessage(
            msg: msg,
            csr: nil,
            innerContent: inner,
            isTribeMessage: false
        )

        XCTAssertEqual(
            sut?.timestamp, Int(relayTimestamp),
            "DM message with relay timestamp must use msg.timestamp"
        )
        XCTAssertNotEqual(
            sut?.timestamp, innerDate,
            "DM message with relay timestamp must NOT fall back to innerContent.date"
        )
    }

    // MARK: - DM, msg.timestamp nil
    // DMs fall back to innerContent.date when relay timestamp is absent.

    func testDMMessage_nilRelayTimestamp_usesInnerContentDate() {
        let innerDate = 2_222_222

        let msg = makeMsg(timestamp: nil)
        let inner = makeInnerContent(date: innerDate)

        let sut = GenericIncomingMessage(
            msg: msg,
            csr: nil,
            innerContent: inner,
            isTribeMessage: false
        )

        XCTAssertEqual(
            sut?.timestamp, innerDate,
            "DM message with nil relay timestamp must fall back to innerContent.date"
        )
    }
}
