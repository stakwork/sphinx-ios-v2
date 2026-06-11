//
//  CallParticipantsSocketManager.swift
//  sphinx
//
//  Created on 2026-06-08.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation
import Starscream
import SwiftyJSON

class CallParticipantsSocketManager: NSObject, @unchecked Sendable {

    weak var delegate: CallParticipantsSocketDelegate?

    var socket: WebSocketClient?
    var subscribedRooms: Set<String> = []

    // MARK: - Public API

    func subscribe(roomName: String) {
        if socket == nil {
            connect()
        }
        subscribedRooms.insert(roomName)
        sendSubscribe(roomName: roomName)
    }

    func unsubscribe(roomName: String) {
        sendUnsubscribe(roomName: roomName)
        subscribedRooms.remove(roomName)
        if subscribedRooms.isEmpty {
            disconnect()
        }
    }

    // MARK: - Private helpers

    private func connect() {
        let serverBase = API.sharedInstance.kVideoCallServer
        let wsBase = serverBase
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let urlString = "\(wsBase)/ws"

        guard let url = URL(string: urlString) else {
            print("[CallParticipantsSocket] Invalid URL: \(urlString)")
            return
        }

        let request = URLRequest(url: url)
        let ws = WebSocket(request: request)
        ws.delegate = self
        socket = ws
        ws.connect()
        print("[CallParticipantsSocket] Connecting to \(urlString)")
    }

    private func disconnect() {
        socket?.disconnect()
        socket = nil
        print("[CallParticipantsSocket] Disconnected")
    }

    private func sendSubscribe(roomName: String) {
        let payload: [String: String] = ["action": "subscribe", "roomName": roomName]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }
        socket?.write(string: string)
        print("[CallParticipantsSocket] Subscribed to room: \(roomName)")
    }

    private func sendUnsubscribe(roomName: String) {
        let payload: [String: String] = ["action": "unsubscribe", "roomName": roomName]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }
        socket?.write(string: string)
        print("[CallParticipantsSocket] Unsubscribed from room: \(roomName)")
    }

    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSON(data: data) else {
            print("[CallParticipantsSocket] Failed to parse message as JSON")
            return
        }

        let type = json["type"].stringValue
        let roomName = json["roomName"].stringValue

        guard subscribedRooms.contains(roomName) else { return }

        switch type {
        case "current_participants":
            let participants = parseParticipants(from: json["participants"])
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didReceiveCurrentParticipants(roomName: roomName, participants: participants)
            }

        case "participant_joined":
            let participant = parseParticipant(from: json["participant"])
            guard let participant = participant else { return }
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.participantJoined(roomName: roomName, participant: participant)
            }

        case "participant_left":
            let identity = json["identity"].stringValue
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.participantLeft(roomName: roomName, identity: identity)
            }

        case "room_finished":
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.roomFinished(roomName: roomName)
            }

        default:
            print("[CallParticipantsSocket] Unhandled message type: \(type)")
        }
    }

    private func parseParticipants(from json: JSON) -> [BubbleMessageLayoutState.CallParticipantInfo] {
        var participants: [BubbleMessageLayoutState.CallParticipantInfo] = []
        for (_, item) in json {
            if let participant = parseParticipant(from: item) {
                participants.append(participant)
            }
        }
        return participants
    }

    private func parseParticipant(from json: JSON) -> BubbleMessageLayoutState.CallParticipantInfo? {
        let nickname = json["nickname"].stringValue
        let identity = json["identity"].string
        let avatarUrl = json["avatarUrl"].string
        return BubbleMessageLayoutState.CallParticipantInfo(
            identity: identity ?? nickname,
            name: nickname,
            profilePictureUrl: avatarUrl,
            isActive: true
        )
    }
}

// MARK: - WebSocketDelegate (Starscream 3.1)

extension CallParticipantsSocketManager: WebSocketDelegate {

    func websocketDidConnect(socket: WebSocketClient) {
        print("[CallParticipantsSocket] Connected — re-subscribing \(subscribedRooms.count) room(s)")
        subscribedRooms.forEach { sendSubscribe(roomName: $0) }
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        if let error = error {
            print("[CallParticipantsSocket] Disconnected with error: \(error.localizedDescription)")
        } else {
            print("[CallParticipantsSocket] Disconnected cleanly")
        }
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        handleTextMessage(text)
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print(data)
    }
}
