//
//  AIAgentThreadingRulesTests.swift
//  sphinxTests
//
//  Unit tests for AIAgentThreadingRules: pure wire-value / validation / grouping
//  / formatting rules that make the Sphinx Agent thread- and reply-aware.
//  No Core Data is involved — everything here operates on plain value types.
//

import XCTest
@testable import sphinx

final class AIAgentThreadingRulesTests: XCTestCase {

    // MARK: - Wire values

    func test_wireValues_caseA_noThreadNoReply() {
        let result = AIAgentThreadingRules.wireValues(threadUUID: nil, replyTo: nil)
        XCTAssertNil(result.thread)
        XCTAssertNil(result.reply)
    }

    func test_wireValues_caseE_threadOnly() {
        let result = AIAgentThreadingRules.wireValues(threadUUID: "thread-1", replyTo: nil)
        XCTAssertEqual(result.thread, "thread-1")
        XCTAssertNil(result.reply)
    }

    func test_wireValues_caseB_replyWithOwnThreadUUID() {
        // R is itself a thread member — its threadUUID should be used.
        let replyTo = AgentMessageRef(
            uuid: "msg-r",
            threadUUID: "thread-r",
            replyUUID: nil,
            chatId: 1
        )
        let result = AIAgentThreadingRules.wireValues(threadUUID: nil, replyTo: replyTo)
        XCTAssertEqual(result.thread, "thread-r")
        XCTAssertEqual(result.reply, "msg-r")
    }

    func test_wireValues_caseD_replyWithNoThreadNoReplyUUID_fallsBackToOwnUUID() {
        // R has no threadUUID and no replyUUID — falls back to R's own uuid.
        let replyTo = AgentMessageRef(
            uuid: "msg-r",
            threadUUID: nil,
            replyUUID: nil,
            chatId: 1
        )
        let result = AIAgentThreadingRules.wireValues(threadUUID: nil, replyTo: replyTo)
        XCTAssertEqual(result.thread, "msg-r")
        XCTAssertEqual(result.reply, "msg-r")
    }

    func test_wireValues_replyUUIDFallback_whenNoThreadUUID() {
        // R has a replyUUID but no threadUUID — wire thread should be R.replyUUID
        // (supports older messages that only carry a flat replyUUID).
        let replyTo = AgentMessageRef(
            uuid: "msg-r",
            threadUUID: nil,
            replyUUID: "older-root",
            chatId: 1
        )
        let result = AIAgentThreadingRules.wireValues(threadUUID: nil, replyTo: replyTo)
        XCTAssertEqual(result.thread, "older-root")
        XCTAssertEqual(result.reply, "msg-r")
    }

    func test_wireValues_explicitThreadWinsOverReplyDerivedThread() {
        // Reply plus an explicit matching thread — the explicit thread wins.
        let replyTo = AgentMessageRef(
            uuid: "msg-r",
            threadUUID: "thread-from-reply",
            replyUUID: nil,
            chatId: 1
        )
        let result = AIAgentThreadingRules.wireValues(threadUUID: "explicit-thread", replyTo: replyTo)
        XCTAssertEqual(result.thread, "explicit-thread")
        XCTAssertEqual(result.reply, "msg-r")
    }

    func test_wireValues_oneToOneReply_stillYieldsNonNilThread() {
        // 1:1 replies intentionally still produce a non-nil wire thread — this
        // matches the composer's behaviour and is not tribe-specific.
        let replyTo = AgentMessageRef(
            uuid: "msg-1to1",
            threadUUID: nil,
            replyUUID: nil,
            chatId: 5
        )
        let result = AIAgentThreadingRules.wireValues(threadUUID: nil, replyTo: replyTo)
        XCTAssertNotNil(result.thread)
        XCTAssertEqual(result.thread, "msg-1to1")
        XCTAssertEqual(result.reply, "msg-1to1")
    }

    // MARK: - validateReplyTarget

