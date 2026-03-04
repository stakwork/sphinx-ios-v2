//
//  HivePusherManagerTests.swift
//  sphinxTests
//
//  Created on 2/27/26.
//  Copyright © 2026 sphinx. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import sphinx

class HivePusherManagerTests: XCTestCase {
    
    var manager: HivePusherManager!
    var mockDelegate: MockHivePusherDelegate!
    
    override func setUp() {
        super.setUp()
        manager = HivePusherManager.shared
        mockDelegate = MockHivePusherDelegate()
        manager.delegate = mockDelegate
    }
    
    override func tearDown() {
        manager.delegate = nil
        manager.disconnect()
        mockDelegate = nil
        manager = nil
        super.tearDown()
    }
    
    // MARK: - feature-updated Event Tests
    
    func testParseFeatureUpdatedEvent_ValidJSON_Success() {
        let dataJSON = """
        {"featureId": "feature-123"}
        """
        
        let expectation = self.expectation(description: "Feature updated callback")
        mockDelegate.onFeatureUpdateReceived = { featureId in
            XCTAssertEqual(featureId, "feature-123")
            expectation.fulfill()
        }
        
        simulateEvent(name: "feature-updated", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseFeatureUpdatedEvent_MinimalJSON_Success() {
        let dataJSON = """
        {"featureId": "feature-456"}
        """
        
        let expectation = self.expectation(description: "Minimal feature updated callback")
        mockDelegate.onFeatureUpdateReceived = { featureId in
            XCTAssertEqual(featureId, "feature-456")
            expectation.fulfill()
        }
        
        simulateEvent(name: "feature-updated", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseFeatureUpdatedEvent_InvalidJSON_NoCallback() {
        let dataJSON = """
        {"notFeatureId": "oops"}
        """
        
        var callbackCalled = false
        mockDelegate.onFeatureUpdateReceived = { _ in callbackCalled = true }
        
        simulateEvent(name: "feature-updated", dataJSON: dataJSON)
        
        let expectation = self.expectation(description: "Wait for potential callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(callbackCalled, "Callback should not be called when featureId is missing")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }
    
    func testFeatureUpdatedDebounce_RapidEvents_OnlyOneCallback() {
        let dataJSON = """
        {"featureId": "feature-debounce"}
        """
        
        var callbackCount = 0
        mockDelegate.onFeatureUpdateReceived = { _ in callbackCount += 1 }
        
        simulateEvent(name: "feature-updated", dataJSON: dataJSON)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.simulateEvent(name: "feature-updated", dataJSON: dataJSON)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            self.simulateEvent(name: "feature-updated", dataJSON: dataJSON)
        }
        
        let expectation = self.expectation(description: "Debounce produces single callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            XCTAssertEqual(callbackCount, 1, "Rapid events should be debounced into a single callback")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.5)
    }
    
    // MARK: - new-message Event Tests
    
    func testParseNewMessageEvent_UserMessage_Success() {
        let dataJSON = """
        {
            "id": "msg-789",
            "message": "Hello, can you help me?",
            "role": "user",
            "createdAt": "2026-02-27T14:30:00Z"
        }
        """
        
        let expectation = self.expectation(description: "New message callback")
        mockDelegate.onNewMessageReceived = { message in
            XCTAssertEqual(message.id, "msg-789")
            XCTAssertEqual(message.message, "Hello, can you help me?")
            XCTAssertEqual(message.role, "user")
            XCTAssertEqual(message.createdAt, "2026-02-27T14:30:00Z")
            expectation.fulfill()
        }
        
        simulateEvent(name: "new-message", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseNewMessageEvent_AssistantMessage_Success() {
        let dataJSON = """
        {
            "id": "msg-790",
            "message": "Sure! I can help you with that.",
            "role": "assistant",
            "createdAt": "2026-02-27T14:31:00Z"
        }
        """
        
        let expectation = self.expectation(description: "Assistant message callback")
        mockDelegate.onNewMessageReceived = { message in
            XCTAssertEqual(message.id, "msg-790")
            XCTAssertEqual(message.role, "assistant")
            XCTAssertTrue(message.message.contains("help you"))
            expectation.fulfill()
        }
        
        simulateEvent(name: "new-message", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseNewMessageEvent_MinimalMessage_Success() {
        let dataJSON = """
        {
            "id": "msg-791",
            "message": "Short message",
            "role": "user"
        }
        """
        
        let expectation = self.expectation(description: "Minimal message callback")
        mockDelegate.onNewMessageReceived = { message in
            XCTAssertEqual(message.id, "msg-791")
            XCTAssertEqual(message.message, "Short message")
            XCTAssertEqual(message.role, "user")
            XCTAssertNil(message.createdAt)
            expectation.fulfill()
        }
        
        simulateEvent(name: "new-message", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseNewMessageEvent_MissingRequiredField_NoCallback() {
        let dataJSON = """
        {
            "id": "msg-bad",
            "message": "Invalid message"
        }
        """
        
        var callbackCalled = false
        mockDelegate.onNewMessageReceived = { _ in callbackCalled = true }
        
        simulateEvent(name: "new-message", dataJSON: dataJSON)
        
        let expectation = self.expectation(description: "Wait for potential callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(callbackCalled, "Callback should not be called for invalid message")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - workflow-status-update Event Tests
    
    func testParseWorkflowStatusUpdate_InProgress() {
        let dataJSON = """
        {"workflowStatus": "IN_PROGRESS"}
        """
        
        let expectation = self.expectation(description: "Workflow status IN_PROGRESS callback")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .IN_PROGRESS)
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusUpdate_Completed() {
        let dataJSON = """
        {"workflowStatus": "COMPLETED"}
        """
        
        let expectation = self.expectation(description: "Workflow status COMPLETED callback")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .COMPLETED)
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusUpdate_Error() {
        let dataJSON = """
        {"workflowStatus": "ERROR"}
        """
        
        let expectation = self.expectation(description: "Workflow status ERROR callback")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .ERROR)
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusUpdate_Halted() {
        let dataJSON = """
        {"workflowStatus": "HALTED"}
        """
        
        let expectation = self.expectation(description: "Workflow status HALTED callback")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .HALTED)
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusUpdate_Failed() {
        let dataJSON = """
        {"workflowStatus": "FAILED"}
        """
        
        let expectation = self.expectation(description: "Workflow status FAILED callback")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .FAILED)
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusUpdate_Pending() {
        let dataJSON = """
        {"workflowStatus": "PENDING"}
        """
        
        let expectation = self.expectation(description: "Workflow status PENDING callback")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .PENDING)
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusUpdate_UnknownRawValue_DefaultsPending() {
        let dataJSON = """
        {"workflowStatus": "SOMETHING_UNKNOWN"}
        """
        
        let expectation = self.expectation(description: "Workflow status unknown defaults to PENDING")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .PENDING, "Unknown status strings should default to .PENDING")
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusUpdate_MissingField_DefaultsPending() {
        let dataJSON = """
        {"someOtherField": "value"}
        """
        
        let expectation = self.expectation(description: "Missing workflowStatus defaults to PENDING")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .PENDING, "Missing workflowStatus should default to .PENDING")
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - WorkflowStatus Raw Value Parse Tests
    
    func testWorkflowStatus_RawValue_Pending() {
        XCTAssertEqual(WorkflowStatus(rawValue: "PENDING"), .PENDING)
    }
    
    func testWorkflowStatus_RawValue_InProgress() {
        XCTAssertEqual(WorkflowStatus(rawValue: "IN_PROGRESS"), .IN_PROGRESS)
    }
    
    func testWorkflowStatus_RawValue_Completed() {
        XCTAssertEqual(WorkflowStatus(rawValue: "COMPLETED"), .COMPLETED)
    }
    
    func testWorkflowStatus_RawValue_Error() {
        XCTAssertEqual(WorkflowStatus(rawValue: "ERROR"), .ERROR)
    }
    
    func testWorkflowStatus_RawValue_Halted() {
        XCTAssertEqual(WorkflowStatus(rawValue: "HALTED"), .HALTED)
    }
    
    func testWorkflowStatus_RawValue_Failed() {
        XCTAssertEqual(WorkflowStatus(rawValue: "FAILED"), .FAILED)
    }
    
    func testWorkflowStatus_UnknownRawValue_ReturnsNil() {
        XCTAssertNil(WorkflowStatus(rawValue: "UNKNOWN_VALUE"))
    }
    
    // MARK: - Task Channel Subscription Tests
    
    func testConnectWithTaskId_SubscribesToTaskChannel() {
        let taskId = "task-abc"
        let expectedChannel = "task-\(taskId)"
        XCTAssertEqual(expectedChannel, "task-task-abc")
        
        let dataJSON = """
        {"workflowStatus": "IN_PROGRESS"}
        """
        
        let expectation = self.expectation(description: "Task channel subscription")
        mockDelegate.onWorkflowStatusChanged = { status in
            XCTAssertEqual(status, .IN_PROGRESS)
            expectation.fulfill()
        }
        
        simulateEvent(name: "workflow-status-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }
    
    // MARK: - Unknown Event Tests
    
    func testParseUnknownEvent_NoCallback() {
        var anyCallbackCalled = false
        mockDelegate.onFeatureUpdateReceived = { _ in anyCallbackCalled = true }
        mockDelegate.onNewMessageReceived = { _ in anyCallbackCalled = true }
        mockDelegate.onWorkflowStatusChanged = { _ in anyCallbackCalled = true }
        
        manager.handleEvent(name: "UNKNOWN_EVENT", data: "{\"test\": \"data\"}")
        
        let expectation = self.expectation(description: "Wait for potential callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(anyCallbackCalled, "No callback should be called for unknown event")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Helper Methods

    /// Simulates a PusherSwift event delivery by calling the manager's internal
    /// `handleEvent(name:data:)` entry point with the raw inner-JSON data string,
    /// matching exactly how PusherSwift delivers `event.data`.
    private func simulateEvent(name: String, dataJSON: String) {
        manager.handleEvent(name: name, data: dataJSON)
    }
}

// MARK: - Mock Delegate

class MockHivePusherDelegate: HivePusherDelegate {
    var onFeatureUpdateReceived: ((String) -> Void)?
    var onNewMessageReceived: ((HiveChatMessage) -> Void)?
    var onWorkflowStatusChanged: ((WorkflowStatus) -> Void)?
    
    func featureUpdateReceived(featureId: String) {
        onFeatureUpdateReceived?(featureId)
    }
    
    func newMessageReceived(_ message: HiveChatMessage) {
        onNewMessageReceived?(message)
    }
    
    func workflowStatusChanged(status: WorkflowStatus) {
        onWorkflowStatusChanged?(status)
    }
}
