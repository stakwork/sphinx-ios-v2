import XCTest
import SwiftyJSON
@testable import sphinx

final class HivePlanToolsTests: XCTestCase {

    func testArtifactOnlyMessageIsKept() {
        let json = JSON(["id": "m1", "role": "ASSISTANT", "message": NSNull(),
                         "artifacts": [["id": "a1", "type": "FORM", "content": ["k": "v"]]]])
        let msg = HiveChatMessage(json: json)
        XCTAssertNotNil(msg)
        XCTAssertEqual(msg?.message, "")
        XCTAssertEqual(msg?.artifacts.first?.contentJSON?["k"].string, "v")
    }

    func testStatusMapper() {
        if case .plannerBusy(let m) = HiveStatusMapper.sendResult(statusCode: 409, body: JSON(["error": "running"])) {
            XCTAssertEqual(m, "running")
        } else { XCTFail() }
        if case .notFound = HiveStatusMapper.sendResult(statusCode: 404, body: nil) {} else { XCTFail() }
        if case .forbidden = HiveStatusMapper.sendResult(statusCode: 403, body: nil) {} else { XCTFail() }
        if case .failed = HiveStatusMapper.sendResult(statusCode: 500, body: nil) {} else { XCTFail() }
    }

    func testOnlyUnauthorizedTriggersRetry() {
        XCTAssertTrue(HiveStatusMapper.shouldReauthAndRetry(statusCode: 401))
        for code in [409, 500, 403, 404, 200] { XCTAssertFalse(HiveStatusMapper.shouldReauthAndRetry(statusCode: code)) }
        XCTAssertFalse(HiveStatusMapper.shouldReauthAndRetry(statusCode: nil))
    }

    func testCreateResultShapes() {
        let wrapped = JSON(["data": ["id": "f1", "title": "T"]])
        let top = JSON(["id": "f2", "title": "T"])
        if case .created(let f) = HiveStatusMapper.createResult(statusCode: 201, body: wrapped) { XCTAssertEqual(f.id, "f1") } else { XCTFail() }
        if case .created(let f) = HiveStatusMapper.createResult(statusCode: 200, body: top) { XCTAssertEqual(f.id, "f2") } else { XCTFail() }
        if case .createdUnparseable = HiveStatusMapper.createResult(statusCode: 200, body: JSON(["ok": true])) {} else { XCTFail() }
        if case .failed(let c) = HiveStatusMapper.createResult(statusCode: 500, body: nil) { XCTAssertEqual(c, 500) } else { XCTFail() }
    }

    func testRepeated401ReauthsExactlyOnce() {
        var reauths = 0
        var hasRetried = false
        for _ in 0..<5 {
            if HiveStatusMapper.shouldReauthAndRetry(statusCode: 401, hasRetried: hasRetried) {
                reauths += 1
                hasRetried = true
            }
        }
        XCTAssertEqual(reauths, 1)
        XCTAssertFalse(HiveStatusMapper.shouldReauthAndRetry(statusCode: 409, hasRetried: false))
    }

    func testOpeningMessageAndCreateReplies() {
        XCTAssertEqual(HivePlanFormatter.openingMessage(title: "T", description: nil), "T")
        XCTAssertEqual(HivePlanFormatter.openingMessage(title: "T", description: "D"), "T\n\nD")
        XCTAssertTrue(HivePlanFormatter.createFeatureMessage(result: .createdUnparseable, seed: nil, workspace: "w").contains("duplicate"))
        XCTAssertTrue(HivePlanFormatter.createFeatureMessage(result: .failed(500), seed: nil, workspace: "w").contains("Failed"))
        let f = HiveFeature(json: JSON(["id": "f1", "title": "T"]))!
        XCTAssertTrue(HivePlanFormatter.createFeatureMessage(result: .created(f), seed: .failed, workspace: "w").contains("f1"))
        XCTAssertTrue(HivePlanFormatter.createFeatureMessage(result: .created(f), seed: .plannerBusy(nil), workspace: "w").contains("do not create"))
    }

    func testFormatPlan() {
        let f = HiveFeature(json: JSON(["id": "f1", "title": "Feat", "workflowStatus": "IN_PROGRESS"]))!
        let text = HivePlanFormatter.formatPlan(f)
        XCTAssertTrue(text.contains(HivePlanFormatter.notWritten))
        XCTAssertTrue(text.contains("WORKING"))
        let idle = HiveFeature(json: JSON(["id": "f2", "title": "F", "brief": "B"]))!
        XCTAssertTrue(HivePlanFormatter.formatPlan(idle).contains("idle"))
    }

    private func clarifyingQuestionMessage(id: String, question: String = "Q1?") -> HiveChatMessage {
        HiveChatMessage(json: JSON([
            "id": id, "role": "ASSISTANT", "message": "",
            "artifacts": [[
                "id": "a-\(id)", "type": "PLAN",
                "content": [
                    "tool_use": "ask_clarifying_questions",
                    "content": [["question": question, "options": ["A", "B"], "type": "single"]]
                ]
            ]]
        ]))!
    }