    func test_validateReplyTarget_notFound() {
        let result = AIAgentThreadingRules.validateReplyTarget(nil, chatId: 1)
        XCTAssertFalse(result.isOK)
    }

    func test_validateReplyTarget_nilUUID_pending() {
        let ref = AgentMessageRef(uuid: nil, threadUUID: nil, replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateReplyTarget(ref, chatId: 1)
        XCTAssertFalse(result.isOK)
    }

    func test_validateReplyTarget_deleted() {
        let ref = AgentMessageRef(uuid: "u1", threadUUID: nil, replyUUID: nil, chatId: 1, isDeleted: true)
        let result = AIAgentThreadingRules.validateReplyTarget(ref, chatId: 1)
        XCTAssertFalse(result.isOK)
    }

    func test_validateReplyTarget_otherChat() {
        let ref = AgentMessageRef(uuid: "u1", threadUUID: nil, replyUUID: nil, chatId: 2)
        let result = AIAgentThreadingRules.validateReplyTarget(ref, chatId: 1)
        XCTAssertFalse(result.isOK)
    }

    func test_validateReplyTarget_valid() {
        let ref = AgentMessageRef(uuid: "u1", threadUUID: nil, replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateReplyTarget(ref, chatId: 1)
        XCTAssertTrue(result.isOK)
    }

    // MARK: - validateThreadRoot

    func test_validateThreadRoot_rejectedInOneToOneChat() {
        let ref = AgentMessageRef(uuid: "root", threadUUID: nil, replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateThreadRoot(ref, chatId: 1, isTribe: false)
        XCTAssertFalse(result.isOK)
    }

    func test_validateThreadRoot_notFound() {
        let result = AIAgentThreadingRules.validateThreadRoot(nil, chatId: 1, isTribe: true)
        XCTAssertFalse(result.isOK)
    }

    func test_validateThreadRoot_deleted() {
        let ref = AgentMessageRef(uuid: "root", threadUUID: nil, replyUUID: nil, chatId: 1, isDeleted: true)
        let result = AIAgentThreadingRules.validateThreadRoot(ref, chatId: 1, isTribe: true)
        XCTAssertFalse(result.isOK)
    }

    func test_validateThreadRoot_otherChat() {
        let ref = AgentMessageRef(uuid: "root", threadUUID: nil, replyUUID: nil, chatId: 2)
        let result = AIAgentThreadingRules.validateThreadRoot(ref, chatId: 1, isTribe: true)
        XCTAssertFalse(result.isOK)
    }

    func test_validateThreadRoot_memberOfAnotherThreadRejected() {
        // Message itself belongs to a different thread — can't be used as a root.
        let ref = AgentMessageRef(uuid: "msg", threadUUID: "some-other-thread", replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateThreadRoot(ref, chatId: 1, isTribe: true)
        XCTAssertFalse(result.isOK)
    }

    func test_validateThreadRoot_selfReferencingThreadUUIDAccepted() {
        // A root whose threadUUID equals its own uuid is fine (consistent self-reference).
        let ref = AgentMessageRef(uuid: "root", threadUUID: "root", replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateThreadRoot(ref, chatId: 1, isTribe: true)
        XCTAssertTrue(result.isOK)
    }

    func test_validateThreadRoot_validRootWithNoReplies() {
        // Reply count is NOT checked — a root with 0/1 replies is still a valid target.
        let ref = AgentMessageRef(uuid: "root", threadUUID: nil, replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateThreadRoot(ref, chatId: 1, isTribe: true)
        XCTAssertTrue(result.isOK)
    }

    // MARK: - validateThreadReplyConsistency

    func test_validateThreadReplyConsistency_mismatchRejected() {
        // R belongs to thread T1, but we're posting into thread T2.
        let replyTo = AgentMessageRef(uuid: "r", threadUUID: "T1", replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateThreadReplyConsistency(threadUUID: "T2", replyTo: replyTo)
        XCTAssertFalse(result.isOK)
    }

    func test_validateThreadReplyConsistency_replyIsRootAccepted() {
        let replyTo = AgentMessageRef(uuid: "T", threadUUID: nil, replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateThreadReplyConsistency(threadUUID: "T", replyTo: replyTo)
        XCTAssertTrue(result.isOK)
    }

    func test_validateThreadReplyConsistency_replyIsMemberAccepted() {
        let replyTo = AgentMessageRef(uuid: "r", threadUUID: "T", replyUUID: nil, chatId: 1)
        let result = AIAgentThreadingRules.validateThreadReplyConsistency(threadUUID: "T", replyTo: replyTo)
        XCTAssertTrue(result.isOK)
    }

    func test_validateThreadReplyConsistency_notFoundRejected() {
        let result = AIAgentThreadingRules.validateThreadReplyConsistency(threadUUID: "T", replyTo: nil)
        XCTAssertFalse(result.isOK)
    }

    // MARK: - threadRootUUIDs

    func test_threadRootUUIDs_oneReplyDoesNotMakeRoot() {
        let replies = [
            AgentMessageRef(uuid: "m1", threadUUID: "root-1", replyUUID: nil, chatId: 1)
        ]
        let roots = AIAgentThreadingRules.threadRootUUIDs(replies: replies, isTribe: true)
        XCTAssertTrue(roots.isEmpty)
    }

    func test_threadRootUUIDs_twoRepliesMakeRoot() {
        let replies = [
            AgentMessageRef(uuid: "m1", threadUUID: "root-1", replyUUID: nil, chatId: 1),
            AgentMessageRef(uuid: "m2", threadUUID: "root-1", replyUUID: nil, chatId: 1)
        ]
        let roots = AIAgentThreadingRules.threadRootUUIDs(replies: replies, isTribe: true)
        XCTAssertEqual(roots, Set(["root-1"]))
    }

    func test_threadRootUUIDs_nonTribeAlwaysEmpty() {
        let replies = [
            AgentMessageRef(uuid: "m1", threadUUID: "root-1", replyUUID: nil, chatId: 1),
            AgentMessageRef(uuid: "m2", threadUUID: "root-1", replyUUID: nil, chatId: 1)
        ]
        let roots = AIAgentThreadingRules.threadRootUUIDs(replies: replies, isTribe: false)
        XCTAssertTrue(roots.isEmpty)
    }

    // MARK: - groupThreads

    func test_groupThreads_thresholdExcludesSingleReplyThreads() {
        let now = Date()
        let rows = [
            AgentThreadRow(uuid: "a1", threadUUID: "rootA", date: now)
        ]
        let groups = AIAgentThreadingRules.groupThreads(rows: rows)
        XCTAssertTrue(groups.isEmpty)
    }

    func test_groupThreads_sortsByLatestActivityDescending() {
        let now = Date()
        let older = now.addingTimeInterval(-100)
        let newer = now.addingTimeInterval(100)

        let rows = [
            AgentThreadRow(uuid: "a1", threadUUID: "rootA", date: older),
            AgentThreadRow(uuid: "a2", threadUUID: "rootA", date: older.addingTimeInterval(1)),
            AgentThreadRow(uuid: "b1", threadUUID: "rootB", date: newer),
            AgentThreadRow(uuid: "b2", threadUUID: "rootB", date: newer.addingTimeInterval(1))
        ]
        let groups = AIAgentThreadingRules.groupThreads(rows: rows)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.rootUUID, "rootB")
        XCTAssertEqual(groups.last?.rootUUID, "rootA")
    }

    func test_groupThreads_replyCountAndLimit() {
        let now = Date()
        let rows = [
            AgentThreadRow(uuid: "a1", threadUUID: "rootA", date: now),
            AgentThreadRow(uuid: "a2", threadUUID: "rootA", date: now.addingTimeInterval(1)),
            AgentThreadRow(uuid: "a3", threadUUID: "rootA", date: now.addingTimeInterval(2)),
            AgentThreadRow(uuid: "b1", threadUUID: "rootB", date: now.addingTimeInterval(3)),
            AgentThreadRow(uuid: "b2", threadUUID: "rootB", date: now.addingTimeInterval(4))
        ]
        let groups = AIAgentThreadingRules.groupThreads(rows: rows)
        XCTAssertEqual(groups.count, 2)

        let rootAGroup = groups.first(where: { $0.rootUUID == "rootA" })
        XCTAssertEqual(rootAGroup?.replyCount, 3)

        let limited = Array(groups.prefix(1))
        XCTAssertEqual(limited.count, 1)
    }

    // MARK: - formatLine

    func test_formatLine_pendingUUID() {
        let ref = AgentMessageRef(uuid: nil, threadUUID: nil, replyUUID: nil, chatId: 1)
        let line = AIAgentThreadingRules.formatLine(
            ref: ref,
            isOwner: false,
            isTribe: false,
            senderAlias: nil,
            resolvedContactName: "Alice",
            date: Date(),
            content: "hello"
        )
        XCTAssertTrue(line.contains("uuid=pending"))
    }

    func test_formatLine_inThreadMarker() {
        let ref = AgentMessageRef(uuid: "m1", threadUUID: "root-1", replyUUID: nil, chatId: 1)
        let line = AIAgentThreadingRules.formatLine(
            ref: ref,
            isOwner: false,
            isTribe: true,
            senderAlias: "bob",
            resolvedContactName: nil,
            date: Date(),
            content: "in a thread",
            isInThread: true
        )
        XCTAssertTrue(line.contains("[IN THREAD]"))
    }

    func test_formatLine_oneToOneUsesResolvedContactName_notRawQuery() {
        let ref = AgentMessageRef(uuid: "m1", threadUUID: nil, replyUUID: nil, chatId: 1)
        let line = AIAgentThreadingRules.formatLine(
            ref: ref,
            isOwner: false,
            isTribe: false,
            senderAlias: "ignored-tribe-style-alias",
            resolvedContactName: "Alice Resolved",
            date: Date(),
            content: "hi"
        )
        XCTAssertTrue(line.hasPrefix("[Alice Resolved]"))
        XCTAssertFalse(line.contains("ignored-tribe-style-alias"))
    }

    func test_formatLine_tribeNoAliasShowsUnknown_notTribeName() {
        let ref = AgentMessageRef(uuid: "m1", threadUUID: nil, replyUUID: nil, chatId: 1)
        let line = AIAgentThreadingRules.formatLine(
            ref: ref,
            isOwner: false,
            isTribe: true,
            senderAlias: nil,
            resolvedContactName: nil,
            date: Date(),
            content: "hi"
        )
        XCTAssertTrue(line.hasPrefix("[Unknown]"))
    }

    func test_formatLine_ownerShowsMe() {
        let ref = AgentMessageRef(uuid: "m1", threadUUID: nil, replyUUID: nil, chatId: 1)
        let line = AIAgentThreadingRules.formatLine(
            ref: ref,
            isOwner: true,
            isTribe: true,
            senderAlias: "whatever",
            resolvedContactName: nil,
            date: Date(),
            content: "hi"
        )
        XCTAssertTrue(line.hasPrefix("[Me]"))
    }

    func test_formatLine_threadRootMarkerShowsReplyCount() {
        let ref = AgentMessageRef(uuid: "root", threadUUID: "root", replyUUID: nil, chatId: 1)
        let line = AIAgentThreadingRules.formatLine(
            ref: ref,
            isOwner: false,
            isTribe: true,
            senderAlias: "carol",
            resolvedContactName: nil,
            date: Date(),
            content: "root message",
            rootReplyCount: 3
        )
        XCTAssertTrue(line.contains("[THREAD ROOT, 3 replies]"))
    }
}
