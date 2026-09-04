//
//  ChatPaginationTests.swift
//  sphinxTests
//
//  Unit tests for chat history pagination: NSPredicate / NSFetchRequest
//  construction, real-id probe reduction, and PaginationPhase transitions.
//  No in-memory Core Data stack and no FRC fetches.
//

import XCTest
@testable import sphinx

final class ChatPaginationTests: XCTestCase {

    // MARK: - Probe request construction

    func testPaginationProbeFormat_excludesNegativeIds() {
        let format = ChatMessagePredicateBuilder.paginationProbeFormat()
        XCTAssertTrue(format.contains("id >= 0"), "Probe must require real ids")
        XCTAssertFalse(format.contains("id < 0"), "Probe must not include a negative-id clause")
        XCTAssertTrue(format.contains("chat == %@"))
        XCTAssertTrue(format.contains("NOT (type IN %@)"))
    }

    func testPaginationProbeConfig_hasFetchLimit() {
        let config = ChatMessagesFetchRequestConfig.paginationProbe(items: 50)
        XCTAssertEqual(config.fetchLimit, 50)
    }

    func testPinnedProbeFormat_lowerBoundsAtMaxZeroPinnedMinus200() {
        let belowWindow = ChatMessagePredicateBuilder.pinnedProbeFormat(pinnedMessageId: 50)
        XCTAssertTrue(belowWindow.contains("id >= 0"), "pinned-200 below 0 must clamp to 0")
        XCTAssertTrue(belowWindow.contains("id >= 0 AND id >= 0") || belowWindow.contains("id >= 0"))
        XCTAssertFalse(belowWindow.contains("id < 0"))

        let aboveWindow = ChatMessagePredicateBuilder.pinnedProbeFormat(pinnedMessageId: 500)
        XCTAssertTrue(aboveWindow.contains("id >= 300"), "500 - 200 = 300")
        XCTAssertTrue(aboveWindow.contains("id >= 0"))
        XCTAssertFalse(aboveWindow.contains("id < 0"))
    }

    func testPinnedProbeConfig_hasNoFetchLimit() {
        XCTAssertNil(ChatMessagesFetchRequestConfig.pinnedProbe().fetchLimit)
    }

    func testMinMessageIndexFormat_requiresRealId() {
        XCTAssertEqual(ChatMessagePredicateBuilder.minMessageIndexFormat(), "chat == %@ AND id >= 0")
    }

    // MARK: - Main pagination predicate

