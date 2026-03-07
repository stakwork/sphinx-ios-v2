//
//  HiveAnyCableManager.swift
//  sphinx
//
//  Created on 2026-03-06.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation
import Starscream
import SwiftyJSON

class HiveAnyCableManager: NSObject {

    weak var delegate: HiveAnyCableDelegate?

    // Internal (not private) so @testable tests can inject mocks and inspect state
    var socket: WebSocketClient?
    var projectId: Int?
    var isSubscribed = false

    // MARK: - Public API

    func connect(projectId: Int) {
        self.projectId = projectId
        self.isSubscribed = false

        // No auth required — stakwork cable is open for project log subscriptions
        let urlString = "wss://jobs.stakwork.com/cable?channel=ProjectLogChannel"
        let request = URLRequest(url: URL(string: urlString)!)

        let ws = WebSocket(request: request)
        ws.delegate = self
        socket = ws
        ws.connect()
        print("[HiveAnyCable] Connecting for projectId: \(projectId)")
    }

    func disconnect() {
        if isSubscribed, let projectId = projectId {
            let identifier = identifierString(for: projectId)
            let cmd = buildCommand("unsubscribe", identifier: identifier)
            socket?.write(string: cmd)
        }
        socket?.disconnect()
        socket = nil
        projectId = nil
        isSubscribed = false
        print("[HiveAnyCable] Disconnected")
    }

    // MARK: - Internal helpers (internal so tests can call sendSubscribeCommand directly)

    func identifierString(for projectId: Int) -> String {
        return "{\"channel\":\"ProjectLogChannel\",\"id\":\"\(projectId)\"}"
    }

    func buildCommand(_ command: String, identifier: String) -> String {
        let payload: [String: String] = [
            "command": command,
            "identifier": identifier
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    func sendSubscribeCommand() {
        guard let projectId = projectId else { return }
        let identifier = identifierString(for: projectId)
        let cmd = buildCommand("subscribe", identifier: identifier)
        socket?.write(string: cmd)
        print("[HiveAnyCable] Sent subscribe command for projectId: \(projectId)")
    }

    func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSON(data: data) else {
            print("[HiveAnyCable] Failed to parse message as JSON")
            return
        }

        // Ignore heartbeat pings
        if json["type"].string == "ping" { return }

        // Handle control frames (welcome, confirm_subscription)
        if let type = json["type"].string {
            switch type {
            case "welcome":
                break
            case "confirm_subscription":
                isSubscribed = true
                print("[HiveAnyCable] Subscription confirmed")
            default:
                print("[HiveAnyCable] Unhandled type frame: \(type)")
            }
            return
        }

        // Data frame — extract inner message object
        let messageJSON = json["message"]
        guard messageJSON.exists() else { return }

        let msgType = messageJSON["type"].stringValue
        guard msgType == "on_step_start" || msgType == "on_step_complete" else { return }

        let stepText = messageJSON["message"].stringValue
        guard !stepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        print("[HiveAnyCable] Step event '\(msgType)': \(stepText)")
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.workflowStepTextReceived(stepText: stepText)
        }
    }
}

// MARK: - WebSocketDelegate (Starscream 3.1)

extension HiveAnyCableManager: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        print("[HiveAnyCable] Connected — sending subscribe")
        sendSubscribeCommand()
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        if let error = error {
            print("[HiveAnyCable] Disconnected with error: \(error.localizedDescription)")
        } else {
            print("[HiveAnyCable] Disconnected cleanly")
        }
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        handleTextMessage(text)
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        // Not used for Action Cable text frames
    }
}
