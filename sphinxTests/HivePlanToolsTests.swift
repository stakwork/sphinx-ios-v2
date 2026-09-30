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

    func testMatchOrg() {
        XCTAssertEqual(HivePlanFormatter.matchOrg(logins: ["a"], slugsByLogin: [:], slug: "x"), "a")
        XCTAssertEqual(HivePlanFormatter.matchOrg(logins: ["a", "b"], slugsByLogin: ["a": ["y"], "b": ["x"]], slug: "x"), "b")
        XCTAssertNil(HivePlanFormatter.matchOrg(logins: ["a", "b"], slugsByLogin: ["a": ["y"], "b": ["z"]], slug: "x"))
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
}