    private func replyMessage(id: String, replyId: String) -> HiveChatMessage {
        HiveChatMessage(json: JSON(["id": id, "role": "USER", "message": "answer", "replyId": replyId]))!
    }

    func testResolvePlannerMessage_defaultsToLatestOpen() {
        let q1 = clarifyingQuestionMessage(id: "p1")
        let q2 = clarifyingQuestionMessage(id: "p2")
        XCTAssertEqual(
            HivePlanFormatter.resolvePlannerMessage(messages: [q1, q2], plannerMessageId: nil),
            .target(id: "p2")
        )
    }

    func testResolvePlannerMessage_skipsAlreadyAnsweredWhenDefaulting() {
        let q1 = clarifyingQuestionMessage(id: "p1")
        let a1 = replyMessage(id: "u1", replyId: "p1")
        let q2 = clarifyingQuestionMessage(id: "p2")
        XCTAssertEqual(
            HivePlanFormatter.resolvePlannerMessage(messages: [q1, a1, q2], plannerMessageId: nil),
            .target(id: "p2")
        )
    }

    func testResolvePlannerMessage_noOpenQuestions() {
        let q1 = clarifyingQuestionMessage(id: "p1")
        let a1 = replyMessage(id: "u1", replyId: "p1")
        XCTAssertEqual(
            HivePlanFormatter.resolvePlannerMessage(messages: [q1, a1], plannerMessageId: nil),
            .noOpenQuestions
        )
        XCTAssertEqual(HivePlanFormatter.resolvePlannerMessage(messages: [], plannerMessageId: nil), .noOpenQuestions)
    }

    func testResolvePlannerMessage_explicitIdNotPlanMessage_rejected() {
        let notClarifying = HiveChatMessage(json: JSON(["id": "p1", "role": "ASSISTANT", "message": "plain"]))!
        XCTAssertEqual(
            HivePlanFormatter.resolvePlannerMessage(messages: [notClarifying], plannerMessageId: "p1"),
            .invalidMessageId
        )
    }

    func testResolvePlannerMessage_explicitIdFromOtherFeature_rejected() {
        let q1 = clarifyingQuestionMessage(id: "p1")
        XCTAssertEqual(
            HivePlanFormatter.resolvePlannerMessage(messages: [q1], plannerMessageId: "does-not-exist"),
            .invalidMessageId
        )
    }

    func testResolvePlannerMessage_explicitIdAlreadyAnswered() {
        let q1 = clarifyingQuestionMessage(id: "p1")
        let a1 = replyMessage(id: "u1", replyId: "p1")
        XCTAssertEqual(
            HivePlanFormatter.resolvePlannerMessage(messages: [q1, a1], plannerMessageId: "p1"),
            .alreadyAnswered(id: "p1")
        )
    }

    func testResolvePlannerMessage_explicitIdOpen() {
        let q1 = clarifyingQuestionMessage(id: "p1")
        let q2 = clarifyingQuestionMessage(id: "p2")
        XCTAssertEqual(
            HivePlanFormatter.resolvePlannerMessage(messages: [q1, q2], plannerMessageId: "p1"),
            .target(id: "p1")
        )
    }

    func testAnsweredDetectionUsesReplyId() {
        let planner = HiveChatMessage(json: JSON(["id": "p1", "role": "ASSISTANT", "message": "Q"]))!
        let reply = HiveChatMessage(json: JSON(["id": "u1", "role": "USER", "message": "A", "replyId": "p1"]))!
        let other = HiveChatMessage(json: JSON(["id": "u2", "role": "USER", "message": "B"]))!
        XCTAssertEqual(HivePlanFormatter.answeredPlannerMessageIds([planner, reply, other]), ["p1"])
        XCTAssertEqual(HivePlanFormatter.answeredPlannerMessageIds([planner, other]), [])
        XCTAssertFalse(HivePlanFormatter.isClarifyingPlannerMessage(planner))
    }

    func testUserStoriesParsedAsObjectsSortedByOrder() {
        let json = JSON(["id": "f1", "title": "T", "userStories": [
            ["id": "s2", "title": "Second", "order": 1, "completed": false],
            ["id": "s1", "title": "First", "order": 0, "completed": true]
        ]])
        let f = HiveFeature(json: json)!
        XCTAssertEqual(f.userStoryItems.map { $0.title }, ["First", "Second"])
        XCTAssertEqual(f.userStories ?? [], ["Second", "First"])
        let text = HivePlanFormatter.formatPlan(f)
        XCTAssertTrue(text.contains("✓ First"))
        XCTAssertTrue(text.contains("○ Second"))
    }
}
