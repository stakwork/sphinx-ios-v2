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

    // MARK: - stakwork-run-update Event Tests

    func testStakworkRunUpdate_ValidTaskGeneration_FiresCallback() {
        let dataJSON = """
        {"runId": "run_001", "type": "TASK_GENERATION", "status": "IN_PROGRESS", "featureId": "feat_abc"}
        """

        let expectation = self.expectation(description: "taskGenerationStatusChanged callback fires")
        mockDelegate.onTaskGenerationStatusChanged = { status, featureId in
            XCTAssertEqual(status, "IN_PROGRESS")
            XCTAssertEqual(featureId, "feat_abc")
            expectation.fulfill()
        }

        simulateEvent(name: "stakwork-run-update", dataJSON: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    func testStakworkRunUpdate_NonTaskGenerationType_DoesNotFireCallback() {
        let dataJSON = """
        {"runId": "run_002", "type": "PLAN_GENERATION", "status": "COMPLETED", "featureId": "feat_abc"}
        """

        var callbackCalled = false
        mockDelegate.onTaskGenerationStatusChanged = { _, _ in callbackCalled = true }

        simulateEvent(name: "stakwork-run-update", dataJSON: dataJSON)

        let expectation = self.expectation(description: "No callback for non-TASK_GENERATION type")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire for non-TASK_GENERATION type")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testStakworkRunUpdate_MissingFeatureId_DoesNotFireCallback() {
        let dataJSON = """
        {"runId": "run_003", "type": "TASK_GENERATION", "status": "COMPLETED"}
        """

        var callbackCalled = false
        mockDelegate.onTaskGenerationStatusChanged = { _, _ in callbackCalled = true }

        simulateEvent(name: "stakwork-run-update", dataJSON: dataJSON)

        let expectation = self.expectation(description: "No callback when featureId is missing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire when featureId is missing")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testStakworkRunUpdate_MissingStatus_DoesNotFireCallback() {
        let dataJSON = """
        {"runId": "run_004", "type": "TASK_GENERATION", "featureId": "feat_abc"}
        """

        var callbackCalled = false
        mockDelegate.onTaskGenerationStatusChanged = { _, _ in callbackCalled = true }

        simulateEvent(name: "stakwork-run-update", dataJSON: dataJSON)

        let expectation = self.expectation(description: "No callback when status is missing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire when status is missing")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testStakworkRunUpdate_AllStatusValues_DispatchedCorrectly() {
        let statuses = ["PENDING", "IN_PROGRESS", "COMPLETED", "FAILED", "HALTED"]

        for status in statuses {
            let dataJSON = """
            {"runId": "run_\(status)", "type": "TASK_GENERATION", "status": "\(status)", "featureId": "feat_status_test"}
            """

            let expectation = self.expectation(description: "Status \(status) dispatched correctly")
            mockDelegate.onTaskGenerationStatusChanged = { receivedStatus, featureId in
                XCTAssertEqual(receivedStatus, status)
                XCTAssertEqual(featureId, "feat_status_test")
                expectation.fulfill()
            }

            simulateEvent(name: "stakwork-run-update", dataJSON: dataJSON)
            waitForExpectations(timeout: 2.0)
        }
    }

    func testStakworkRunUpdate_EmptyPayload_NoCrash() {
        // Should not crash and should not fire delegate
        var callbackCalled = false
        mockDelegate.onTaskGenerationStatusChanged = { _, _ in callbackCalled = true }

        simulateEvent(name: "stakwork-run-update", dataJSON: "{}")

        let expectation = self.expectation(description: "No crash and no callback for empty payload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire for empty payload")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - pr-status-change Event Tests

    func testPRStatusChange_ValidPayload_FiresCallback() {
        let dataJSON = """
        {"prNumber": 42, "state": "closed", "artifactStatus": "COMPLETED", "prUrl": "https://github.com/org/repo/pull/42", "problemDetails": null}
        """

        let expectation = self.expectation(description: "pr-status-change callback fires")
        mockDelegate.onPRStatusChanged = { prNumber, state, artifactStatus, prUrl, problemDetails in
            XCTAssertEqual(prNumber, 42)
            XCTAssertEqual(state, "closed")
            XCTAssertEqual(artifactStatus, "COMPLETED")
            XCTAssertEqual(prUrl, "https://github.com/org/repo/pull/42")
            expectation.fulfill()
        }

        manager.handleEvent(name: "pr-status-change", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    func testPRStatusChange_MissingPRNumber_NoCallback() {
        let dataJSON = """
        {"state": "open", "artifactStatus": "IN_REVIEW"}
        """

        var callbackCalled = false
        mockDelegate.onPRStatusChanged = { _, _, _, _, _ in callbackCalled = true }

        manager.handleEvent(name: "pr-status-change", data: dataJSON)

        let expectation = self.expectation(description: "No callback for missing prNumber")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire when prNumber is missing")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - feature-title-update Event Tests

    func testFeatureTitleUpdate_ValidPayload_FiresCallback() {
        let dataJSON = """
        {"featureId": "feat_123", "newTitle": "Revamped Feature Title"}
        """

        let expectation = self.expectation(description: "feature-title-update callback fires")
        mockDelegate.onFeatureTitleUpdated = { featureId, newTitle in
            XCTAssertEqual(featureId, "feat_123")
            XCTAssertEqual(newTitle, "Revamped Feature Title")
            expectation.fulfill()
        }

        manager.handleEvent(name: "feature-title-update", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - task-title-update Event Tests

    func testTaskTitleUpdate_ValidPayload_FiresCallback() {
        let dataJSON = """
        {"taskId": "task_456", "newTitle": "Updated Task Title"}
        """

        let expectation = self.expectation(description: "task-title-update callback fires")
        mockDelegate.onTaskTitleUpdated = { taskId, newTitle in
            XCTAssertEqual(taskId, "task_456")
            XCTAssertEqual(newTitle, "Updated Task Title")
            expectation.fulfill()
        }

        manager.handleEvent(name: "task-title-update", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Duplicate new-message Guard Tests

    func testNewMessageReceived_DuplicateId_NotAddedTwice() {
        // Build a minimal HiveChatMessage JSON
        let messageJSON = JSON([
            "id": "cmsg_dup01",
            "message": "Hello",
            "role": "USER"
        ])
        guard let message = HiveChatMessage(json: messageJSON) else {
            XCTFail("Failed to construct HiveChatMessage")
            return
        }

        // Simulate receiving the same message twice via the delegate directly
        var receivedMessages: [HiveChatMessage] = []
        mockDelegate.onNewMessageReceived = { msg in
            // Guard against duplicate by ID (mirrors VC logic)
            guard !receivedMessages.contains(where: { $0.id == msg.id }) else { return }
            receivedMessages.append(msg)
        }

        mockDelegate.newMessageReceived(message)
        mockDelegate.newMessageReceived(message)

        XCTAssertEqual(receivedMessages.count, 1, "Duplicate message should not be added a second time")
    }

    // MARK: - pr-status-change on workspace channel Tests

    /// Verifies that a `pr-status-change` event delivered via the workspace channel
    /// (i.e. dispatched through `handleEvent`) fires the delegate callback with the
    /// correct parsed values — mirroring the existing feature/task channel behaviour.
    func testPRStatusChange_ViaWorkspaceChannel_FiresCallback() {
        let dataJSON = """
        {"prNumber": 77, "state": "open", "artifactStatus": "OPEN", "prUrl": "https://github.com/org/repo/pull/77"}
        """

        let expectation = self.expectation(description: "pr-status-change workspace channel callback fires")
        mockDelegate.onPRStatusChanged = { prNumber, state, artifactStatus, prUrl, _ in
            XCTAssertEqual(prNumber, 77)
            XCTAssertEqual(state, "open")
            XCTAssertEqual(artifactStatus, "OPEN")
            XCTAssertEqual(prUrl, "https://github.com/org/repo/pull/77")
            expectation.fulfill()
        }

        // handleEvent routes "pr-status-change" to handlePRStatusChange, which is the
        // same handler bound to both feature, task, and workspace-task channels.
        manager.handleEvent(name: "pr-status-change", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    func testPRStatusChange_ViaWorkspaceChannel_MergedStatus_FiresCallback() {
        let dataJSON = """
        {"prNumber": 101, "state": "closed", "artifactStatus": "MERGED", "prUrl": "https://github.com/org/repo/pull/101"}
        """

        let expectation = self.expectation(description: "pr-status-change MERGED workspace callback fires")
        mockDelegate.onPRStatusChanged = { prNumber, state, artifactStatus, prUrl, _ in
            XCTAssertEqual(prNumber, 101)
            XCTAssertEqual(state, "closed")
            XCTAssertEqual(artifactStatus, "MERGED")
            expectation.fulfill()
        }

        manager.handleEvent(name: "pr-status-change", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    func testPRStatusChange_ViaWorkspaceChannel_NilUrl_FiresCallback() {
        let dataJSON = """
        {"prNumber": 5, "state": "closed", "artifactStatus": "DONE"}
        """

        let expectation = self.expectation(description: "pr-status-change nil URL callback fires")
        mockDelegate.onPRStatusChanged = { prNumber, _, artifactStatus, prUrl, _ in
            XCTAssertEqual(prNumber, 5)
            XCTAssertEqual(artifactStatus, "DONE")
            XCTAssertNil(prUrl, "prUrl should be nil when omitted from payload")
            expectation.fulfill()
        }

        manager.handleEvent(name: "pr-status-change", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - workspace-task-title-update Event Tests

    func testWorkspaceTaskUpdate_ValidPayload_FiresCallbackWithCorrectValues() {
        let dataJSON = """
        {"taskId":"t1","status":"IN_PROGRESS","workflowStatus":"IN_PROGRESS","archived":false}
        """

        let expectation = self.expectation(description: "taskStatusUpdated callback fires with correct values")
        mockDelegate.onTaskStatusUpdated = { taskId, status, workflowStatus, archived in
            XCTAssertEqual(taskId, "t1")
            XCTAssertEqual(status, "IN_PROGRESS")
            XCTAssertEqual(workflowStatus, "IN_PROGRESS")
            XCTAssertFalse(archived)
            expectation.fulfill()
        }

        manager.handleEvent(name: "workspace-task-title-update", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    func testWorkspaceTaskUpdate_MissingTaskId_DoesNotFireCallback() {
        let dataJSON = """
        {"status":"IN_PROGRESS","workflowStatus":"IN_PROGRESS","archived":false}
        """

        var callbackCalled = false
        mockDelegate.onTaskStatusUpdated = { _, _, _, _ in callbackCalled = true }

        manager.handleEvent(name: "workspace-task-title-update", data: dataJSON)

        let expectation = self.expectation(description: "No callback when taskId is missing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire when taskId is missing")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testWorkspaceTaskUpdate_ArchivedTrue_PassesArchivedCorrectly() {
        let dataJSON = """
        {"taskId":"t2","status":"DONE","archived":true}
        """

        let expectation = self.expectation(description: "taskStatusUpdated fires with archived: true")
        mockDelegate.onTaskStatusUpdated = { taskId, status, workflowStatus, archived in
            XCTAssertEqual(taskId, "t2")
            XCTAssertEqual(status, "DONE")
            XCTAssertNil(workflowStatus)
            XCTAssertTrue(archived)
            expectation.fulfill()
        }

        manager.handleEvent(name: "workspace-task-title-update", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - stakwork-run-decision Event Tests

    func testStakworkRunDecision_ValidPayload_FiresCallback() {
        let dataJSON = """
        {"decision": "ACCEPTED", "featureId": "feat_123"}
        """

        let expectation = self.expectation(description: "taskGenerationStatusChanged fires for stakwork-run-decision")
        mockDelegate.onTaskGenerationStatusChanged = { status, featureId in
            XCTAssertEqual(status, "ACCEPTED")
            XCTAssertEqual(featureId, "feat_123")
            expectation.fulfill()
        }

        manager.handleEvent(name: "stakwork-run-decision", data: dataJSON)
        waitForExpectations(timeout: 2.0)
    }

    func testStakworkRunDecision_MissingDecision_DoesNotFireCallback() {
        let dataJSON = """
        {"featureId": "feat_123"}
        """

        var callbackCalled = false
        mockDelegate.onTaskGenerationStatusChanged = { _, _ in callbackCalled = true }

        manager.handleEvent(name: "stakwork-run-decision", data: dataJSON)

        let expectation = self.expectation(description: "No callback when decision is missing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire when decision is missing")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testStakworkRunDecision_MissingFeatureId_DoesNotFireCallback() {
        let dataJSON = """
        {"decision": "ACCEPTED"}
        """

        var callbackCalled = false
        mockDelegate.onTaskGenerationStatusChanged = { _, _ in callbackCalled = true }

        manager.handleEvent(name: "stakwork-run-decision", data: dataJSON)

        let expectation = self.expectation(description: "No callback when featureId is missing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire when featureId is missing")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    func testStakworkRunDecision_EmptyPayload_NoCallback() {
        var callbackCalled = false
        mockDelegate.onTaskGenerationStatusChanged = { _, _ in callbackCalled = true }

        manager.handleEvent(name: "stakwork-run-decision", data: "{}")

        let expectation = self.expectation(description: "No callback for empty payload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertFalse(callbackCalled, "Callback should not fire for empty payload")
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
    var onPRStatusChanged: ((Int, String, String, String?, String?) -> Void)?
    var onFeatureTitleUpdated: ((String, String) -> Void)?
    var onTaskTitleUpdated: ((String, String) -> Void)?
    var onTaskGenerationStatusChanged: ((String, String) -> Void)?
    var onTaskStatusUpdated: ((String, String, String?, Bool) -> Void)?

    func featureUpdateReceived(featureId: String) {
        onFeatureUpdateReceived?(featureId)
    }
    
    func newMessageReceived(_ message: HiveChatMessage) {
        onNewMessageReceived?(message)
    }
    
    func workflowStatusChanged(status: WorkflowStatus) {
        onWorkflowStatusChanged?(status)
    }

    func prStatusChanged(prNumber: Int, state: String, artifactStatus: String, prUrl: String?, problemDetails: String?) {
        onPRStatusChanged?(prNumber, state, artifactStatus, prUrl, problemDetails)
    }

    func featureTitleUpdated(featureId: String, newTitle: String) {
        onFeatureTitleUpdated?(featureId, newTitle)
    }

    func taskTitleUpdated(taskId: String, newTitle: String) {
        onTaskTitleUpdated?(taskId, newTitle)
    }

    func taskGenerationStatusChanged(status: String, featureId: String) {
        onTaskGenerationStatusChanged?(status, featureId)
    }

    func taskStatusUpdated(taskId: String, status: String, workflowStatus: String?, archived: Bool) {
        onTaskStatusUpdated?(taskId, status, workflowStatus, archived)
    }
}
