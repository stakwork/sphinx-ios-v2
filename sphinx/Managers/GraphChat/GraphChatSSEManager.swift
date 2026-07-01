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
    func onToolInputAvailable(_ toolName: String, _ toolCallId: String, _ input: String)
    func onToolCall(_ toolName: String, _ input: String)
    func onToolOutputAvailable(_ toolName: String, _ output: String)
    func onFinish()
    func onError(_ text: String)
}

// MARK: - Manager

class GraphChatSSEManager: NSObject, EventHandler, @unchecked Sendable {

    weak var delegate: GraphChatSSEDelegate?
    private var eventSource: EventSource?

    // MARK: - Org Stream state (URLSession-based)
    private var orgDataTask: URLSessionDataTask?
    private var orgSSEBuffer = ""
    private var orgConversationIdFired = false
    private var onConversationId: ((String) -> Void)?

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
        stopOrgStream()
    }

    // MARK: - Org Stream (URLSession-based, to access X-Conversation-Id header)

    func startOrgStream(
        question: String,
        orgSlugs: [String],
        orgId: String,
        conversationId: String?,
        token: String,
        onConversationId: @escaping (String) -> Void
    ) {
        stopOrgStream()
        orgSSEBuffer = ""
        orgConversationIdFired = false
        self.onConversationId = onConversationId

        guard let url = URL(string: "https://hive.sphinx.chat/api/ask/quick") else {
            delegate?.onError("Invalid endpoint URL.")
            return
        }

        var body: [String: Any] = [
            "workspaceSlugs": orgSlugs,
            "orgId": orgId,
            "skipEnrichments": true,
            "turnId": UUID().uuidString
        ]

        if let cid = conversationId {
            // Subsequent turn — server-history mode
            body["message"] = question
            body["conversationId"] = cid
        } else {
            // First turn — full messages array; server returns X-Conversation-Id in headers
            body["messages"] = [["role": "user", "content": question]]
        }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            delegate?.onError("Failed to serialize request body.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        orgDataTask = session.dataTask(with: request)
        orgDataTask?.resume()
    }

    func stopOrgStream() {
        orgDataTask?.cancel()
        orgDataTask = nil
        onConversationId = nil
    }

    // MARK: - EventHandler Conformance

    func onOpened() {}

    func onClosed() {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onFinish()
        }
    }

    func onMessage(eventType: String, messageEvent: MessageEvent) {
        let dataStr = messageEvent.data

        if dataStr == "[DONE]" {
            DispatchQueue.main.async { [weak self] in self?.delegate?.onFinish() }
            return
        }

        guard let data = dataStr.data(using: .utf8) else { return }
        let json = JSON(data)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Handle error from server
            if let errorMsg = json["error"].string {
                self.delegate?.onError(errorMsg)
                return
            }

            // Handle text delta (shorthand form without "type")
            if let delta = json["delta"].string, !delta.isEmpty {
                self.delegate?.onTextDelta(delta)
                return
            }

            let type = json["type"].stringValue

            switch type {
            case "text-delta", "text_delta":
                let delta = json["delta"].string ?? json["text"].string ?? ""
                if !delta.isEmpty { self.delegate?.onTextDelta(delta) }

            case "tool-input-available", "tool_input_available":
                let toolName = json["toolName"].stringValue.isEmpty ? json["tool_name"].stringValue : json["toolName"].stringValue
                let toolCallId = json["toolCallId"].stringValue
                let input = json["input"].rawString() ?? ""
                self.delegate?.onToolInputAvailable(toolName, toolCallId, input)

            case "tool-call", "tool_call":
                let toolName = json["toolName"].stringValue.isEmpty ? json["tool_name"].stringValue : json["toolName"].stringValue
                let input = json["args"].rawString() ?? json["input"].rawString() ?? ""
                self.delegate?.onToolCall(toolName, input)

            case "tool-output-available", "tool_output_available", "tool-result", "tool_result":
                let toolName = json["toolName"].stringValue.isEmpty ? json["tool_name"].stringValue : json["toolName"].stringValue
                let output = json["output"].rawString() ?? ""
                self.delegate?.onToolOutputAvailable(toolName, output)

            case "finish", "done":
                self.delegate?.onFinish()

            case "error":
                let errorText = json["errorText"].string ?? json["message"].string ?? "An error occurred"
                self.delegate?.onError(errorText)

            default:
                if let text = json["text"].string, !text.isEmpty {
                    self.delegate?.onTextDelta(text)
                }
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

// MARK: - URLSessionDataDelegate (Org Stream)

extension GraphChatSSEManager: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse,
           let cid = http.value(forHTTPHeaderField: "x-conversation-id"),
           !orgConversationIdFired {
            orgConversationIdFired = true
            // Store synchronously on the current delegate queue before allowing data to flow,
            // so the conversationId is persisted before any didReceive data fires.
            onConversationId?(cid)
        }
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        orgSSEBuffer += chunk
        let events = orgSSEBuffer.components(separatedBy: "\n\n")
        orgSSEBuffer = events.last ?? ""
        for event in events.dropLast() {
            parseOrgSSEEvent(event)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        DispatchQueue.main.async {
            if let error = error {
                self.delegate?.onError(error.localizedDescription)
            } else {
                self.delegate?.onFinish()
            }
        }
    }

    private func parseOrgSSEEvent(_ event: String) {
        for line in event.components(separatedBy: "\n") {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard payload != "[DONE]",
                  let _ = payload.data(using: .utf8) else { continue }
            DispatchQueue.main.async {
                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                self.handleOrgSSEJson(json)
            }
        }
    }

    /// Coerce any JSON value (String, Dict, Array, Number, Bool) to a JSON string.
    private func jsonValueToString(_ value: Any?) -> String {
        guard let value = value else { return "" }
        if let str = value as? String { return str }
        if let data = try? JSONSerialization.data(withJSONObject: value),
           let str = String(data: data, encoding: .utf8) { return str }
        return "\(value)"
    }

    private func handleOrgSSEJson(_ json: [String: Any]) {
        // toolName may appear as "toolName" or "tool_name"
        func extractToolName() -> String {
            (json["toolName"] as? String) ?? (json["tool_name"] as? String) ?? ""
        }

        let type = (json["type"] as? String) ?? ""
        switch type {
        case "text-delta", "text_delta":
            let delta = (json["delta"] as? String) ?? (json["text"] as? String) ?? ""
            if !delta.isEmpty { delegate?.onTextDelta(delta) }
        case "finish", "done":
            delegate?.onFinish()
        case "error":
            let msg = (json["errorText"] as? String) ?? (json["message"] as? String) ?? "An error occurred"
            delegate?.onError(msg)
        case "tool-input-available", "tool_input_available":
            let toolCallId = (json["toolCallId"] as? String) ?? ""
            let input = jsonValueToString(json["input"])
            delegate?.onToolInputAvailable(extractToolName(), toolCallId, input)
        case "tool-call", "tool_call":
            let input = jsonValueToString(json["args"] ?? json["input"])
            delegate?.onToolCall(extractToolName(), input)
        case "tool-output-available", "tool_output_available", "tool-result", "tool_result":
            let output = jsonValueToString(json["output"])
            delegate?.onToolOutputAvailable(extractToolName(), output)
        default:
            // Handle {"finish_reason":"stop"} which carries no "type" key
            if json["finish_reason"] != nil {
                delegate?.onFinish()
                return
            }
            if let text = (json["delta"] as? String) ?? (json["text"] as? String), !text.isEmpty {
                delegate?.onTextDelta(text)
            }
        }
    }
}
