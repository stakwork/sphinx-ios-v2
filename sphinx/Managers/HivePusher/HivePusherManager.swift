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
    func featureUpdated(_ feature: HiveFeature)
    func newMessageReceived(_ message: HiveChatMessage)
    func workflowStatusChanged(isWorking: Bool)
}

class HivePusherManager: NSObject {
    static let shared = HivePusherManager()
    
    weak var delegate: HivePusherDelegate?
    
    private var socket: WebSocket?
    private var featureId: String?
    private var authToken: String?
    private let pusherKey = "sphinx-hive-key" // Default key, can be configured
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    func connect(featureId: String, authToken: String) {
        disconnect() // Disconnect any existing connection
        
        self.featureId = featureId
        self.authToken = authToken
        
        guard let url = URL(string: "wss://hive.sphinx.chat/app/\(pusherKey)?protocol=7&client=sphinx-ios&version=1.0") else {
            print("[HivePusher] Invalid WebSocket URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
        
        print("[HivePusher] Connecting to WebSocket for feature: \(featureId)")
    }
    
    func disconnect() {
        guard let socket = socket else { return }
        
        if let featureId = featureId {
            unsubscribeFromChannel("feature-\(featureId)")
        }
        
        socket.disconnect()
        self.socket = nil
        self.featureId = nil
        
        print("[HivePusher] Disconnected from WebSocket")
    }
    
    // MARK: - Private Methods
    private func subscribeToChannel(_ channel: String) {
        guard let socket = socket, socket.isConnected else {
            print("[HivePusher] Cannot subscribe - socket not connected")
            return
        }
        
        let subscribeMessage: [String: Any] = [
            "event": "pusher:subscribe",
            "data": [
                "channel": channel
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: subscribeMessage, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket.write(string: jsonString)
            print("[HivePusher] Subscribed to channel: \(channel)")
        }
    }
    
    private func unsubscribeFromChannel(_ channel: String) {
        guard let socket = socket, socket.isConnected else { return }
        
        let unsubscribeMessage: [String: Any] = [
            "event": "pusher:unsubscribe",
            "data": [
                "channel": channel
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: unsubscribeMessage, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket.write(string: jsonString)
            print("[HivePusher] Unsubscribed from channel: \(channel)")
        }
    }
    
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
            
        case "FEATURE_UPDATED":
            handleFeatureUpdated(json)
            
        case "NEW_MESSAGE":
            handleNewMessage(json)
            
        case "WORKFLOW_STATUS_CHANGED":
            handleWorkflowStatusChanged(json)
            
        default:
            print("[HivePusher] Unhandled event: \(event)")
        }
    }
    
    private func handleConnectionEstablished(_ json: JSON) {
        print("[HivePusher] Connection established")
        
        // Subscribe to the feature channel
        if let featureId = featureId {
            subscribeToChannel("feature-\(featureId)")
        }
    }
    
    private func handleFeatureUpdated(_ json: JSON) {
        // Parse the data field which contains the feature JSON
        guard let dataString = json["data"].string ?? json["data"].rawString() else {
            print("[HivePusher] No data in FEATURE_UPDATED event")
            return
        }
        
        // Parse the data string as JSON
        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse FEATURE_UPDATED data as JSON")
            return
        }
        
        // Try to parse as HiveFeature directly or from nested structure
        let featureJSON = dataJSON["feature"].exists() ? dataJSON["feature"] : dataJSON
        
        guard let feature = HiveFeature(json: featureJSON) else {
            print("[HivePusher] Failed to parse HiveFeature from FEATURE_UPDATED")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.featureUpdated(feature)
        }
    }
    
    private func handleNewMessage(_ json: JSON) {
        // Parse the data field which contains the message JSON
        guard let dataString = json["data"].string ?? json["data"].rawString() else {
            print("[HivePusher] No data in NEW_MESSAGE event")
            return
        }
        
        // Parse the data string as JSON
        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse NEW_MESSAGE data as JSON")
            return
        }
        
        // Try to parse as HiveChatMessage directly or from nested structure
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
        // Parse the data field
        guard let dataString = json["data"].string ?? json["data"].rawString() else {
            print("[HivePusher] No data in WORKFLOW_STATUS_CHANGED event")
            return
        }
        
        // Parse the data string as JSON
        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse WORKFLOW_STATUS_CHANGED data as JSON")
            return
        }
        
        let isWorking = dataJSON["isWorking"].boolValue
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.workflowStatusChanged(isWorking: isWorking)
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
