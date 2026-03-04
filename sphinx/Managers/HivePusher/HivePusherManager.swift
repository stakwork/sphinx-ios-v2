//
//  HivePusherManager.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import PusherSwift
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

    private var pusher: Pusher?
    private var featureId: String?
    private var taskId: String?

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    func connect(featureId: String) {
        disconnect()
        self.featureId = featureId
        setupPusher()
        subscribeToFeatureChannel(featureId)
        print("[HivePusher] Connecting to Pusher for feature: \(featureId)")
    }

    func connect(taskId: String) {
        disconnect()
        self.taskId = taskId
        setupPusher()
        subscribeToTaskChannel(taskId)
        print("[HivePusher] Connecting to Pusher for task: \(taskId)")
    }

    func disconnect() {
        if let featureId = featureId {
            pusher?.unsubscribe("feature-\(featureId)")
        }
        if let taskId = taskId {
            pusher?.unsubscribe("task-\(taskId)")
        }
        pusher?.disconnect()
        pusher = nil
        featureId = nil
        taskId = nil
        print("[HivePusher] Disconnected from Pusher")
    }

    // MARK: - Private Setup

    private func setupPusher() {
        let options = PusherClientOptions(host: .cluster(Config.pusherCluster))
        pusher = Pusher(key: Config.pusherKey, options: options)
        pusher?.connect()
    }

    // MARK: - Private Channel Subscription

    private func subscribeToFeatureChannel(_ featureId: String) {
        guard let channel = pusher?.subscribe("feature-\(featureId)") else { return }
        channel.bind(eventName: "feature-updated") { [weak self] event in
            self?.handleFeatureUpdated(event.data ?? "")
        }
        channel.bind(eventName: "new-message") { [weak self] event in
            self?.handleNewMessage(event.data ?? "")
        }
        channel.bind(eventName: "workflow-status-update") { [weak self] event in
            self?.handleWorkflowStatusChanged(event.data ?? "")
        }
        print("[HivePusher] Subscribed to feature channel: feature-\(featureId)")
    }

    private func subscribeToTaskChannel(_ taskId: String) {
        guard let channel = pusher?.subscribe("task-\(taskId)") else { return }
        channel.bind(eventName: "new-message") { [weak self] event in
            self?.handleNewMessage(event.data ?? "")
        }
        channel.bind(eventName: "workflow-status-update") { [weak self] event in
            self?.handleWorkflowStatusChanged(event.data ?? "")
        }
        print("[HivePusher] Subscribed to task channel: task-\(taskId)")
    }

    // MARK: - Event Handlers

    /// Exposed internally for unit testing — callers pass the inner JSON data string
    /// exactly as PusherSwift delivers it via `event.data`.
    func handleEvent(name: String, data: String) {
        switch name {
        case "feature-updated":
            handleFeatureUpdated(data)
        case "new-message":
            handleNewMessage(data)
        case "workflow-status-update":
            handleWorkflowStatusChanged(data)
        default:
            print("[HivePusher] Unhandled event: \(name)")
        }
    }

    private func handleFeatureUpdated(_ dataString: String) {
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

    private func handleNewMessage(_ dataString: String) {
        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse new-message data as JSON")
            return
        }

        let messageJSON = dataJSON["message"].exists() ? dataJSON["message"] : dataJSON

        guard let message = HiveChatMessage(json: messageJSON) else {
            print("[HivePusher] Failed to parse HiveChatMessage from new-message")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.newMessageReceived(message)
        }
    }

    private func handleWorkflowStatusChanged(_ dataString: String) {
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
