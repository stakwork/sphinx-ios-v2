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

    /// Preferred entry point: establishes a session cookie via an authenticated HTTP request,
    /// then opens the WebSocket with that cookie attached.
    func establishSessionThenConnect(projectId: Int) {
        guard let token: String = UserDefaults.Keys.hiveToken.get(), !token.isEmpty else {
            print("[HiveAnyCable] No token available")
            return
        }

        let url = URL(string: "https://hive.sphinx.chat/api/workspaces")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpShouldHandleCookies = true

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error = error {
                print("[HiveAnyCable] Failed to establish session: \(error.localizedDescription)")
                // Fall back to direct connect
                DispatchQueue.main.async { self?.connect(projectId: projectId) }
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               let headerFields = httpResponse.allHeaderFields as? [String: String],
               let responseURL = response?.url {
                let cookies = HTTPCookie.cookies(withResponseHeaders: headerFields, for: responseURL)
                print("[HiveAnyCable] Received cookies: \(cookies.map { $0.name })")
                HTTPCookieStorage.shared.setCookies(cookies, for: responseURL, mainDocumentURL: nil)
            }

            DispatchQueue.main.async { self?.connect(projectId: projectId) }
        }.resume()
    }

    func connect(projectId: Int) {
        guard let token: String = UserDefaults.Keys.hiveToken.get(), !token.isEmpty else {
            print("[HiveAnyCable] No hive token stored — skipping connect")
            return
        }

        self.projectId = projectId
        self.isSubscribed = false

        var request = URLRequest(url: URL(string: "wss://hive.sphinx.chat/cable")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Attach any stored session cookies
        if let cookieURL = URL(string: "https://hive.sphinx.chat"),
           let cookies = HTTPCookieStorage.shared.cookies(for: cookieURL), !cookies.isEmpty {
            let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
            if let cookieValue = cookieHeader["Cookie"] {
                request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
                print("[HiveAnyCable] Cookie header set: \(cookies.map { $0.name })")
            }
        } else {
            print("[HiveAnyCable] ⚠️ No cookies found in storage")
        }

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
        return "{\"channel\":\"WorkflowChannel\",\"id\":\"\(projectId)\"}"
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

        // Handle typed frames
        if let type = json["type"].string {
            switch type {
            case "welcome", "ping":
                // No-op
                break
            case "confirm_subscription":
                isSubscribed = true
                print("[HiveAnyCable] Subscription confirmed")
            default:
                print("[HiveAnyCable] Unhandled type frame: \(type)")
            }
            return
        }

        // Handle data frames (no "type" key, but has "message")
        let messageJSON = json["message"]
        guard messageJSON.exists() else { return }

        let status = messageJSON["status"].stringValue
        if status == "in_progress" {
            guard let pid = projectId else { return }
            print("[HiveAnyCable] Received in_progress status for projectId: \(pid)")
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.workflowStepUpdateReceived(projectId: pid)
            }
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
