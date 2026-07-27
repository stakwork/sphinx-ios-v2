import XCTest
import SwiftyJSON
@testable import sphinx

class WorkflowVersionTests: XCTestCase {

    func testWorkflowVersion_InitWithCompleteJSON() {
        let jsonDict: [String: Any] = [
            "workflow_version_id": 42,
            "workflow_id": 7,
            "workflow_name": "My Workflow",
            "ref_id": "550e8400-e29b-41d4-a716-446655440000",
            "published": true
        ]
        let version = WorkflowVersion(json: JSON(jsonDict))

        XCTAssertNotNil(version, "WorkflowVersion should initialize with complete JSON")
        XCTAssertEqual(version?.versionId, 42)
        XCTAssertEqual(version?.workflowId, 7)
        XCTAssertEqual(version?.workflowName, "My Workflow")
        XCTAssertEqual(version?.refId, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(version?.workflowVersionId, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertTrue(version?.published == true)
    }

    func testWorkflowVersion_InitWithMinimalJSON() {
        let jsonDict: [String: Any] = [
            "workflow_version_id": 1,
            "workflow_id": 3
        ]
        let version = WorkflowVersion(json: JSON(jsonDict))

        XCTAssertNotNil(version, "WorkflowVersion should initialize with only required fields")
        XCTAssertEqual(version?.versionId, 1)
        XCTAssertEqual(version?.workflowId, 3)
        XCTAssertNil(version?.workflowName)
        XCTAssertNil(version?.refId)
        XCTAssertNil(version?.workflowVersionId)
        XCTAssertFalse(version?.published == true)
    }

    func testWorkflowVersion_InitMissingVersionId_ReturnsNil() {
        let jsonDict: [String: Any] = [
            "workflow_id": 5,
            "workflow_name": "No Version ID"
        ]
        let version = WorkflowVersion(json: JSON(jsonDict))

        XCTAssertNil(version, "WorkflowVersion should return nil when workflow_version_id is missing")
    }

    func testWorkflowVersion_InitMissingWorkflowId_ReturnsNil() {
        let jsonDict: [String: Any] = [
            "workflow_version_id": 10,
            "workflow_name": "No Workflow ID"
        ]
        let version = WorkflowVersion(json: JSON(jsonDict))

        XCTAssertNil(version, "WorkflowVersion should return nil when workflow_id is missing")
    }

    func testWorkflowVersion_PublishedDefaultsFalse() {
        let jsonDict: [String: Any] = [
            "workflow_version_id": 99,
            "workflow_id": 2
        ]
        let version = WorkflowVersion(json: JSON(jsonDict))

        XCTAssertNotNil(version)
        XCTAssertFalse(version?.published == true, "published should default to false when absent from JSON")
    }
}
