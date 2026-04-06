//
//  AgentEventsSSEManager.swift
//  sphinx
//
//  Created on 3/23/26.
//  Copyright © 2026 sphinx. All rights reserved.
//
//  Connects to the second SSE stream:
//    ${baseUrl}/events/${requestId}?token=${eventsToken}
//  This stream provides real-time agent activity (tool_call, text) for the
//  working status bar, separate from the main /api/ask/quick chat stream.
//

import Foundation
import LDSwiftEventSource
import SwiftyJSON

// MARK: - Delegate

@MainActor protocol AgentEventsSSEDelegate: AnyObject {
    func agentEventToolCall(toolName: String, input: [String: Any]?)
    func agentEventText(_ text: String)
    func agentEventFinish()
    func agentEventError(_ message: String)
}

// MARK: - Manager

class AgentEventsSSEManager: EventHandler {

    weak var delegate: AgentEventsSSEDelegate?
    private var eventSource: EventSource?

    // MARK: - Public API

    func startStream(requestId: String, eventsToken: String, baseUrl: String) {
        stopStream()

        // Ensure baseUrl has no trailing slash
        let cleanBase = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        let urlString = "\(cleanBase)/events/\(requestId)?token=\(eventsToken)"

        guard let url = URL(string: urlString) else {
            print("[AgentEventsSSE] Invalid URL: \(urlString)")
            return
        }

        var config = EventSource.Config(handler: self, url: url)
        config.method = "GET"
        // eventsToken is passed as query param – no Authorization header needed

        eventSource = EventSource(config: config)
        eventSource?.start()
        print("[AgentEventsSSE] Started stream for requestId: \(requestId) at \(urlString)")
    }

    func stopStream() {
        eventSource?.stop()
        eventSource = nil
    }

    deinit {
        stopStream()
    }

    // MARK: - EventHandler Conformance

    func onOpened() {
        print("[AgentEventsSSE] Stream opened")
    }

    func onClosed() {
        print("[AgentEventsSSE] Stream closed")
    }

    func onMessage(eventType: String, messageEvent: MessageEvent) {
        guard let data = messageEvent.data.data(using: .utf8) else { return }
        let json = JSON(data)

        // The events endpoint may wrap the type in a "type" field,
        // or use the SSE event field directly. Support both.
        let type = json["type"].string ?? eventType

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case "tool_call", "tool-call":
                let toolName = json["toolName"].string
                    ?? json["tool_name"].string
                    ?? json["name"].string
                    ?? ""
                let input = json["args"].dictionaryObject
                    ?? json["input"].dictionaryObject
                    ?? json["arguments"].dictionaryObject
                self.delegate?.agentEventToolCall(toolName: toolName, input: input)

            case "text", "text-delta":
                let text = json["text"].string
                    ?? json["delta"].string
                    ?? json["message"].string
                    ?? ""
                if !text.isEmpty {
                    self.delegate?.agentEventText(text)
                }

            case "done", "finish", "end":
                self.delegate?.agentEventFinish()

            case "error":
                let msg = json["message"].string ?? json["error"].string ?? "Agent event error"
                self.delegate?.agentEventError(msg)

            default:
                print("[AgentEventsSSE] Unhandled event type: \(type)")
            }
        }
    }

    func onComment(comment: String) {}

    func onError(error: Error) {
        print("[AgentEventsSSE] Error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.agentEventError(error.localizedDescription)
        }
    }
}