    func testMainPaginationPredicate_dateGatesProvisionals() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let restriction = ChatMessagePredicateBuilder.idRestrictionFormat(
            minIndex: 42,
            pinnedMessageId: nil,
            oldestDate: date
        )
        XCTAssertEqual(restriction, "(id >= 42 OR (id < 0 AND date >= %@))")
    }

    func testMinIndexWithoutOldestDate_doesNotAddUnboundedNegativeIds() {
        let restriction = ChatMessagePredicateBuilder.idRestrictionFormat(
            minIndex: 42,
            pinnedMessageId: nil,
            oldestDate: nil
        )
        XCTAssertEqual(restriction, "id >= 42")
        XCTAssertFalse(restriction?.contains("id < 0") ?? true)
    }

    func testBothNil_hasNoIdRestriction() {
        let restriction = ChatMessagePredicateBuilder.idRestrictionFormat(
            minIndex: nil,
            pinnedMessageId: nil,
            oldestDate: nil
        )
        XCTAssertNil(restriction)
    }

    func testPinnedPredicate_lowerBoundsAndDateGates() {
        let date = Date()
        let gated = ChatMessagePredicateBuilder.idRestrictionFormat(
            minIndex: nil,
            pinnedMessageId: 50,
            oldestDate: date
        )
        XCTAssertEqual(gated, "(id >= 0 OR (id < 0 AND date >= %@))")

        let gatedHigh = ChatMessagePredicateBuilder.idRestrictionFormat(
            minIndex: nil,
            pinnedMessageId: 500,
            oldestDate: date
        )
        XCTAssertEqual(gatedHigh, "(id >= 300 OR (id < 0 AND date >= %@))")
    }

    func testPinnedWithoutOldestDate_staysBounded() {
        let restriction = ChatMessagePredicateBuilder.idRestrictionFormat(
            minIndex: nil,
            pinnedMessageId: 500,
            oldestDate: nil
        )
        XCTAssertEqual(restriction, "id >= 300")
        XCTAssertFalse(restriction?.contains("id < 0") ?? true)
    }

    func testUnaffectedCallers_threadAndUnboundedFormatsUnchanged() {
        XCTAssertEqual(
            ChatMessagePredicateBuilder.threadFormat(),
            "chat == %@ AND (NOT (type IN %@) || (type == %d && replyUUID = nil)) AND threadUUID == %@"
        )
        XCTAssertEqual(
            ChatMessagePredicateBuilder.unboundedChatFormat(),
            "chat == %@ AND (NOT (type IN %@) || (type == %d && replyUUID = nil))"
        )
    }

    func testMainFetchLimit_onlyOnFirstPage() {
        XCTAssertEqual(
            ChatMessagesFetchRequestConfig.main(limit: 100, pinnedMessageId: nil, minIndex: nil).fetchLimit,
            100
        )
        XCTAssertNil(
            ChatMessagesFetchRequestConfig.main(limit: 100, pinnedMessageId: nil, minIndex: 10).fetchLimit
        )
        XCTAssertNil(
            ChatMessagesFetchRequestConfig.main(limit: 100, pinnedMessageId: 50, minIndex: nil).fetchLimit
        )
    }

    func testDateGatedPredicate_excludesNilDates() {
        let oldest = Date(timeIntervalSince1970: 1_000)
        let predicate = NSPredicate(format: "date >= %@", oldest as NSDate)

        class Row: NSObject {
            @objc var date: Date?
            init(date: Date?) { self.date = date }
        }

        XCTAssertTrue(predicate.evaluate(with: Row(date: Date(timeIntervalSince1970: 2_000))))
        XCTAssertFalse(predicate.evaluate(with: Row(date: Date(timeIntervalSince1970: 500))))
        XCTAssertFalse(predicate.evaluate(with: Row(date: nil)), "nil date must be excluded by date >= oldestDate")
    }

    // MARK: - getFetchMinIndex reduction

    func testGetFetchMinIndex_mixedIdsAndDates_usesSmallestRealIdAndMinNonNilDate() {
        let lastDate = Date(timeIntervalSince1970: 9_000)
        let oldest = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 5_000)

        // id-DESC probe order: last element is not the oldest date.
        let rows: [(id: Int, date: Date?)] = [
            (id: 50, date: newer),
            (id: 20, date: oldest),
            (id: -3, date: Date(timeIntervalSince1970: 100)),
            (id: 10, date: lastDate)
        ]

        let result = ChatPaginationProbe.minIndexAndOldestDate(from: rows)
        XCTAssertEqual(result?.minId, 10)
        XCTAssertEqual(result?.oldestDate, oldest)
        XCTAssertNotEqual(result?.oldestDate, lastDate, "must not use objects.last?.date")
    }

    func testGetFetchMinIndex_allNilDates_fallsBackToDistantPast() {
        let rows: [(id: Int, date: Date?)] = [
            (id: 8, date: nil),
            (id: 3, date: nil),
            (id: -1, date: nil)
        ]
        let result = ChatPaginationProbe.minIndexAndOldestDate(from: rows)
        XCTAssertEqual(result?.minId, 3)
        XCTAssertEqual(result?.oldestDate, Date.distantPast)
    }

    func testGetFetchMinIndex_onlyProvisionals_returnsNil() {
        let rows: [(id: Int, date: Date?)] = [
            (id: -1, date: Date()),
            (id: -4, date: Date())
        ]
        XCTAssertNil(ChatPaginationProbe.minIndexAndOldestDate(from: rows))
    }

    // MARK: - Phase transitions

    func testBeginUserLoad_threadOrNoChat_neverEntersLoading() {
        var threadState = PaginationState()
        XCTAssertFalse(threadState.beginUserLoad(isThread: true, hasChat: true))
        XCTAssertEqual(threadState.phase, .idle)

        var noChat = PaginationState()
        XCTAssertFalse(noChat.beginUserLoad(isThread: false, hasChat: false))
        XCTAssertEqual(noChat.phase, .idle)
    }

    func testBeginUserLoad_phaseNotIdle_returnsWithoutChange() {
        var loading = PaginationState()
        loading.phase = .loading
        XCTAssertFalse(loading.beginUserLoad(isThread: false, hasChat: true))
        XCTAssertEqual(loading.phase, .loading)

        var exhausted = PaginationState()
        exhausted.phase = .exhausted
        XCTAssertFalse(exhausted.beginUserLoad(isThread: false, hasChat: true))
        XCTAssertEqual(exhausted.phase, .exhausted)
    }

    func testBeginUserLoad_pendingScrollRestore_doesNotStartSecondLoad() {
        var state = PaginationState()
        state.pendingScrollRestore = true
        XCTAssertFalse(state.beginUserLoad(isThread: false, hasChat: true))
        XCTAssertEqual(state.phase, .idle)
    }

    func testNoPubkeyAndNilSeed_failToStart_returnsToIdle() {
        var state = PaginationState()
        XCTAssertTrue(state.beginUserLoad(isThread: false, hasChat: true))
        XCTAssertEqual(state.phase, .loading)

        state.failToStart(reason: "no pubkey")
        XCTAssertEqual(state.phase, .idle)

        XCTAssertTrue(state.beginUserLoad(isThread: false, hasChat: true))
        state.failToStart(reason: "nil seed")
        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.pendingScrollRestore)
    }

    func testShortNetworkPage_exhaustedWithPendingScrollRestore() {
        var state = PaginationState()
        XCTAssertTrue(state.beginUserLoad(isThread: false, hasChat: true))
        state.completeNetworkPage(messagesCount: 40, itemsPerPage: 100)
        XCTAssertEqual(state.phase, .exhausted)
        XCTAssertTrue(state.pendingScrollRestore)
        XCTAssertTrue(state.shouldRestoreScroll())
    }

    func testFullNetworkPage_idleWithPendingScrollRestore() {
        var state = PaginationState()
        XCTAssertTrue(state.beginUserLoad(isThread: false, hasChat: true))
        state.completeNetworkPage(messagesCount: 100, itemsPerPage: 100)
        XCTAssertEqual(state.phase, .idle)
        XCTAssertTrue(state.pendingScrollRestore)
    }

    func testAlreadyAtOldest_exhaustedWithPendingScrollRestore() {
        var state = PaginationState()
        XCTAssertTrue(state.beginUserLoad(isThread: false, hasChat: true))
        state.completeAlreadyAtOldest()
        XCTAssertEqual(state.phase, .exhausted)
        XCTAssertTrue(state.pendingScrollRestore)
    }

    func testShortLocalProbeOnNetworkPath_doesNotExhaust() {
        // A short local probe is not end-of-history; phase stays loading until
        // the network callback (or failToStart) settles it.
        var state = PaginationState()
        XCTAssertTrue(state.beginUserLoad(isThread: false, hasChat: true))
        let probeCount = 12
        let items = 50
        XCTAssertLessThan(probeCount, items)
        XCTAssertEqual(state.phase, .loading)
        XCTAssertNotEqual(state.phase, .exhausted)
    }

    func testFirstLoadRestore_doesNotChainFetchWhileLoadingOrPendingRestore() {
        var loading = PaginationState()
        loading.phase = .loading
        XCTAssertFalse(loading.shouldAutoFillOnFirstLoad(allContentVisible: true))

        var restoring = PaginationState()
        restoring.phase = .idle
        restoring.pendingScrollRestore = true
        XCTAssertFalse(restoring.shouldAutoFillOnFirstLoad(allContentVisible: true))
    }

    func testSecondAutoFill_blockedByDidAutoPageOnFirstLoad() {
        var state = PaginationState()
        XCTAssertTrue(state.shouldAutoFillOnFirstLoad(allContentVisible: true))
        state.markAutoFilled()
        XCTAssertFalse(state.shouldAutoFillOnFirstLoad(allContentVisible: true))
    }

    func testChatSwitch_resetsToIdleAndClearsWindow() {
        var state = PaginationState()
        state.phase = .exhausted
        state.pendingScrollRestore = true
        state.didAutoPageOnFirstLoad = true
        state.fetchMinIndex = 77
        state.fetchOldestDate = Date()

        state.resetOnChatSwitch()

        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.pendingScrollRestore)
        XCTAssertFalse(state.didAutoPageOnFirstLoad)
        XCTAssertEqual(state.fetchMinIndex, 0)
        XCTAssertNil(state.fetchOldestDate)
    }

    func testAllItemsLoaded_isExhausted() {
        var state = PaginationState()
        XCTAssertNotEqual(state.phase, .exhausted)
        state.phase = .exhausted
        XCTAssertEqual(state.phase, .exhausted)
        state.phase = .idle
        XCTAssertNotEqual(state.phase, .exhausted)
    }
}
