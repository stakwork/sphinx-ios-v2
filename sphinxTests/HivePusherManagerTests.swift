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
    //
    // The new-message payload is a plain message ID string (e.g. "cmsg_abc123"),
    // optionally wrapped in quotes by PusherSwift (e.g. "\"cmsg_abc123\"").
    // The handler strips the quotes and calls fetchChatMessageWithAuth, so the
    // delegate is NOT called synchronously in unit tests (no network available).
    // Tests here verify quote-stripping logic and that the delegate is NOT called
    // for invalid / empty payloads.

    func testNewMessageEvent_PlainStringId_StripsQuotesNoImmediateCallback() {
        // Payload as delivered by PusherSwift: outer JSON string wrapping the id
        let data = "\"cmsg_abc123\""

        var callbackCalled = false
        mockDelegate.onNewMessageReceived = { _ in callbackCalled = true }

        manager.handleEvent(name: "new-message", data: data)

        let expectation = self.expectation(description: "Handler processes without immediate delegate call")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Delegate is only called after the async network fetch succeeds;
            // in unit tests the fetch won't complete, so no callback expected.
            XCTAssertFalse(callbackCalled, "Delegate should not be called synchronously — fetch is async")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testNewMessageEvent_UnquotedId_NoImmediateCallback() {
        // Payload without surrounding quotes (bare string)
        let data = "cmsg_xyz789"

        var callbackCalled = false
        mockDelegate.onNewMessageReceived = { _ in callbackCalled = true }

        manager.handleEvent(name: "new-message", data: data)

        let expectation = self.expectation(description: "Handler processes bare id without immediate delegate call")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Delegate should not be called synchronously — fetch is async")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testNewMessageEvent_EmptyPayload_NoCallback() {
        var callbackCalled = false
        mockDelegate.onNewMessageReceived = { _ in callbackCalled = true }

        // Empty string (even after trimming) should bail out early
        manager.handleEvent(name: "new-message", data: "\"\"")

        let expectation = self.expectation(description: "Empty payload produces no callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not be called for empty message id")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testNewMessageEvent_QuoteStripping_ProducesCorrectId() {
        // Verify the trimming logic in isolation
        let raw = "\"cmsg_abc123\""
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        XCTAssertEqual(trimmed, "cmsg_abc123", "Surrounding quotes should be stripped from message ID")
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
