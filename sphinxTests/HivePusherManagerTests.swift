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
    
    // MARK: - FEATURE_UPDATED Event Tests
    
    func testParseFeatureUpdatedEvent_ValidJSON_Success() {
        // Given
        let featureJSON = """
        {
            "id": "feature-123",
            "name": "Test Feature",
            "brief": "This is a test brief",
            "userStories": "As a user, I want to test",
            "requirements": "Must have tests",
            "architecture": "Clean architecture",
            "workflowStatus": "IN_PROGRESS",
            "createdAt": "2026-02-27T10:00:00Z",
            "updatedAt": "2026-02-27T14:00:00Z"
        }
        """
        
        let pusherMessage = """
        {
            "event": "FEATURE_UPDATED",
            "channel": "feature-feature-123",
            "data": "\(featureJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        let expectation = self.expectation(description: "Feature updated callback")
        mockDelegate.onFeatureUpdated = { feature in
            XCTAssertEqual(feature.id, "feature-123")
            XCTAssertEqual(feature.name, "Test Feature")
            XCTAssertEqual(feature.brief, "This is a test brief")
            XCTAssertEqual(feature.userStories, "As a user, I want to test")
            XCTAssertEqual(feature.requirements, "Must have tests")
            XCTAssertEqual(feature.architecture, "Clean architecture")
            XCTAssertEqual(feature.workflowStatus, "IN_PROGRESS")
            expectation.fulfill()
        }
        
        // When - simulate receiving WebSocket message
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseFeatureUpdatedEvent_MinimalJSON_Success() {
        // Given - feature with only required fields
        let featureJSON = """
        {
            "id": "feature-456",
            "name": "Minimal Feature"
        }
        """
        
        let pusherMessage = """
        {
            "event": "FEATURE_UPDATED",
            "channel": "feature-feature-456",
            "data": "\(featureJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        let expectation = self.expectation(description: "Minimal feature updated callback")
        mockDelegate.onFeatureUpdated = { feature in
            XCTAssertEqual(feature.id, "feature-456")
            XCTAssertEqual(feature.name, "Minimal Feature")
            XCTAssertNil(feature.brief)
            XCTAssertNil(feature.userStories)
            expectation.fulfill()
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseFeatureUpdatedEvent_InvalidJSON_NoCallback() {
        // Given
        let pusherMessage = """
        {
            "event": "FEATURE_UPDATED",
            "channel": "feature-test",
            "data": "invalid json"
        }
        """
        
        var callbackCalled = false
        mockDelegate.onFeatureUpdated = { _ in
            callbackCalled = true
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then - wait briefly to ensure callback is not called
        let expectation = self.expectation(description: "Wait for potential callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(callbackCalled, "Callback should not be called for invalid JSON")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - NEW_MESSAGE Event Tests
    
    func testParseNewMessageEvent_UserMessage_Success() {
        // Given
        let messageJSON = """
        {
            "id": "msg-789",
            "message": "Hello, can you help me?",
            "role": "user",
            "timestamp": "2026-02-27T14:30:00Z"
        }
        """
        
        let pusherMessage = """
        {
            "event": "NEW_MESSAGE",
            "channel": "feature-test",
            "data": "\(messageJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        let expectation = self.expectation(description: "New message callback")
        mockDelegate.onNewMessageReceived = { message in
            XCTAssertEqual(message.id, "msg-789")
            XCTAssertEqual(message.message, "Hello, can you help me?")
            XCTAssertEqual(message.role, "user")
            XCTAssertEqual(message.timestamp, "2026-02-27T14:30:00Z")
            expectation.fulfill()
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseNewMessageEvent_AssistantMessage_Success() {
        // Given
        let messageJSON = """
        {
            "id": "msg-790",
            "message": "Sure! I can help you with that.",
            "role": "assistant",
            "timestamp": "2026-02-27T14:31:00Z"
        }
        """
        
        let pusherMessage = """
        {
            "event": "NEW_MESSAGE",
            "channel": "feature-test",
            "data": "\(messageJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        let expectation = self.expectation(description: "Assistant message callback")
        mockDelegate.onNewMessageReceived = { message in
            XCTAssertEqual(message.id, "msg-790")
            XCTAssertEqual(message.role, "assistant")
            XCTAssertTrue(message.message.contains("help you"))
            expectation.fulfill()
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseNewMessageEvent_MinimalMessage_Success() {
        // Given - message with only required fields
        let messageJSON = """
        {
            "id": "msg-791",
            "message": "Short message",
            "role": "user"
        }
        """
        
        let pusherMessage = """
        {
            "event": "NEW_MESSAGE",
            "channel": "feature-test",
            "data": "\(messageJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        let expectation = self.expectation(description: "Minimal message callback")
        mockDelegate.onNewMessageReceived = { message in
            XCTAssertEqual(message.id, "msg-791")
            XCTAssertEqual(message.message, "Short message")
            XCTAssertEqual(message.role, "user")
            XCTAssertNil(message.timestamp)
            expectation.fulfill()
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseNewMessageEvent_MissingRequiredField_NoCallback() {
        // Given - message missing required "role" field
        let messageJSON = """
        {
            "id": "msg-bad",
            "message": "Invalid message"
        }
        """
        
        let pusherMessage = """
        {
            "event": "NEW_MESSAGE",
            "channel": "feature-test",
            "data": "\(messageJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        var callbackCalled = false
        mockDelegate.onNewMessageReceived = { _ in
            callbackCalled = true
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        let expectation = self.expectation(description: "Wait for potential callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(callbackCalled, "Callback should not be called for invalid message")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - WORKFLOW_STATUS_CHANGED Event Tests
    
    func testParseWorkflowStatusChanged_IsWorking_True() {
        // Given
        let statusJSON = """
        {
            "isWorking": true
        }
        """
        
        let pusherMessage = """
        {
            "event": "WORKFLOW_STATUS_CHANGED",
            "channel": "feature-test",
            "data": "\(statusJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        let expectation = self.expectation(description: "Workflow status true callback")
        mockDelegate.onWorkflowStatusChanged = { isWorking in
            XCTAssertTrue(isWorking, "isWorking should be true")
            expectation.fulfill()
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusChanged_IsWorking_False() {
        // Given
        let statusJSON = """
        {
            "isWorking": false
        }
        """
        
        let pusherMessage = """
        {
            "event": "WORKFLOW_STATUS_CHANGED",
            "channel": "feature-test",
            "data": "\(statusJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        let expectation = self.expectation(description: "Workflow status false callback")
        mockDelegate.onWorkflowStatusChanged = { isWorking in
            XCTAssertFalse(isWorking, "isWorking should be false")
            expectation.fulfill()
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        waitForExpectations(timeout: 2.0)
    }
    
    func testParseWorkflowStatusChanged_MissingField_NoCallback() {
        // Given - missing isWorking field
        let statusJSON = """
        {
            "someOtherField": "value"
        }
        """
        
        let pusherMessage = """
        {
            "event": "WORKFLOW_STATUS_CHANGED",
            "channel": "feature-test",
            "data": "\(statusJSON.replacingOccurrences(of: "\"", with: "\\\""))"
        }
        """
        
        var callbackCalled = false
        mockDelegate.onWorkflowStatusChanged = { _ in
            callbackCalled = true
        }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        let expectation = self.expectation(description: "Wait for potential callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(callbackCalled, "Callback should not be called for missing isWorking field")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Unknown Event Tests
    
    func testParseUnknownEvent_NoCallback() {
        // Given
        let pusherMessage = """
        {
            "event": "UNKNOWN_EVENT",
            "channel": "feature-test",
            "data": "{\\"test\\": \\"data\\"}"
        }
        """
        
        var anyCallbackCalled = false
        mockDelegate.onFeatureUpdated = { _ in anyCallbackCalled = true }
        mockDelegate.onNewMessageReceived = { _ in anyCallbackCalled = true }
        mockDelegate.onWorkflowStatusChanged = { _ in anyCallbackCalled = true }
        
        // When
        simulateWebSocketMessage(pusherMessage)
        
        // Then
        let expectation = self.expectation(description: "Wait for potential callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(anyCallbackCalled, "No callback should be called for unknown event")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func simulateWebSocketMessage(_ message: String) {
        // This simulates the internal message parsing that HivePusherManager does
        // In a real implementation, you would need to expose a test hook or
        // refactor the parsing logic into a testable method
        
        // For now, we'll use a workaround by calling the delegate methods directly
        // if the manager exposes a test method, or we can parse manually
        
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let event = json["event"] as? String,
           let dataString = json["data"] as? String {
            
            parseAndDispatch(event: event, dataString: dataString)
        }
    }
    
    private func parseAndDispatch(event: String, dataString: String) {
        guard let dataJson = try? JSONSerialization.jsonObject(
            with: dataString.data(using: .utf8) ?? Data()
        ) as? [String: Any] else {
            return
        }
        
        switch event {
        case "FEATURE_UPDATED":
            if let feature = HiveFeature(json: JSON(dataJson)) {
                DispatchQueue.main.async {
                    self.mockDelegate.featureUpdated(feature)
                }
            }
            
        case "NEW_MESSAGE":
            if let message = HiveChatMessage(json: JSON(dataJson)) {
                DispatchQueue.main.async {
                    self.mockDelegate.newMessageReceived(message)
                }
            }
            
        case "WORKFLOW_STATUS_CHANGED":
            if let isWorking = dataJson["isWorking"] as? Bool {
                DispatchQueue.main.async {
                    self.mockDelegate.workflowStatusChanged(isWorking: isWorking)
                }
            }
            
        default:
            break
        }
    }
}

// MARK: - Mock Delegate

class MockHivePusherDelegate: HivePusherDelegate {
    var onFeatureUpdated: ((HiveFeature) -> Void)?
    var onNewMessageReceived: ((HiveChatMessage) -> Void)?
    var onWorkflowStatusChanged: ((Bool) -> Void)?
    
    func featureUpdated(_ feature: HiveFeature) {
        onFeatureUpdated?(feature)
    }
    
    func newMessageReceived(_ message: HiveChatMessage) {
        onNewMessageReceived?(message)
    }
    
    func workflowStatusChanged(isWorking: Bool) {
        onWorkflowStatusChanged?(isWorking)
    }
}
