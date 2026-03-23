//
//  GraphChatSSEManager.swift
//  sphinx
//
//  Created on 3/13/26.
//  Copyright © 2026 sphinx. All rights reserved.
//

import Foundation
import LDSwiftEventSource
import SwiftyJSON

// MARK: - Delegate

protocol GraphChatSSEDelegate: AnyObject {
    func onTextDelta(_ delta: String)
    func onToolInputAvailable(toolName: String)
    func onToolOutputAvailable()
    func onFinish()
    func onError(_ text: String)
    func onToolCall(toolName: String, input: [String: Any]?)
}

// MARK: - Manager

class GraphChatSSEManager: EventHandler {

    weak var delegate: GraphChatSSEDelegate?
    private var eventSource: EventSource?

    func startStream(
        messages: [[String: String]],
        workspaceSlug: String,
        token: String
    ) {
        stopStream()

        guard let url = URL(string: "https://hive.sphinx.chat/api/ask/quick") else { return }

        var config = EventSource.Config(handler: self, url: url)
        config.method = "POST"
        config.headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        let body: [String: Any] = [
            "messages": messages,
            "workspaceSlug": workspaceSlug
        ]
        config.body = try? JSONSerialization.data(withJSONObject: body)

        eventSource = EventSource(config: config)
        eventSource?.start()
    }

    func stopStream() {
        eventSource?.stop()
        eventSource = nil
    }

    deinit {
        stopStream()
    }

    // MARK: - EventHandler Conformance

    func onOpened() {}

    func onClosed() {}

    func onMessage(eventType: String, messageEvent: MessageEvent) {
        guard let data = messageEvent.data.data(using: .utf8) else { return }
        let json = JSON(data)

        guard let type = json["type"].string else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case "text-delta":
                let delta = json["delta"].string ?? json["text"].string ?? ""
                self.delegate?.onTextDelta(delta)

            case "tool-input-available":
                let toolName = json["toolName"].stringValue
                self.delegate?.onToolInputAvailable(toolName: toolName)

            case "tool-call":
                let toolName = json["toolName"].stringValue
                let input = json["args"].dictionaryObject ?? json["input"].dictionaryObject
                self.delegate?.onToolCall(toolName: toolName, input: input)

            case "tool-output-available", "tool-result":
                self.delegate?.onToolOutputAvailable()

            case "finish":
                self.delegate?.onFinish()

            case "error":
                let errorText = json["errorText"].string ?? json["message"].string ?? "An error occurred"
                self.delegate?.onError(errorText)

            default:
                break
            }
        }
    }

    func onComment(comment: String) {}

    func onError(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onError(error.localizedDescription)
        }
    }
}
