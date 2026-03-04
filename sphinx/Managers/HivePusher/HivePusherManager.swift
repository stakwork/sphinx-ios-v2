//
//  HivePusherManager.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import Starscream
import SwiftyJSON

protocol HivePusherDelegate: AnyObject {
    func featureUpdateReceived(featureId: String)
    func newMessageReceived(_ message: HiveChatMessage)
    func workflowStatusChanged(status: WorkflowStatus)
}

class HivePusherManager: NSObject {
    static let shared = HivePusherManager()

    weak var delegate: HivePusherDelegate?

    private var fetchWorkItem: DispatchWorkItem?

    private var socket: WebSocket?
    private var featureId: String?
    private var taskId: String?
    private var authToken: String?
    private var socketId: String?
    private let pusherKey = "sphinx-hive-key"

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    func connect(featureId: String, authToken: String) {
        disconnect()

        self.featureId = featureId
        self.authToken = authToken

        setupSocket()
        print("[HivePusher] Connecting to WebSocket for feature: \(featureId)")
    }

    func connect(taskId: String, authToken: String) {
        disconnect()

        self.taskId = taskId
        self.authToken = authToken

        setupSocket()
        print("[HivePusher] Connecting to WebSocket for task: \(taskId)")
    }

    func disconnect() {
        guard let socket = socket else { return }

        if let featureId = featureId {
            unsubscribeFromChannel("feature-\(featureId)")
        }
        if let taskId = taskId {
            unsubscribeFromChannel("task-\(taskId)")
        }

        socket.disconnect()
        self.socket = nil
        self.featureId = nil
        self.taskId = nil
        self.socketId = nil

        print("[HivePusher] Disconnected from WebSocket")
    }

    // MARK: - Private Setup

    private func setupSocket() {
        guard let url = URL(string: "wss://hive.sphinx.chat/app/\(pusherKey)?protocol=7&client=sphinx-ios&version=1.0") else {
            print("[HivePusher] Invalid WebSocket URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        // No Authorization header — Pusher auth is per-channel via HTTP

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }

    // MARK: - Private Channel Methods

    private func subscribeToPrivateChannel(_ channelName: String) {
        guard let socketId = socketId else {
            print("[HivePusher] Cannot subscribe - no socket ID yet")
            return
        }
        guard let authToken = authToken else {
            print("[HivePusher] Cannot subscribe - no auth token")
            return
        }

        API.sharedInstance.authenticatePusherChannel(
            socketId: socketId,
            channelName: channelName,
            authToken: authToken
        ) { [weak self] authSignature in
            guard let self = self else { return }
            let message: [String: Any] = [
                "event": "pusher:subscribe",
                "data": [
                    "channel": channelName,
                    "auth": authSignature
                ]
            ]
            self.sendJSON(message)
            print("[HivePusher] Subscribed to private channel: \(channelName)")
        }
    }

    private func unsubscribeFromChannel(_ channel: String) {
        let message: [String: Any] = [
            "event": "pusher:unsubscribe",
            "data": ["channel": channel]
        ]
        sendJSON(message)
        print("[HivePusher] Unsubscribed from channel: \(channel)")
    }

    private func sendJSON(_ payload: [String: Any]) {
        guard let socket = socket, socket.isConnected else { return }
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let string = String(data: data, encoding: .utf8) {
            socket.write(string: string)
        }
    }

    // MARK: - Message Handling

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            print("[HivePusher] Failed to convert text to data")
            return
        }

        let json = JSON(data)

        guard let event = json["event"].string else {
            print("[HivePusher] No event found in message")
            return
        }

        print("[HivePusher] Received event: \(event)")

        switch event {
        case "pusher:connection_established":
            handleConnectionEstablished(json)

        case "pusher_internal:subscription_succeeded":
            print("[HivePusher] Successfully subscribed to channel")

        case "feature-updated":
            handleFeatureUpdated(json)

        case "NEW_MESSAGE":
            handleNewMessage(json)

        case "workflow-status-update":
            handleWorkflowStatusChanged(json)

        default:
            print("[HivePusher] Unhandled event: \(event)")
        }
    }

    private func handleConnectionEstablished(_ json: JSON) {
        print("[HivePusher] Connection established")
        let dataString = json["data"].stringValue
        let dataJSON = JSON(dataString.data(using: .utf8) ?? Data())
        self.socketId = dataJSON["socket_id"].string
        print("[HivePusher] Socket ID: \(self.socketId ?? "nil")")

        if let taskId = taskId {
            subscribeToPrivateChannel("task-\(taskId)")
        } else if let featureId = featureId {
            subscribeToPrivateChannel("feature-\(featureId)")
        }
    }

    private func handleFeatureUpdated(_ json: JSON) {
        guard let dataString = json["data"].string ?? json["data"].rawString() else {
            print("[HivePusher] No data in feature-updated event")
            return
        }

        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse feature-updated data as JSON")
            return
        }

        guard let featureId = dataJSON["featureId"].string else {
            print("[HivePusher] Missing featureId in feature-updated payload")
            return
        }

        fetchWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.delegate?.featureUpdateReceived(featureId: featureId)
        }
        fetchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func handleNewMessage(_ json: JSON) {
        guard let dataString = json["data"].string ?? json["data"].rawString() else {
            print("[HivePusher] No data in NEW_MESSAGE event")
            return
        }

        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse NEW_MESSAGE data as JSON")
            return
        }

        let messageJSON = dataJSON["message"].exists() ? dataJSON["message"] : dataJSON

        guard let message = HiveChatMessage(json: messageJSON) else {
            print("[HivePusher] Failed to parse HiveChatMessage from NEW_MESSAGE")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.newMessageReceived(message)
        }
    }

    private func handleWorkflowStatusChanged(_ json: JSON) {
        guard let dataString = json["data"].string ?? json["data"].rawString() else {
            print("[HivePusher] No data in workflow-status-update event")
            return
        }

        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse workflow-status-update data as JSON")
            return
        }

        let rawStatus = dataJSON["workflowStatus"].stringValue
        let status = WorkflowStatus(rawValue: rawStatus) ?? .PENDING

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.workflowStatusChanged(status: status)
        }
    }
}

// MARK: - WebSocketDelegate (Starscream 3.x API)
extension HivePusherManager: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        print("[HivePusher] WebSocket connected")
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("[HivePusher] WebSocket disconnected: \(error?.localizedDescription ?? "no error")")
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        handleMessage(text)
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("[HivePusher] Received binary data: \(data.count) bytes")
    }
}
