//
//  HiveAnyCableManagerTests.swift
//  sphinxTests
//
//  Created on 2026-03-06.
//  Copyright © 2026 sphinx. All rights reserved.
//

import XCTest
import Starscream
@testable import sphinx

// MARK: - Mock WebSocketClient

/// A test double for Starscream's WebSocketClient that records sent strings
/// and lets tests simulate incoming server frames via the delegate.
class MockWebSocketClient: WebSocketClient {
    weak var delegate: WebSocketDelegate?
    var sentStrings: [String] = []
    var didCallConnect = false
    var didCallDisconnect = false

    func connect() {
        didCallConnect = true
        delegate?.websocketDidConnect(socket: self)
    }

    func disconnect(forceTimeout: TimeInterval?, closeCode: UInt16) {
        didCallDisconnect = true
        delegate?.websocketDidDisconnect(socket: self, error: nil)
    }

    func write(string: String, completion: (() -> Void)?) {
        sentStrings.append(string)
        completion?()
    }

    func write(data: Data, completion: (() -> Void)?) {}
    func write(ping: Data, completion: (() -> Void)?) {}
    func write(pong: Data, completion: (() -> Void)?) {}

    /// Simulate the server pushing a text frame to the manager.
    func simulateReceiveText(_ text: String) {
        delegate?.websocketDidReceiveMessage(socket: self, text: text)
    }
}

// MARK: - Mock HiveAnyCableDelegate

class MockHiveAnyCableDelegate: HiveAnyCableDelegate {
    var receivedProjectIds: [Int] = []

    func workflowStepUpdateReceived(projectId: Int) {
        receivedProjectIds.append(projectId)
    }
}

// MARK: - HiveAnyCableManagerTests

class HiveAnyCableManagerTests: XCTestCase {

    var manager: HiveAnyCableManager!
    var mockDelegate: MockHiveAnyCableDelegate!
    var mockSocket: MockWebSocketClient!

    override func setUp() {
        super.setUp()
        manager = HiveAnyCableManager()
        mockDelegate = MockHiveAnyCableDelegate()
        mockSocket = MockWebSocketClient()

        manager.delegate = mockDelegate
        // Wire the mock socket as the manager's socket and its delegate back to the manager
        mockSocket.delegate = manager
        manager.socket = mockSocket
    }

    override func tearDown() {
        manager = nil
        mockDelegate = nil
        mockSocket = nil
        super.tearDown()
    }

    // MARK: - connect() is a no-op when no hive token is stored

    func testConnect_NoToken_SkipsSocketCreation() {
        // Ensure no token is stored
        UserDefaults.Keys.hiveToken.set(nil as String?)

        let freshManager = HiveAnyCableManager()
        freshManager.delegate = mockDelegate

        // connect() should bail early — socket stays nil
        freshManager.connect(projectId: 42)

        XCTAssertNil(freshManager.socket, "Socket should not be created without a hive token")
        XCTAssertTrue(mockDelegate.receivedProjectIds.isEmpty)
    }

    // MARK: - websocketDidConnect sends correctly-formatted subscribe JSON

    func testWebsocketDidConnect_SendsSubscribeCommand() {
        manager.projectId = 123

        // Simulate the socket connecting
        manager.websocketDidConnect(socket: mockSocket)

        XCTAssertEqual(mockSocket.sentStrings.count, 1, "Should send exactly one string on connect")

        let sent = mockSocket.sentStrings[0]
        guard let data = sent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            XCTFail("Sent string is not valid JSON dictionary: \(sent)")
            return
        }

        XCTAssertEqual(json["command"], "subscribe")

        let identifier = json["identifier"] ?? ""
        XCTAssertTrue(
            identifier.contains("WorkflowChannel"),
            "identifier should contain WorkflowChannel, got: \(identifier)"
        )
        XCTAssertTrue(
            identifier.contains("123"),
            "identifier should contain projectId 123, got: \(identifier)"
        )
    }

    // MARK: - confirm_subscription sets isSubscribed without calling delegate

    func testConfirmSubscription_SetsFlag_NoDelegate() {
        manager.projectId = 99

        mockSocket.simulateReceiveText("{\"type\":\"confirm_subscription\"}")

        XCTAssertTrue(manager.isSubscribed, "isSubscribed should be true after confirm_subscription")
        XCTAssertTrue(mockDelegate.receivedProjectIds.isEmpty, "Delegate should not be called on confirm_subscription")
    }

    // MARK: - in_progress message calls workflowStepUpdateReceived

    func testInProgressMessage_CallsDelegate() {
        manager.projectId = 77

        mockSocket.simulateReceiveText("{\"message\":{\"status\":\"in_progress\"}}")

        let expectation = self.expectation(description: "Delegate called on main queue")
        DispatchQueue.main.async {
            XCTAssertEqual(self.mockDelegate.receivedProjectIds, [77])
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - completed status does NOT call delegate

    func testCompletedMessage_DoesNotCallDelegate() {
        manager.projectId = 55

        mockSocket.simulateReceiveText("{\"message\":{\"status\":\"completed\"}}")

        let expectation = self.expectation(description: "No delegate for completed")
        DispatchQueue.main.async {
            XCTAssertTrue(self.mockDelegate.receivedProjectIds.isEmpty)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - welcome and ping frames are no-ops

    func testWelcomePingFrames_AreNoOps() {
        manager.projectId = 1

        mockSocket.simulateReceiveText("{\"type\":\"welcome\"}")
        mockSocket.simulateReceiveText("{\"type\":\"ping\"}")

        XCTAssertFalse(manager.isSubscribed)
        XCTAssertTrue(mockDelegate.receivedProjectIds.isEmpty)
    }

    // MARK: - connectAnyCable() is a no-op when cachedStakworkProjectId is nil

    func testConnectAnyCable_NilProjectId_NoDelegate() {
        // When projectId is nil, calling sendSubscribeCommand() (via websocketDidConnect)
        // should not send anything and no delegate should fire.
        manager.projectId = nil
        manager.websocketDidConnect(socket: mockSocket)

        // sendSubscribeCommand guards on projectId being non-nil → nothing sent
        XCTAssertTrue(mockSocket.sentStrings.isEmpty, "No subscribe command should be sent when projectId is nil")
        XCTAssertTrue(mockDelegate.receivedProjectIds.isEmpty)
    }

    // MARK: - disconnect sends unsubscribe when subscribed

    func testDisconnect_WhenSubscribed_SendsUnsubscribe() {
        manager.projectId = 10
        manager.isSubscribed = true

        manager.disconnect()

        XCTAssertTrue(
            mockSocket.sentStrings.contains(where: { $0.contains("unsubscribe") }),
            "disconnect() should send an unsubscribe command when isSubscribed is true"
        )
        XCTAssertNil(manager.projectId)
        XCTAssertFalse(manager.isSubscribed)
    }

    // MARK: - disconnect is clean when not subscribed

    func testDisconnect_WhenNotSubscribed_NoUnsubscribe() {
        manager.projectId = 10
        manager.isSubscribed = false

        manager.disconnect()

        XCTAssertTrue(
            mockSocket.sentStrings.isEmpty,
            "disconnect() should not send unsubscribe when isSubscribed is false"
        )
    }
}
