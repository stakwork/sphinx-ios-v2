import XCTest
import SwiftyJSON
@testable import sphinx

// NOTE: no live Hive fixtures were available, so these use inline JSON limited to
// field names already parsed by existing models.
final class HivePlanToolsTests: XCTestCase {

    private func feature(_ extra: [String: Any] = [:]) -> HiveFeature {
        var d: [String: Any] = ["id": "f1", "title": "Login"]
        extra.forEach { d[$0.key] = $0.value }
        return HiveFeature(json: JSON(d))!
    }

    func testFormatPlan_emptySectionsAndIdle() {
        let out = HivePlanFormatter.formatPlan(feature(["workflowStatus": "COMPLETED"]))
        XCTAssertEqual(out.components(separatedBy: "(not yet written)").count - 1, 4)
        XCTAssertTrue(out.contains("Planner is idle"))
    }

    func testFormatPlan_inProgress() {
        let out = HivePlanFormatter.formatPlan(
            feature(["workflowStatus": "IN_PROGRESS", "brief": "B", "requirements": "R"])
        )
        XCTAssertTrue(out.contains("currently working"))
        XCTAssertTrue(out.contains("B"))
    }

    func testChatMessage_keepsArtifactOnlyMessage() {
        let json = JSON([
            "id": "m1", "role": "ASSISTANT",
            "artifacts": [["id": "a1", "type": "FORM", "content": ["x": 1]]]
        ])
        let m = HiveChatMessage(json: json)
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.message, "")
        XCTAssertNotNil(m?.artifacts.first?.contentJSON)
    }

    func testStatusMapper() {
        let body = #"{"error":"Planner running"}"#.data(using: .utf8)
        if case .plannerBusy(let msg) = HiveStatusMapper.sendResult(statusCode: 409, body: body) {
            XCTAssertEqual(msg, "Planner running")
        } else { XCTFail("expected plannerBusy") }
        guard case .notFound = HiveStatusMapper.sendResult(statusCode: 404, body: nil) else { return XCTFail() }
        guard case .forbidden = HiveStatusMapper.sendResult(statusCode: 403, body: nil) else { return XCTFail() }
        guard case .failed = HiveStatusMapper.sendResult(statusCode: 500, body: nil) else { return XCTFail() }
    }

    func testRetryPolicy_only401() {
        XCTAssertTrue(HiveRetryPolicy.shouldReauthenticate(statusCode: 401))
        for s in [409, 500, 404, 403, 200] { XCTAssertFalse(HiveRetryPolicy.shouldReauthenticate(statusCode: s)) }
        XCTAssertFalse(HiveRetryPolicy.shouldReauthenticate(statusCode: nil))
    }

    func testCreateParsing() {
        XCTAssertEqual(HiveFeatureParser.parseCreated(json: JSON(["data": ["id": "a", "title": "T"]]))?.id, "a")
        XCTAssertEqual(HiveFeatureParser.parseCreated(json: JSON(["id": "b", "title": "T"]))?.id, "b")
        XCTAssertNil(HiveFeatureParser.parseCreated(json: JSON(["success": true])))
    }

    func testCreateReplies() {
        let f = feature()
        let sent = HivePlanFormatter.createReply(
            title: "t", workspace: "w", result: .created(f),
            seed: .sent(HiveChatMessage(id: "1", message: "", role: "USER")))
        XCTAssertTrue(sent.contains("f1") && sent.contains("planner was started"))
        let busy = HivePlanFormatter.createReply(
            title: "t", workspace: "w", result: .created(f), seed: .plannerBusy(nil))
        XCTAssertTrue(busy.contains("f1") && busy.contains("send_to_planner"))
        XCTAssertTrue(HivePlanFormatter.createReply(
            title: "t", workspace: "w", result: .createdUnparseable, seed: nil).contains("duplicate"))
        XCTAssertTrue(HivePlanFormatter.createReply(
            title: "t", workspace: "w", result: .failed(500), seed: nil).contains("Failed"))
    }

    func testResolveOrgLogin() {
        XCTAssertEqual(HivePlanResolver.resolveOrgLogin(workspaceSlug: "s", logins: ["a"], slugsByLogin: [:]), .login("a"))
        XCTAssertEqual(
            HivePlanResolver.resolveOrgLogin(workspaceSlug: "s", logins: ["a", "b"], slugsByLogin: ["b": ["s"]]),
            .login("b"))
        if case .error = HivePlanResolver.resolveOrgLogin(
            workspaceSlug: "s", logins: ["a", "b"], slugsByLogin: ["a": ["x"]]) {} else { XCTFail() }
    }

    func testFindFeature_pagination() async {
        func page(_ id: String, more: Bool) -> ([HiveFeature], PaginationInfo) {
            ([feature(["id": id, "title": id])], PaginationInfo(json: JSON(["hasMore": more])))
        }
        var calls = 0
        let found = await HivePlanResolver.findFeature(
            fetchPage: { p in calls += 1; return p == 1 ? page("one", more: true) : page("two", more: false) },
            matcher: { $0.first(where: { $0.title == "two" }) })
        XCTAssertEqual(found?.id, "two")
        XCTAssertEqual(calls, 2)

        calls = 0
        let none = await HivePlanResolver.findFeature(
            fetchPage: { _ in calls += 1; return page("x", more: true) }, matcher: { _ in nil })
        XCTAssertNil(none)
        XCTAssertEqual(calls, HivePlanResolver.maxFeaturePages)
    }
}
