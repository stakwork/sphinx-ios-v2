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
    func prStatusChanged(prNumber: Int, state: String, artifactStatus: String, prUrl: String?, problemDetails: String?)
    func featureTitleUpdated(featureId: String, newTitle: String)
    func taskTitleUpdated(taskId: String, newTitle: String)
    func taskGenerationStatusChanged(status: String, featureId: String)

    // Connection state callbacks (optional)
    func pusherConnectionStateChanged(from old: ConnectionState, to new: ConnectionState)
    func pusherConnectionError(_ error: Error?)
}

// Default implementations for optional methods
extension HivePusherDelegate {
    func pusherConnectionStateChanged(from old: ConnectionState, to new: ConnectionState) {}
    func pusherConnectionError(_ error: Error?) {}
}

class HivePusherManager: NSObject {
    static let shared = HivePusherManager()

    weak var delegate: HivePusherDelegate?

    private var fetchWorkItem: DispatchWorkItem?

    private var pusher: Pusher?
    private var featureId: String?
    private var taskId: String?
    private var workspaceSlug: String?

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    func connect(featureId: String, workspaceSlug: String = "") {
        disconnect()
        self.featureId = featureId
        self.workspaceSlug = workspaceSlug.isEmpty ? nil : workspaceSlug
        setupPusher()
        subscribeToFeatureChannel(featureId)
        if !workspaceSlug.isEmpty {
            subscribeToWorkspaceChannel(workspaceSlug)
        }
        print("[HivePusher] Connecting for feature: \(featureId), workspace: \(workspaceSlug)")
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
        if let slug = workspaceSlug {
            pusher?.unsubscribe("workspace-\(slug)")
        }
        pusher?.disconnect()
        pusher = nil
        featureId = nil
        taskId = nil
        workspaceSlug = nil
        print("[HivePusher] Disconnected from Pusher")
    }

    // MARK: - Public Connection State

    var isConnected: Bool {
        return pusher?.connection.connectionState == .connected
    }

    var connectionState: ConnectionState? {
        return pusher?.connection.connectionState
    }

    // MARK: - Private Setup

