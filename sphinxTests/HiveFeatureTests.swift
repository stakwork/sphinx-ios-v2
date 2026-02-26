import XCTest
import SwiftyJSON
@testable import sphinx

class HiveFeatureTests: XCTestCase {
    
    // MARK: - JSON Parsing Tests
    
    func testHiveFeature_InitWithCompleteJSON() {
        let jsonDict: [String: Any] = [
            "id": "feature-123",
            "name": "User Authentication",
            "brief": "Implement secure user login and registration",
            "userStories": "As a user, I want to log in securely",
            "requirements": "- JWT tokens\n- Password hashing",
            "architecture": "Use OAuth 2.0 with refresh tokens",
            "workflowStatus": "IN_PROGRESS",
            "createdAt": "2024-01-15T10:30:00Z",
            "updatedAt": "2024-01-20T14:45:00Z"
        ]
        
        let json = JSON(jsonDict)
        let feature = HiveFeature(json: json)
        
        XCTAssertNotNil(feature, "HiveFeature should initialize with complete JSON")
        XCTAssertEqual(feature?.id, "feature-123")
        XCTAssertEqual(feature?.name, "User Authentication")
        XCTAssertEqual(feature?.brief, "Implement secure user login and registration")
        XCTAssertEqual(feature?.userStories, "As a user, I want to log in securely")
        XCTAssertEqual(feature?.requirements, "- JWT tokens\n- Password hashing")
        XCTAssertEqual(feature?.architecture, "Use OAuth 2.0 with refresh tokens")
        XCTAssertEqual(feature?.workflowStatus, "IN_PROGRESS")
        XCTAssertEqual(feature?.createdAt, "2024-01-15T10:30:00Z")
        XCTAssertEqual(feature?.updatedAt, "2024-01-20T14:45:00Z")
    }
    
    func testHiveFeature_InitWithMinimalJSON() {
        let jsonDict: [String: Any] = [
            "id": "feature-456",
            "name": "Payment Integration"
        ]
        
        let json = JSON(jsonDict)
        let feature = HiveFeature(json: json)
        
        XCTAssertNotNil(feature, "HiveFeature should initialize with minimal JSON")
        XCTAssertEqual(feature?.id, "feature-456")
        XCTAssertEqual(feature?.name, "Payment Integration")
        XCTAssertNil(feature?.brief)
        XCTAssertNil(feature?.userStories)
        XCTAssertNil(feature?.requirements)
        XCTAssertNil(feature?.architecture)
        XCTAssertNil(feature?.workflowStatus)
        XCTAssertNil(feature?.createdAt)
        XCTAssertNil(feature?.updatedAt)
    }
    
    func testHiveFeature_InitWithMissingId_ReturnsNil() {
        let jsonDict: [String: Any] = [
            "name": "Missing ID Feature"
        ]
        
        let json = JSON(jsonDict)
        let feature = HiveFeature(json: json)
        
        XCTAssertNil(feature, "HiveFeature should return nil when id is missing")
    }
    
    func testHiveFeature_InitWithMissingName_ReturnsNil() {
        let jsonDict: [String: Any] = [
            "id": "feature-789"
        ]
        
        let json = JSON(jsonDict)
        let feature = HiveFeature(json: json)
        
        XCTAssertNil(feature, "HiveFeature should return nil when name is missing")
    }
    
    func testHiveFeature_InitWithEmptyJSON_ReturnsNil() {
        let json = JSON([:])
        let feature = HiveFeature(json: json)
        
        XCTAssertNil(feature, "HiveFeature should return nil with empty JSON")
    }
    
    // MARK: - Workflow Status Tests
    
    func testHiveFeature_WorkflowStatus_COMPLETED() {
        let jsonDict: [String: Any] = [
            "id": "feature-completed",
            "name": "Completed Feature",
            "workflowStatus": "COMPLETED"
        ]
        
        let json = JSON(jsonDict)
        let feature = HiveFeature(json: json)
        
        XCTAssertEqual(feature?.workflowStatus, "COMPLETED")
    }
    
    func testHiveFeature_WorkflowStatus_IN_PROGRESS() {
        let jsonDict: [String: Any] = [
            "id": "feature-in-progress",
            "name": "In Progress Feature",
            "workflowStatus": "IN_PROGRESS"
        ]
        
        let json = JSON(jsonDict)
        let feature = HiveFeature(json: json)
        
        XCTAssertEqual(feature?.workflowStatus, "IN_PROGRESS")
    }
    
    func testHiveFeature_WorkflowStatus_TODO() {
        let jsonDict: [String: Any] = [
            "id": "feature-todo",
            "name": "TODO Feature",
            "workflowStatus": "TODO"
        ]
        
        let json = JSON(jsonDict)
        let feature = HiveFeature(json: json)
        
        XCTAssertEqual(feature?.workflowStatus, "TODO")
    }
    
    // MARK: - Mock Data Tests
    
    func testHiveFeature_MockList_ReturnsMultipleFeatures() {
        let mockFeatures = HiveFeature.mockList()
        
        XCTAssertGreaterThanOrEqual(mockFeatures.count, 3, "Mock list should contain at least 3 features")
    }
    
    func testHiveFeature_MockList_ContainsVariousWorkflowStatuses() {
        let mockFeatures = HiveFeature.mockList()
        
        let statuses = mockFeatures.compactMap { $0.workflowStatus }
        
        XCTAssertTrue(statuses.contains("COMPLETED"), "Mock list should contain COMPLETED status")
        XCTAssertTrue(statuses.contains("IN_PROGRESS"), "Mock list should contain IN_PROGRESS status")
        XCTAssertTrue(statuses.contains("TODO"), "Mock list should contain TODO status")
    }
    
    func testHiveFeature_MockList_AllFeaturesHaveRequiredFields() {
        let mockFeatures = HiveFeature.mockList()
        
        for feature in mockFeatures {
            XCTAssertFalse(feature.id.isEmpty, "Mock feature should have non-empty id")
            XCTAssertFalse(feature.name.isEmpty, "Mock feature should have non-empty name")
        }
    }
}
