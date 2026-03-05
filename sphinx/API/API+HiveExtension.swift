//
//  API+HiveExtension.swift
//  sphinx
//
//  Created on 2025-02-18.
//  Copyright © 2025 Sphinx. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

typealias HiveAuthTokenCallback = ((String?) -> ())
typealias HiveWorkspacesCallback = (([Workspace]) -> ())
typealias HiveTasksCallback = (([WorkspaceTask]) -> ())
typealias HiveWorkspaceImageCallback = ((String?) -> ())
typealias HiveFeaturesCallback = (([HiveFeature]) -> ())
typealias HiveFeatureCallback = ((HiveFeature?) -> ())
typealias HiveChatMessagesCallback = (([HiveChatMessage]) -> ())
typealias HiveTaskMessagesCallback = (([HiveChatMessage]) -> ())
typealias HiveChatMessageCallback = ((HiveChatMessage?) -> ())
typealias HiveStakworkRunCallback = ((StakworkRun?) -> ())
typealias HiveStakworkRunsCallback = (([StakworkRun]) -> ())

extension API {

    static let kHiveBaseUrl = "https://hive.sphinx.chat/api"

    func authenticateWithHive(
        callback: @escaping HiveAuthTokenCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let signedToken = SphinxOnionManager.sharedInstance.getSignedToken(),
              let pubkey = UserData.sharedInstance.getUserPubKey() else {
            errorCallback()
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)

        let params: [String: AnyObject] = [
            "token": signedToken as AnyObject,
            "pubkey": pubkey as AnyObject,
            "timestamp": timestamp as AnyObject
        ]

        guard let request = createRequest(
            "\(API.kHiveBaseUrl)/auth/sphinx/token",
            bodyParams: params as NSDictionary,
            method: "POST"
        ) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let token = json["token"].string {
                    callback(token)
                } else {
                    errorCallback()
                }
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchWorkspaces(
        authToken: String,
        callback: @escaping HiveWorkspacesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let request = createRequest(
            "\(API.kHiveBaseUrl)/workspaces",
            bodyParams: nil,
            method: "GET",
            token: authToken
        ) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                var workspaces: [Workspace] = []

                if let workspacesArray = json["workspaces"].array {
                    for workspaceJson in workspacesArray {
                        if let workspace = Workspace(json: workspaceJson) {
                            workspaces.append(workspace)
                        }
                    }
                }

                callback(workspaces)
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchWorkspacesWithAuth(
        callback: @escaping HiveWorkspacesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        // Check if we have a stored token
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            // Try using the stored token first
            fetchWorkspaces(
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    // Token might be expired, get a new one and retry
                    self?.authenticateAndFetchWorkspaces(
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            // No stored token, authenticate first
            authenticateAndFetchWorkspaces(
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchWorkspaces(
        callback: @escaping HiveWorkspacesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else {
                    errorCallback()
                    return
                }

                // Store the new token
                UserDefaults.Keys.hiveToken.set(token)

                self?.fetchWorkspaces(
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    func fetchTasks(
        workspaceId: String,
        authToken: String,
        includeArchived: Bool = false,
        callback: @escaping HiveTasksCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        // URL-encode the workspaceId to handle special characters
        guard let encodedWorkspaceId = workspaceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            errorCallback()
            return
        }

        var urlString = "\(API.kHiveBaseUrl)/tasks?workspaceId=\(encodedWorkspaceId)&limit=100&includeLatestMessage=true"
        if includeArchived { urlString += "&includeArchived=true" }

        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            // Check HTTP status code for unauthorized
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Tasks fetch unauthorized (401) - token may be expired")
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                // Check if the response contains an error
                if let error = json["error"].string {
                    print("[HiveAPI] Tasks fetch error: \(error)")
                    errorCallback()
                    return
                }

                let tasks: [WorkspaceTask] = (json["data"].array ?? []).compactMap { WorkspaceTask(json: $0) }
                callback(tasks)
            case .failure(let error):
                print("[HiveAPI] Tasks fetch failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchTasksWithAuth(
        workspaceId: String,
        includeArchived: Bool = false,
        callback: @escaping HiveTasksCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchTasks(
                workspaceId: workspaceId,
                authToken: storedToken,
                includeArchived: includeArchived,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchTasks(
                        workspaceId: workspaceId,
                        includeArchived: includeArchived,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchTasks(
                workspaceId: workspaceId,
                includeArchived: includeArchived,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchTasks(
        workspaceId: String,
        includeArchived: Bool,
        callback: @escaping HiveTasksCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchTasks(
                    workspaceId: workspaceId,
                    authToken: token,
                    includeArchived: includeArchived,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Workspace Image

    func fetchWorkspaceImage(
        slug: String,
        authToken: String,
        callback: @escaping HiveWorkspaceImageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback()
            return
        }

        let urlString = "\(API.kHiveBaseUrl)/workspaces/\(encodedSlug)/image"

        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                if let presignedUrl = json["presignedUrl"].string,
                   let expiresIn = json["expiresIn"].int {
                    // Cache the URL with expiration
                    let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                    WorkspaceImageCache.shared.setImage(
                        url: presignedUrl,
                        forSlug: slug,
                        expiresAt: expirationDate
                    )
                    callback(presignedUrl)
                } else {
                    callback(nil)
                }
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchWorkspaceImageWithAuth(
        slug: String,
        callback: @escaping HiveWorkspaceImageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        // Check cache first
        if let cachedUrl = WorkspaceImageCache.shared.getImageUrl(forSlug: slug) {
            callback(cachedUrl)
            return
        }

        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchWorkspaceImage(
                slug: slug,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchWorkspaceImage(
                        slug: slug,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchWorkspaceImage(
                slug: slug,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchWorkspaceImage(
        slug: String,
        callback: @escaping HiveWorkspaceImageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchWorkspaceImage(
                    slug: slug,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Features

    func fetchFeatures(
        workspaceId: String,
        authToken: String,
        callback: @escaping HiveFeaturesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        // Use the new endpoint: /api/features with workspaceId as query param
        let urlString = "\(API.kHiveBaseUrl)/features?workspaceId=\(workspaceId)&limit=100"
        
        print("[HiveAPI] Fetching features from: \(urlString)")

        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            print("[HiveAPI] Features fetch - failed to create request")
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode {
                print("[HiveAPI] Features fetch response status: \(statusCode)")
                if statusCode == 401 {
                    print("[HiveAPI] Features fetch unauthorized (401) - token may be expired")
                    errorCallback()
                    return
                }
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)
                print("[HiveAPI] Features fetch raw response: \(json)")

                if let error = json["error"].string {
                    print("[HiveAPI] Features fetch error: \(error)")
                    errorCallback()
                    return
                }

                // Parse the new response structure: { success: true, data: [...] }
                let featuresArray = json["data"].array ?? []
                print("[HiveAPI] Features fetch - found \(featuresArray.count) features in response")
                
                let features: [HiveFeature] = featuresArray.compactMap { 
                    let feature = HiveFeature(json: $0)
                    if feature == nil {
                        print("[HiveAPI] Failed to parse feature: \($0)")
                    }
                    return feature
                }
                print("[HiveAPI] Features fetch - successfully parsed \(features.count) features")
                callback(features)
            case .failure(let error):
                print("[HiveAPI] Features fetch failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchFeaturesWithAuth(
        workspaceId: String,
        callback: @escaping HiveFeaturesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchFeatures(
                workspaceId: workspaceId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchFeatures(
                        workspaceId: workspaceId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchFeatures(
                workspaceId: workspaceId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchFeatures(
        workspaceId: String,
        callback: @escaping HiveFeaturesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchFeatures(
                    workspaceId: workspaceId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    func createFeature(
        workspaceId: String,
        title: String,
        authToken: String,
        callback: @escaping HiveFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/features"
        let params: [String: AnyObject] = [
            "title": title as AnyObject,
            "workspaceId": workspaceId as AnyObject
        ]

        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Create feature unauthorized (401) - token may be expired")
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                if let error = json["error"].string {
                    print("[HiveAPI] Create feature error: \(error)")
                    errorCallback()
                    return
                }

                let feature = HiveFeature(json: json["data"])
                callback(feature)
            case .failure(let error):
                print("[HiveAPI] Create feature failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func createFeatureWithAuth(
        workspaceId: String,
        title: String,
        callback: @escaping HiveFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            createFeature(
                workspaceId: workspaceId,
                title: title,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndCreateFeature(
                        workspaceId: workspaceId,
                        title: title,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndCreateFeature(
                workspaceId: workspaceId,
                title: title,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndCreateFeature(
        workspaceId: String,
        title: String,
        callback: @escaping HiveFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.createFeature(
                    workspaceId: workspaceId,
                    title: title,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    func fetchFeatureChat(
        featureId: String,
        authToken: String,
        callback: @escaping HiveChatMessagesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedFeatureId = featureId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback()
            return
        }

        let urlString = "\(API.kHiveBaseUrl)/features/\(encodedFeatureId)/chat"

        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Feature chat fetch unauthorized (401) - token may be expired")
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                if let error = json["error"].string {
                    print("[HiveAPI] Feature chat fetch error: \(error)")
                    errorCallback()
                    return
                }

                guard json["success"].bool == true else {
                    print("[HiveAPI] Feature chat fetch returned success=false")
                    errorCallback()
                    return
                }

                let messages: [HiveChatMessage] = (json["data"].array ?? []).compactMap { HiveChatMessage(json: $0) }
                callback(messages)
            case .failure(let error):
                print("[HiveAPI] Feature chat fetch failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchFeatureChatWithAuth(
        featureId: String,
        callback: @escaping HiveChatMessagesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchFeatureChat(
                featureId: featureId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchFeatureChat(
                        featureId: featureId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchFeatureChat(
                featureId: featureId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchFeatureChat(
        featureId: String,
        callback: @escaping HiveChatMessagesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchFeatureChat(
                    featureId: featureId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    func sendFeatureChatMessage(
        featureId: String,
        message: String,
        replyId: String? = nil,
        socketId: String? = nil,
        authToken: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedFeatureId = featureId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback()
            return
        }

        let urlString = "\(API.kHiveBaseUrl)/features/\(encodedFeatureId)/chat"
        let params: [String: AnyObject] = [
            "message": message as AnyObject,
            "contextTags": [] as AnyObject,
            "sourceWebsocketID": (socketId as AnyObject? ?? NSNull() as AnyObject),
            "replyId": (replyId as AnyObject? ?? NSNull() as AnyObject)
        ]

        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Send chat message unauthorized (401) - token may be expired")
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                if let error = json["error"].string {
                    print("[HiveAPI] Send chat message error: \(error)")
                    errorCallback()
                    return
                }

                guard json["success"].bool == true else {
                    print("[HiveAPI] Send chat message returned success=false")
                    errorCallback()
                    return
                }

                guard let sentMessage = HiveChatMessage(json: json["message"]) else {
                    print("[HiveAPI] Send chat message - failed to parse returned message")
                    errorCallback()
                    return
                }

                callback(sentMessage)
            case .failure(let error):
                print("[HiveAPI] Send chat message failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func sendFeatureChatMessageWithAuth(
        featureId: String,
        message: String,
        replyId: String? = nil,
        socketId: String? = nil,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            sendFeatureChatMessage(
                featureId: featureId,
                message: message,
                replyId: replyId,
                socketId: socketId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndSendFeatureChatMessage(
                        featureId: featureId,
                        message: message,
                        replyId: replyId,
                        socketId: socketId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndSendFeatureChatMessage(
                featureId: featureId,
                message: message,
                replyId: replyId,
                socketId: socketId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndSendFeatureChatMessage(
        featureId: String,
        message: String,
        replyId: String? = nil,
        socketId: String? = nil,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.sendFeatureChatMessage(
                    featureId: featureId,
                    message: message,
                    replyId: replyId,
                    socketId: socketId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    func sendTaskChatMessage(
        taskId: String,
        message: String,
        replyId: String? = nil,
        socketId: String? = nil,
        authToken: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/chat/message"
        let params: [String: AnyObject] = [
            "taskId": taskId as AnyObject,
            "message": message as AnyObject,
            "contextTags": [] as AnyObject,
            "sourceWebsocketID": (socketId as AnyObject? ?? NSNull() as AnyObject),
            "replyId": (replyId as AnyObject? ?? NSNull() as AnyObject)
        ]

        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Send task chat message unauthorized (401) - token may be expired")
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                if let error = json["error"].string {
                    print("[HiveAPI] Send task chat message error: \(error)")
                    errorCallback()
                    return
                }

                guard json["success"].bool == true else {
                    print("[HiveAPI] Send task chat message returned success=false")
                    errorCallback()
                    return
                }

                guard let sentMessage = HiveChatMessage(json: json["message"]) else {
                    print("[HiveAPI] Send task chat message - failed to parse returned message")
                    errorCallback()
                    return
                }

                callback(sentMessage)
            case .failure(let error):
                print("[HiveAPI] Send task chat message failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func sendTaskChatMessageWithAuth(
        taskId: String,
        message: String,
        replyId: String? = nil,
        socketId: String? = nil,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            sendTaskChatMessage(
                taskId: taskId,
                message: message,
                replyId: replyId,
                socketId: socketId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndSendTaskChatMessage(
                        taskId: taskId,
                        message: message,
                        replyId: replyId,
                        socketId: socketId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndSendTaskChatMessage(
                taskId: taskId,
                message: message,
                replyId: replyId,
                socketId: socketId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndSendTaskChatMessage(
        taskId: String,
        message: String,
        replyId: String? = nil,
        socketId: String? = nil,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.sendTaskChatMessage(
                    taskId: taskId,
                    message: message,
                    replyId: replyId,
                    socketId: socketId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    func triggerTaskGeneration(
        workspaceId: String,
        featureId: String,
        includeHistory: Bool,
        authToken: String,
        callback: @escaping HiveStakworkRunCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/stakwork/ai/generate"
        let body: NSDictionary = [
            "type": "TASK_GENERATION",
            "workspaceId": workspaceId,
            "featureId": featureId,
            "params": ["skipClarifyingQuestions": true],
            "includeHistory": includeHistory,
            "autoAccept": false
        ]
        guard let request = createRequest(urlString, bodyParams: body, method: "POST", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback(); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] Trigger task generation error: \(error)")
                    errorCallback(); return
                }
                let run = StakworkRun(json: json["run"])
                callback(run)
            case .failure(let error):
                print("[HiveAPI] Trigger task generation failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func triggerTaskGenerationWithAuth(
        workspaceId: String,
        featureId: String,
        includeHistory: Bool,
        callback: @escaping HiveStakworkRunCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            triggerTaskGeneration(
                workspaceId: workspaceId, featureId: featureId, includeHistory: includeHistory,
                authToken: storedToken, callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndTriggerTaskGeneration(
                        workspaceId: workspaceId, featureId: featureId,
                        includeHistory: includeHistory, callback: callback, errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndTriggerTaskGeneration(
                workspaceId: workspaceId, featureId: featureId,
                includeHistory: includeHistory, callback: callback, errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndTriggerTaskGeneration(
        workspaceId: String,
        featureId: String,
        includeHistory: Bool,
        callback: @escaping HiveStakworkRunCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.triggerTaskGeneration(
                    workspaceId: workspaceId, featureId: featureId, includeHistory: includeHistory,
                    authToken: token, callback: callback, errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Task Generation Runs

    func fetchTaskGenerationRuns(
        workspaceId: String,
        featureId: String,
        authToken: String,
        callback: @escaping HiveStakworkRunsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/stakwork/runs?workspaceId=\(workspaceId)&featureId=\(featureId)&type=TASK_GENERATION"
        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback(); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                let runs = json["runs"].arrayValue.compactMap { StakworkRun(json: $0) }
                callback(runs)
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchTaskGenerationRunsWithAuth(
        workspaceId: String,
        featureId: String,
        callback: @escaping HiveStakworkRunsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchTaskGenerationRuns(
                workspaceId: workspaceId, featureId: featureId, authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchTaskGenerationRuns(
                        workspaceId: workspaceId, featureId: featureId,
                        callback: callback, errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchTaskGenerationRuns(
                workspaceId: workspaceId, featureId: featureId,
                callback: callback, errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchTaskGenerationRuns(
        workspaceId: String,
        featureId: String,
        callback: @escaping HiveStakworkRunsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchTaskGenerationRuns(
                    workspaceId: workspaceId, featureId: featureId, authToken: token,
                    callback: callback, errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Feature Detail (GET /api/features/{featureId})

    func fetchFeatureDetail(
        featureId: String,
        authToken: String,
        callback: @escaping HiveFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedId = featureId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback()
            return
        }

        let urlString = "\(API.kHiveBaseUrl)/features/\(encodedId)"

        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Feature detail fetch unauthorized (401)")
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                guard json["success"].bool == true,
                      let feature = HiveFeature(json: json["data"]) else {
                    print("[HiveAPI] Feature detail parse failed: \(json)")
                    errorCallback()
                    return
                }

                callback(feature)
            case .failure(let error):
                print("[HiveAPI] Feature detail fetch failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchFeatureDetailWithAuth(
        featureId: String,
        callback: @escaping HiveFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchFeatureDetail(
                featureId: featureId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchFeatureDetail(
                        featureId: featureId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchFeatureDetail(
                featureId: featureId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchFeatureDetail(
        featureId: String,
        callback: @escaping HiveFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchFeatureDetail(
                    featureId: featureId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }
    // MARK: - Task Messages

    func fetchTaskMessages(
        taskId: String,
        authToken: String,
        callback: @escaping HiveTaskMessagesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/tasks/\(encodedId)/messages"
        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback(); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                guard json["success"].bool == true else { errorCallback(); return }
                let messages = json["data"]["messages"].arrayValue.compactMap { HiveChatMessage(json: $0) }
                callback(messages)
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchTaskMessagesWithAuth(
        taskId: String,
        callback: @escaping HiveTaskMessagesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let token: String = UserDefaults.Keys.hiveToken.get() {
            fetchTaskMessages(
                taskId: taskId,
                authToken: token,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchTaskMessages(
                        taskId: taskId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchTaskMessages(taskId: taskId, callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndFetchTaskMessages(
        taskId: String,
        callback: @escaping HiveTaskMessagesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchTaskMessages(
                    taskId: taskId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Single Chat Message

    func fetchChatMessage(
        messageId: String,
        authToken: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedMessageId = messageId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback()
            return
        }

        let urlString = "\(API.kHiveBaseUrl)/chat/messages/\(encodedMessageId)"

        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] fetchChatMessage unauthorized (401) - token may be expired")
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                if let error = json["error"].string {
                    print("[HiveAPI] fetchChatMessage error: \(error)")
                    errorCallback()
                    return
                }

                let message = HiveChatMessage(json: json["data"])
                callback(message)
            case .failure(let error):
                print("[HiveAPI] fetchChatMessage failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchChatMessageWithAuth(
        messageId: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchChatMessage(
                messageId: messageId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchChatMessage(
                        messageId: messageId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchChatMessage(
                messageId: messageId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchChatMessage(
        messageId: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchChatMessage(
                    messageId: messageId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Assign All Feature Tasks (POST /api/features/{featureId}/tasks/assign-all)

    func assignAllFeatureTasks(
        featureId: String,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedFeatureId = featureId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/features/\(encodedFeatureId)/tasks/assign-all"
        guard let request = createRequest(urlString, bodyParams: nil, method: "POST", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback(); return
            }
            switch response.result {
            case .success:
                callback()
            case .failure(let error):
                print("[HiveAPI] assignAllFeatureTasks failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func assignAllFeatureTasksWithAuth(
        featureId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            assignAllFeatureTasks(
                featureId: featureId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndAssignAllFeatureTasks(
                        featureId: featureId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndAssignAllFeatureTasks(
                featureId: featureId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndAssignAllFeatureTasks(
        featureId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.assignAllFeatureTasks(
                    featureId: featureId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Delete Feature (DELETE /api/features/{featureId})

    func deleteFeature(
        featureId: String,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedFeatureId = featureId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/features/\(encodedFeatureId)"
        guard let request = createRequest(urlString, bodyParams: nil, method: "DELETE", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback(); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["success"].bool == true {
                    callback()
                } else {
                    print("[HiveAPI] deleteFeature returned success=false: \(json)")
                    errorCallback()
                }
            case .failure(let error):
                print("[HiveAPI] deleteFeature failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func deleteFeatureWithAuth(
        featureId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            deleteFeature(
                featureId: featureId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndDeleteFeature(
                        featureId: featureId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndDeleteFeature(
                featureId: featureId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndDeleteFeature(
        featureId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.deleteFeature(
                    featureId: featureId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Archive Task (PATCH /api/tasks/{taskId})

    func archiveTask(
        taskId: String,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/tasks/\(encodedTaskId)"
        let body: NSDictionary = ["archived": true]
        guard let request = createRequest(urlString, bodyParams: body, method: "PATCH", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback(); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["success"].bool == true {
                    callback()
                } else {
                    print("[HiveAPI] archiveTask returned success=false: \(json)")
                    errorCallback()
                }
            case .failure(let error):
                print("[HiveAPI] archiveTask failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func archiveTaskWithAuth(
        taskId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            archiveTask(
                taskId: taskId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndArchiveTask(
                        taskId: taskId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndArchiveTask(
                taskId: taskId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndArchiveTask(
        taskId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.archiveTask(
                    taskId: taskId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }
}

// MARK: - Workspace Image Cache

class WorkspaceImageCache {
    static let shared = WorkspaceImageCache()

    private struct CachedImage {
        let url: String
        let expiresAt: Date
    }

    private var cache: [String: CachedImage] = [:]
    private let queue = DispatchQueue(label: "com.sphinx.workspaceImageCache")

    private init() {}

    func setImage(url: String, forSlug slug: String, expiresAt: Date) {
        queue.async { [weak self] in
            self?.cache[slug] = CachedImage(url: url, expiresAt: expiresAt)
        }
    }

    func getImageUrl(forSlug slug: String) -> String? {
        return queue.sync {
            guard let cached = cache[slug] else { return nil }

            // Check if expired (with 60 second buffer)
            if cached.expiresAt.timeIntervalSinceNow < 60 {
                cache.removeValue(forKey: slug)
                return nil
            }

            return cached.url
        }
    }

    func clearCache() {
        queue.async { [weak self] in
            self?.cache.removeAll()
        }
    }
}