    private func setupPusher() {
        let options = PusherClientOptions(host: .cluster(Config.pusherCluster))
        pusher = Pusher(key: Config.pusherKey, options: options)
        pusher?.delegate = self
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
        channel.bind(eventName: "feature-title-update") { [weak self] event in
            self?.handleFeatureTitleUpdate(event.data ?? "")
        }
        channel.bind(eventName: "pr-status-change") { [weak self] event in
            self?.handlePRStatusChange(event.data ?? "")
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
        channel.bind(eventName: "task-title-update") { [weak self] event in
            self?.handleTaskTitleUpdate(event.data ?? "")
        }
        channel.bind(eventName: "pr-status-change") { [weak self] event in
            self?.handlePRStatusChange(event.data ?? "")
        }
        print("[HivePusher] Subscribed to task channel: task-\(taskId)")
    }

    private func subscribeToWorkspaceChannel(_ slug: String) {
        guard let channel = pusher?.subscribe("workspace-\(slug)") else { return }
        channel.bind(eventName: "stakwork-run-update") { [weak self] event in
            self?.handleStakworkRunUpdate(event.data ?? "")
        }
        print("[HivePusher] Subscribed to workspace channel: workspace-\(slug)")
    }

    private func handleStakworkRunUpdate(_ dataString: String) {
        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse stakwork-run-update data")
            return
        }
        guard dataJSON["type"].string == "TASK_GENERATION",
              let status = dataJSON["status"].string,
              let featureId = dataJSON["featureId"].string else {
            print("[HivePusher] stakwork-run-update ignored: not TASK_GENERATION or missing fields")
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.taskGenerationStatusChanged(status: status, featureId: featureId)
        }
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
        case "pr-status-change":
            handlePRStatusChange(data)
        case "feature-title-update":
            handleFeatureTitleUpdate(data)
        case "task-title-update":
            handleTaskTitleUpdate(data)
        case "stakwork-run-update":
            handleStakworkRunUpdate(data)
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
        // The payload is a plain message ID string, possibly wrapped in quotes
        // by PusherSwift JSON serialisation (e.g. "\"cmsg_abc123\""). Strip them.
        let trimmedId = dataString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        guard !trimmedId.isEmpty else {
            print("[HivePusher] new-message payload is empty after trimming quotes")
            return
        }

        print("[HivePusher] Fetching chat message with id: \(trimmedId)")

        API.sharedInstance.fetchChatMessageWithAuth(
            messageId: trimmedId,
            callback: { [weak self] message in
                guard let message = message else {
                    print("[HivePusher] fetchChatMessage returned nil for id: \(trimmedId)")
                    return
                }
                DispatchQueue.main.async {
                    self?.delegate?.newMessageReceived(message)
                }
            },
            errorCallback: {
                print("[HivePusher] fetchChatMessage failed for id: \(trimmedId)")
            }
        )
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

    private func handlePRStatusChange(_ dataString: String) {
        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse pr-status-change data as JSON")
            return
        }

        guard let prNumber = dataJSON["prNumber"].int else {
            print("[HivePusher] Missing prNumber in pr-status-change payload")
            return
        }

        guard let state = dataJSON["state"].string,
              let artifactStatus = dataJSON["artifactStatus"].string else {
            print("[HivePusher] Missing state or artifactStatus in pr-status-change payload")
            return
        }

        let prUrl = dataJSON["prUrl"].string
        let problemDetails = dataJSON["problemDetails"].string

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.prStatusChanged(
                prNumber: prNumber,
                state: state,
                artifactStatus: artifactStatus,
                prUrl: prUrl,
                problemDetails: problemDetails
            )
        }
    }

    private func handleFeatureTitleUpdate(_ dataString: String) {
        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse feature-title-update data as JSON")
            return
        }

        guard let featureId = dataJSON["featureId"].string,
              let newTitle = dataJSON["newTitle"].string else {
            print("[HivePusher] Missing featureId or newTitle in feature-title-update payload")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.featureTitleUpdated(featureId: featureId, newTitle: newTitle)
        }
    }

    private func handleTaskTitleUpdate(_ dataString: String) {
        guard let dataJSON = try? JSON(data: dataString.data(using: .utf8) ?? Data()) else {
            print("[HivePusher] Failed to parse task-title-update data as JSON")
            return
        }

        guard let taskId = dataJSON["taskId"].string,
              let newTitle = dataJSON["newTitle"].string else {
            print("[HivePusher] Missing taskId or newTitle in task-title-update payload")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.taskTitleUpdated(taskId: taskId, newTitle: newTitle)
        }
    }
}

// MARK: - PusherDelegate

extension HivePusherManager: PusherDelegate {
    func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        print("[HivePusher] Connection state changed: \(old) -> \(new)")

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.pusherConnectionStateChanged(from: old, to: new)
        }

        switch new {
        case .connected:
            print("[HivePusher] Successfully connected to Pusher")
        case .disconnected:
            print("[HivePusher] Disconnected from Pusher")
        case .connecting:
            print("[HivePusher] Connecting to Pusher...")
        case .reconnecting:
            print("[HivePusher] Reconnecting to Pusher...")
        case .disconnecting:
            print("[HivePusher] Disconnecting to Pusher...")
        @unknown default:
            print("[HivePusher] Unknown connection state: \(new)")
        }
    }

    func subscribedToChannel(name: String) {
        print("[HivePusher] Successfully subscribed to channel: \(name)")
    }

    func failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: NSError?) {
        print("[HivePusher] Failed to subscribe to channel \(name): \(error?.localizedDescription ?? "unknown error")")
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.pusherConnectionError(error)
        }
    }

    func debugLog(message: String) {
        #if DEBUG
        print("[HivePusher DEBUG] \(message)")
        #endif
    }

    func receivedError(error: PusherError) {
        print("[HivePusher] Received error: \(error.message) (code: \(error.code ?? 0))")
        let nsError = NSError(
            domain: "HivePusher",
            code: error.code ?? -1,
            userInfo: [NSLocalizedDescriptionKey: error.message]
        )
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.pusherConnectionError(nsError)
        }
    }
}
