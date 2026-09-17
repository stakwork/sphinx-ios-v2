//
//  CallParticipantsSocketManagerTests.swift
//  sphinxTests
//
//  Retain-until-disconnect for the Starscream call-participants socket:
//  last-room unsubscribe parks the client until websocketDidDisconnect
//  (or a hang timeout), and subscribe during disconnect must not write.
//

import XCTest
import Starscream
@testable import sphinx

final class CallParticipantsSocketManagerTests: XCTestCase {

    private var manager: CallParticipantsSocketManager!
    private var mockSocket: RecordingWebSocketClient!

    override func setUp() {
        super.setUp()
        CallParticipantsSocketManager.resetDisconnectingStateForTests()
        manager = CallParticipantsSocketManager()
        mockSocket = RecordingWebSocketClient()
        mockSocket.autoFireDisconnect = false
        mockSocket.delegate = manager
        manager.socket = mockSocket
        manager.disconnectHangTimeout = 5.0
    }

    override func tearDown() {
        manager.disconnectHangTimeout = 5.0
        CallParticipantsSocketManager.resetDisconnectingStateForTests()
        manager = nil
        mockSocket = nil
        super.tearDown()
    }

    func test_unsubscribeLastRoom_doesNotNilSocketUntilDidDisconnect() {
        manager.subscribedRooms = ["room-1"]
        manager.unsubscribe(roomName: "room-1")

        XCTAssertTrue(manager.subscribedRooms.isEmpty)
        XCTAssertTrue(manager.isDisconnecting)
        XCTAssertTrue(mockSocket.didCallDisconnect)
        XCTAssertNotNil(manager.socket)
        XCTAssertTrue(manager.socket === mockSocket)
        XCTAssertTrue(CallParticipantsSocketManager.isRetainedForDisconnect(manager))

        manager.websocketDidDisconnect(socket: mockSocket, error: nil)

        XCTAssertNil(manager.socket)
        XCTAssertFalse(manager.isDisconnecting)
        XCTAssertFalse(CallParticipantsSocketManager.isRetainedForDisconnect(manager))
    }

    func test_subscribeWhileDisconnecting_doesNotWrite() {
        manager.subscribedRooms = ["room-1"]
        manager.unsubscribe(roomName: "room-1")
        mockSocket.sentStrings.removeAll()

        XCTAssertTrue(manager.isDisconnecting)
        manager.subscribe(roomName: "room-2")

        XCTAssertTrue(manager.subscribedRooms.contains("room-2"))
        XCTAssertTrue(
            mockSocket.sentStrings.isEmpty,
            "subscribe during disconnect must not write on the dying socket"
        )
        XCTAssertTrue(manager.isDisconnecting)
        XCTAssertNotNil(manager.socket)
    }

    func test_hangTimeout_nilsSocketAndDropsStaticRetain() {
        manager.disconnectHangTimeout = 0.05
        manager.subscribedRooms = ["room-1"]
        manager.unsubscribe(roomName: "room-1")

        XCTAssertTrue(manager.isDisconnecting)
        XCTAssertNotNil(manager.socket)
        XCTAssertTrue(CallParticipantsSocketManager.isRetainedForDisconnect(manager))

        let exp = expectation(description: "hang timeout releases socket")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertNil(self.manager.socket)
            XCTAssertFalse(self.manager.isDisconnecting)
            XCTAssertFalse(CallParticipantsSocketManager.isRetainedForDisconnect(self.manager))
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func test_subscribeDuringDisconnect_reconnectsAfterDidDisconnect() {
        let reconnectSocket = RecordingWebSocketClient()
        reconnectSocket.autoFireDisconnect = false
        manager.socketFactory = { [unowned self] in
            reconnectSocket.delegate = self.manager
            return reconnectSocket
        }

        manager.subscribedRooms = ["room-1"]
        manager.unsubscribe(roomName: "room-1")
        manager.subscribe(roomName: "room-2")
        XCTAssertTrue(manager.isDisconnecting)
        XCTAssertTrue(mockSocket.sentStrings.filter { $0.contains("subscribe") && $0.contains("room-2") }.isEmpty)

        manager.websocketDidDisconnect(socket: mockSocket, error: nil)

        XCTAssertFalse(manager.isDisconnecting)
        XCTAssertTrue(manager.socket === reconnectSocket)
        XCTAssertTrue(reconnectSocket.didCallConnect)
        XCTAssertTrue(reconnectSocket.sentStrings.contains(where: { $0.contains("room-2") }))
    }
}

/// Starscream test double that records writes/disconnect and optionally withholds
/// `websocketDidDisconnect` so hang-timeout coverage can run.
private final class RecordingWebSocketClient: WebSocketClient {
    weak var delegate: WebSocketDelegate?
    var sentStrings: [String] = []
    var didCallConnect = false
    var didCallDisconnect = false
    var autoFireDisconnect = false

    func connect() {
        didCallConnect = true
        delegate?.websocketDidConnect(socket: self)
    }

    func disconnect(forceTimeout: TimeInterval?, closeCode: UInt16) {
        didCallDisconnect = true
        if autoFireDisconnect {
            delegate?.websocketDidDisconnect(socket: self, error: nil)
        }
    }

    func write(string: String, completion: (() -> Void)?) {
        sentStrings.append(string)
        completion?()
    }

    func write(data: Data, completion: (() -> Void)?) {}
    func write(ping: Data, completion: (() -> Void)?) {}
    func write(pong: Data, completion: (() -> Void)?) {}
}
