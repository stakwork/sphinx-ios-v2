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
typealias HiveTasksCallback = (([WorkspaceTask], PaginationInfo) -> ())
typealias HiveWorkspaceImageCallback = ((String?) -> ())
typealias HiveFeaturesCallback = (([HiveFeature], PaginationInfo) -> ())
typealias HiveFeatureCallback = ((HiveFeature?) -> ())
typealias HiveUpdateFeatureCallback = ((HiveFeature?) -> ())
typealias HiveChatMessagesCallback = (([HiveChatMessage]) -> ())
typealias HiveTaskMessagesCallback = (([HiveChatMessage], String?) -> ())
typealias HiveChatMessageCallback = ((HiveChatMessage?) -> ())
typealias HiveStakworkRunCallback = ((StakworkRun?) -> ())
typealias HiveStakworkRunsCallback = (([StakworkRun]) -> ())
typealias HiveTaskCallback = ((WorkspaceTask?) -> ())
typealias StakworkWorkflowCallback = ((StakworkWorkflowData?) -> ())
typealias HiveSearchResultsCallback = ((HiveSearchResults) -> ())
typealias HiveReleasePodCallback = (() -> ())
typealias HivePoolStatusCallback = ((_ queuedCount: Int, _ unusedVms: Int) -> ())
typealias HiveCallLinkCallback = ((String) -> ())
typealias HivePoolWorkspacesCallback = ((_ pods: [WorkspacePod], _ hasWarning: Bool) -> ())
typealias HiveRepositoriesCallback = (([WorkspaceRepository]) -> ())
typealias HiveBranchesCallback = (([WorkspaceBranch]) -> ())
typealias HiveWorkflowVersionsCallback = (([WorkflowVersion]) -> ())
typealias HiveWorkspaceMembersCallback = (([WorkspaceMember]) -> ())
typealias HiveProjectErrorCallback = ((String) -> ())

// MARK: - WorkspaceRepository

struct WorkspaceRepository {
    let id: String
    let name: String
    let repositoryUrl: String
    let branch: String?   // default branch
    let status: String?

    init?(json: JSON) {
        guard let id = json["id"].string,
              let name = json["name"].string,
              let repositoryUrl = json["repositoryUrl"].string else { return nil }
        self.id = id
        self.name = name
        self.repositoryUrl = repositoryUrl
        self.branch = json["branch"].string
        self.status = json["status"].string
    }
}

// MARK: - WorkspaceBranch

struct WorkspaceBranch {
    let name: String
    let sha: String?

    init(json: JSON) {
        self.name = json["name"].string ?? ""
        self.sha = json["sha"].string
    }
}

// MARK: - PaginationInfo

struct PaginationInfo {
    let page: Int
    let totalPages: Int
    let totalCount: Int
    let hasMore: Bool

    init(json: JSON) {
        self.page       = json["page"].int       ?? 1
        self.totalPages = json["totalPages"].int  ?? 1
        self.totalCount = json["totalCount"].int  ?? 0
        self.hasMore    = json["hasMore"].bool    ?? false
    }

    static let empty = PaginationInfo(json: JSON([:]))
}

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
        page: Int = 1,
        callback: @escaping HiveTasksCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        // URL-encode the workspaceId to handle special characters
        guard let encodedWorkspaceId = workspaceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            errorCallback()
            return
        }

        var urlString = "\(API.kHiveBaseUrl)/tasks?workspaceId=\(encodedWorkspaceId)&limit=20&page=\(page)&includeLatestMessage=true"
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
                let pagination = PaginationInfo(json: json["pagination"])
                callback(tasks, pagination)
            case .failure(let error):
                print("[HiveAPI] Tasks fetch failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchTasksWithAuth(
        workspaceId: String,
        includeArchived: Bool = false,
        page: Int = 1,
        callback: @escaping HiveTasksCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchTasks(
                workspaceId: workspaceId,
                authToken: storedToken,
                includeArchived: includeArchived,
                page: page,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchTasks(
                        workspaceId: workspaceId,
                        includeArchived: includeArchived,
                        page: page,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchTasks(
                workspaceId: workspaceId,
                includeArchived: includeArchived,
                page: page,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchTasks(
        workspaceId: String,
        includeArchived: Bool,
        page: Int = 1,
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
                    page: page,
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

    // MARK: - Presigned URL

    /// Fetches a presigned S3 URL for the given S3 key.
    /// The server returns a 302 redirect to the actual S3 URL; Alamofire follows it
    /// and we return the final resolved URL from the response.
    func fetchPresignedUrl(
        s3Key: String,
        authToken: String,
        callback: @escaping (String?) -> Void
    ) {
        guard let encoded = s3Key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            callback(nil); return
        }
        let urlString = "\(API.kHiveBaseUrl)/upload/presigned-url?s3Key=\(encoded)"
        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            callback(nil); return
        }
        session()?.request(request).responseData { response in
            // Alamofire follows the 302 redirect; response.response?.url is the final S3 URL
            if let finalUrl = response.response?.url?.absoluteString {
                callback(finalUrl)
            } else {
                callback(nil)
            }
        }
    }

    func fetchPresignedUrlWithAuth(
        s3Key: String,
        callback: @escaping (String?) -> Void
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchPresignedUrl(s3Key: s3Key, authToken: storedToken) { [weak self] result in
                if result != nil {
                    callback(result)
                } else {
                    // Token may be expired — re-auth and retry once
                    self?.authenticateWithHive(callback: { newToken in
                        guard let newToken = newToken else { callback(nil); return }
                        UserDefaults.Keys.hiveToken.set(newToken)
                        self?.fetchPresignedUrl(s3Key: s3Key, authToken: newToken, callback: callback)
                    }, errorCallback: { callback(nil) })
                }
            }
        } else {
            authenticateWithHive(callback: { [weak self] token in
                guard let token = token else { callback(nil); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchPresignedUrl(s3Key: s3Key, authToken: token, callback: callback)
            }, errorCallback: { callback(nil) })
        }
    }

    // MARK: - Features

    func fetchFeatures(
        workspaceId: String,
        authToken: String,
        page: Int = 1,
        callback: @escaping HiveFeaturesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        // Use the new endpoint: /api/features with workspaceId as query param
        let urlString = "\(API.kHiveBaseUrl)/features?workspaceId=\(workspaceId)&limit=20&page=\(page)"
        
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
                let pagination = PaginationInfo(json: json["pagination"])
                callback(features, pagination)
            case .failure(let error):
                print("[HiveAPI] Features fetch failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchFeaturesWithAuth(
        workspaceId: String,
        page: Int = 1,
        callback: @escaping HiveFeaturesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchFeatures(
                workspaceId: workspaceId,
                authToken: storedToken,
                page: page,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchFeatures(
                        workspaceId: workspaceId,
                        page: page,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchFeatures(
                workspaceId: workspaceId,
                page: page,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchFeatures(
        workspaceId: String,
        page: Int = 1,
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
                    page: page,
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
        attachments: [[String: AnyObject]] = [],
        authToken: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/chat/message"
        var params: [String: AnyObject] = [
            "taskId": taskId as AnyObject,
            "message": message as AnyObject,
            "contextTags": [] as AnyObject,
            "sourceWebsocketID": (socketId as AnyObject? ?? NSNull() as AnyObject),
            "replyId": (replyId as AnyObject? ?? NSNull() as AnyObject),
            "mode": "live" as AnyObject
        ]
        if !attachments.isEmpty {
            params["attachments"] = attachments as AnyObject
        }

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
        attachments: [[String: AnyObject]] = [],
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            sendTaskChatMessage(
                taskId: taskId,
                message: message,
                replyId: replyId,
                socketId: socketId,
                attachments: attachments,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndSendTaskChatMessage(
                        taskId: taskId,
                        message: message,
                        replyId: replyId,
                        socketId: socketId,
                        attachments: attachments,
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
                attachments: attachments,
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
        mode: String? = nil,
        attachments: [[String: AnyObject]] = [],
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
                    attachments: attachments,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Workflow Editor

    func sendWorkflowEditorMessage(
        taskId: String,
        message: String,
        workflowId: Int,
        workflowName: String,
        workflowRefId: String,
        workflowVersionId: String?,
        webhook: String?,
        workflowJson: String? = nil,
        stepName: String? = nil,
        stepUniqueId: String? = nil,
        stepDisplayName: String? = nil,
        stepType: String? = nil,
        stepData: [String: AnyObject]? = nil,
        authToken: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/workflow-editor"
        var params: [String: AnyObject] = [
            "taskId": taskId as AnyObject,
            "message": message as AnyObject,
            "workflowId": workflowId as AnyObject,
            "workflowName": workflowName as AnyObject,
            "workflowRefId": workflowRefId as AnyObject
        ]
        if let workflowVersionId = workflowVersionId {
            params["workflowVersionId"] = workflowVersionId as AnyObject
        }
        if let webhook = webhook {
            params["webhook"] = webhook as AnyObject
        }
        if let workflowJson = workflowJson {
            params["workflowJson"] = workflowJson as AnyObject
        }
        params["stepName"] = (stepName ?? "") as AnyObject
        params["stepUniqueId"] = (stepUniqueId ?? "") as AnyObject
        params["stepDisplayName"] = (stepDisplayName ?? "") as AnyObject
        params["stepType"] = (stepType ?? "") as AnyObject
        params["stepData"] = (stepData ?? [:]) as AnyObject

        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] sendWorkflowEditorMessage unauthorized (401)")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] sendWorkflowEditorMessage error: \(error)")
                    errorCallback()
                    return
                }
                guard json["success"].bool == true else {
                    print("[HiveAPI] sendWorkflowEditorMessage returned success=false")
                    errorCallback()
                    return
                }
                guard let sentMessage = HiveChatMessage(json: json["message"]) else {
                    print("[HiveAPI] sendWorkflowEditorMessage - failed to parse returned message")
                    errorCallback()
                    return
                }
                callback(sentMessage)
            case .failure(let error):
                print("[HiveAPI] sendWorkflowEditorMessage failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func sendWorkflowEditorMessageWithAuth(
        taskId: String,
        message: String,
        workflowId: Int,
        workflowName: String,
        workflowRefId: String,
        workflowVersionId: String?,
        webhook: String?,
        workflowJson: String?,
        stepName: String? = nil,
        stepUniqueId: String? = nil,
        stepDisplayName: String? = nil,
        stepType: String? = nil,
        stepData: [String: AnyObject]? = nil,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            sendWorkflowEditorMessage(
                taskId: taskId, message: message,
                workflowId: workflowId,
                workflowName: workflowName,
                workflowRefId: workflowRefId,
                workflowVersionId: workflowVersionId,
                webhook: webhook,
                workflowJson: workflowJson,
                stepName: stepName,
                stepUniqueId: stepUniqueId,
                stepDisplayName: stepDisplayName,
                stepType: stepType,
                stepData: stepData,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndSendWorkflowEditorMessage(
                        taskId: taskId,
                        message: message,
                        workflowId: workflowId,
                        workflowName: workflowName,
                        workflowRefId: workflowRefId,
                        workflowVersionId: workflowVersionId,
                        webhook: webhook,
                        workflowJson: workflowJson,
                        stepName: stepName,
                        stepUniqueId: stepUniqueId,
                        stepDisplayName: stepDisplayName,
                        stepType: stepType,
                        stepData: stepData,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndSendWorkflowEditorMessage(
                taskId: taskId,
                message: message,
                workflowId: workflowId,
                workflowName: workflowName,
                workflowRefId: workflowRefId,
                workflowVersionId: workflowVersionId,
                webhook: webhook,
                workflowJson: workflowJson,
                stepName: stepName,
                stepUniqueId: stepUniqueId,
                stepDisplayName: stepDisplayName,
                stepType: stepType,
                stepData: stepData,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndSendWorkflowEditorMessage(
        taskId: String,
        message: String,
        workflowId: Int,
        workflowName: String,
        workflowRefId: String,
        workflowVersionId: String?,
        webhook: String?,
        workflowJson: String? = nil,
        stepName: String? = nil,
        stepUniqueId: String? = nil,
        stepDisplayName: String? = nil,
        stepType: String? = nil,
        stepData: [String: AnyObject]? = nil,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.sendWorkflowEditorMessage(
                    taskId: taskId,
                    message: message,
                    workflowId: workflowId,
                    workflowName: workflowName,
                    workflowRefId: workflowRefId,
                    workflowVersionId: workflowVersionId,
                    webhook: webhook,
                    workflowJson: workflowJson,
                    stepName: stepName,
                    stepUniqueId: stepUniqueId,
                    stepDisplayName: stepDisplayName,
                    stepType: stepType,
                    stepData: stepData,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Project Debugger

    func sendProjectDebuggerMessage(
        taskId: String,
        message: String,
        projectId: String,
        webhook: String?,
        authToken: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/project-debugger"
        var params: [String: AnyObject] = [
            "taskId": taskId as AnyObject,
            "message": message as AnyObject,
            "projectId": projectId as AnyObject
        ]
        if let webhook = webhook {
            params["webhook"] = webhook as AnyObject
        }

        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] sendProjectDebuggerMessage unauthorized (401)")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] sendProjectDebuggerMessage error: \(error)")
                    errorCallback()
                    return
                }
                guard json["success"].bool == true else {
                    print("[HiveAPI] sendProjectDebuggerMessage returned success=false")
                    errorCallback()
                    return
                }
                guard let sentMessage = HiveChatMessage(json: json["message"]) else {
                    print("[HiveAPI] sendProjectDebuggerMessage - failed to parse returned message")
                    errorCallback()
                    return
                }
                callback(sentMessage)
            case .failure(let error):
                print("[HiveAPI] sendProjectDebuggerMessage failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func sendProjectDebuggerMessageWithAuth(
        taskId: String,
        message: String,
        projectId: String,
        webhook: String?,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            sendProjectDebuggerMessage(
                taskId: taskId, message: message,
                projectId: projectId, webhook: webhook,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndSendProjectDebuggerMessage(
                        taskId: taskId, message: message,
                        projectId: projectId, webhook: webhook,
                        callback: callback, errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndSendProjectDebuggerMessage(
                taskId: taskId, message: message,
                projectId: projectId, webhook: webhook,
                callback: callback, errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndSendProjectDebuggerMessage(
        taskId: String,
        message: String,
        projectId: String,
        webhook: String?,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.sendProjectDebuggerMessage(
                    taskId: taskId, message: message,
                    projectId: projectId, webhook: webhook,
                    authToken: token,
                    callback: callback, errorCallback: errorCallback
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
//            "includeHistory": includeHistory,
            "autoAccept": true
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
    // MARK: - Feature Attachments

    typealias HiveFeatureAttachmentsCallback = (([HiveFeatureAttachment]) -> ())

    func fetchFeatureAttachments(
        featureId: String,
        authToken: String,
        callback: @escaping HiveFeatureAttachmentsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedId = featureId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/features/\(encodedId)/attachments"
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
                let attachments = json["attachments"].arrayValue.compactMap { HiveFeatureAttachment(json: $0) }
                callback(attachments)
            case .failure(let error):
                print("[HiveAPI] Feature attachments fetch failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchFeatureAttachmentsWithAuth(
        featureId: String,
        callback: @escaping HiveFeatureAttachmentsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchFeatureAttachments(
                featureId: featureId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchFeatureAttachments(
                        featureId: featureId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchFeatureAttachments(
                featureId: featureId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchFeatureAttachments(
        featureId: String,
        callback: @escaping HiveFeatureAttachmentsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchFeatureAttachments(
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
                let podId = json["data"]["task"]["podId"].string
                callback(messages, podId)
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

    // MARK: - Update Feature (PATCH /api/features/{featureId})

    func updateFeature(
        featureId: String,
        status: String? = nil,
        priority: String? = nil,
        authToken: String,
        callback: @escaping HiveUpdateFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedFeatureId = featureId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/features/\(encodedFeatureId)"

        var params: [String: AnyObject] = [:]
        if let status = status { params["status"] = status as AnyObject }
        if let priority = priority { params["priority"] = priority as AnyObject }

        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "PATCH", token: authToken) else {
            errorCallback(); return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] updateFeature unauthorized (401) - token may be expired")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] updateFeature error: \(error)")
                    errorCallback()
                    return
                }
                let feature = HiveFeature(json: json["data"])
                callback(feature)
            case .failure(let error):
                print("[HiveAPI] updateFeature failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func updateFeatureWithAuth(
        featureId: String,
        status: String? = nil,
        priority: String? = nil,
        callback: @escaping HiveUpdateFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            updateFeature(
                featureId: featureId,
                status: status,
                priority: priority,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndUpdateFeature(
                        featureId: featureId,
                        status: status,
                        priority: priority,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndUpdateFeature(
                featureId: featureId,
                status: status,
                priority: priority,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndUpdateFeature(
        featureId: String,
        status: String?,
        priority: String?,
        callback: @escaping HiveUpdateFeatureCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.updateFeature(
                    featureId: featureId,
                    status: status,
                    priority: priority,
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

    // MARK: - Delete Task (DELETE /api/tickets/{taskId})

    private func deleteTask(
        taskId: String,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/tickets/\(encodedTaskId)"
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
                    print("[HiveAPI] deleteTask returned success=false: \(json)")
                    errorCallback()
                }
            case .failure(let error):
                print("[HiveAPI] deleteTask failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func deleteTaskWithAuth(
        taskId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            deleteTask(
                taskId: taskId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndDeleteTask(
                        taskId: taskId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndDeleteTask(taskId: taskId, callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndDeleteTask(
        taskId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.deleteTask(taskId: taskId, authToken: token, callback: callback, errorCallback: errorCallback)
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Unarchive Task (PATCH /api/tasks/{taskId})

    private func unarchiveTask(
        taskId: String,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/tasks/\(encodedTaskId)"
        let body: NSDictionary = ["archived": false]
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
                if json["success"].bool == true { callback() } else { errorCallback() }
            case .failure:
                errorCallback()
            }
        }
    }

    func unarchiveTaskWithAuth(
        taskId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            unarchiveTask(
                taskId: taskId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndUnarchiveTask(taskId: taskId, callback: callback, errorCallback: errorCallback)
                }
            )
        } else {
            authenticateAndUnarchiveTask(taskId: taskId, callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndUnarchiveTask(
        taskId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.unarchiveTask(taskId: taskId, authToken: token, callback: callback, errorCallback: errorCallback)
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Retry Task Workflow (PATCH /api/tasks/{taskId})

    func retryTaskWorkflow(
        taskId: String,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/tasks/\(encodedTaskId)"
        let body: NSDictionary = ["retryWorkflow": true]
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
                    print("[HiveAPI] retryTaskWorkflow returned success=false: \(json)")
                    errorCallback()
                }
            case .failure(let error):
                print("[HiveAPI] retryTaskWorkflow failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func retryTaskWorkflowWithAuth(
        taskId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            retryTaskWorkflow(
                taskId: taskId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndRetryTaskWorkflow(
                        taskId: taskId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndRetryTaskWorkflow(
                taskId: taskId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndRetryTaskWorkflow(
        taskId: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.retryTaskWorkflow(
                    taskId: taskId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Update Task Auto-Merge (PATCH /api/tickets/{taskId})

    private func updateTaskAutoMerge(
        taskId: String,
        autoMerge: Bool,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encoded = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/tickets/\(encoded)"
        let body: NSDictionary = ["autoMerge": autoMerge]
        guard let request = createRequest(urlString, bodyParams: body, method: "PATCH", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 { errorCallback(); return }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["success"].bool == true { callback() }
                else { errorCallback() }
            case .failure: errorCallback()
            }
        }
    }

    func updateTaskAutoMergeWithAuth(
        taskId: String,
        autoMerge: Bool,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let token: String = UserDefaults.Keys.hiveToken.get() {
            updateTaskAutoMerge(taskId: taskId, autoMerge: autoMerge, authToken: token, callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndUpdateTaskAutoMerge(taskId: taskId, autoMerge: autoMerge,
                        callback: callback, errorCallback: errorCallback)
                })
        } else {
            authenticateAndUpdateTaskAutoMerge(taskId: taskId, autoMerge: autoMerge,
                callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndUpdateTaskAutoMerge(
        taskId: String, autoMerge: Bool,
        callback: @escaping EmptyCallback, errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(callback: { [weak self] token in
            guard let token = token else { errorCallback(); return }
            UserDefaults.Keys.hiveToken.set(token)
            self?.updateTaskAutoMerge(taskId: taskId, autoMerge: autoMerge, authToken: token,
                callback: callback, errorCallback: errorCallback)
        }, errorCallback: errorCallback)
    }

    // MARK: - Update Task Build Settings (PATCH /api/tickets/{taskId})

    private func updateTaskBuildSettings(
        taskId: String,
        runBuild: Bool?,
        runTestSuite: Bool?,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encoded = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/tickets/\(encoded)"
        var body: [String: Any] = [:]
        if let v = runBuild { body["runBuild"] = v }
        if let v = runTestSuite { body["runTestSuite"] = v }
        guard let request = createRequest(urlString, bodyParams: body as NSDictionary, method: "PATCH", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 { errorCallback(); return }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["success"].bool == true { callback() } else { errorCallback() }
            case .failure: errorCallback()
            }
        }
    }

    func updateTaskBuildSettingsWithAuth(
        taskId: String,
        runBuild: Bool? = nil,
        runTestSuite: Bool? = nil,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let token: String = UserDefaults.Keys.hiveToken.get() {
            updateTaskBuildSettings(taskId: taskId, runBuild: runBuild, runTestSuite: runTestSuite, authToken: token, callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndUpdateTaskBuildSettings(taskId: taskId, runBuild: runBuild, runTestSuite: runTestSuite,
                        callback: callback, errorCallback: errorCallback)
                })
        } else {
            authenticateAndUpdateTaskBuildSettings(taskId: taskId, runBuild: runBuild, runTestSuite: runTestSuite,
                callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndUpdateTaskBuildSettings(
        taskId: String, runBuild: Bool?, runTestSuite: Bool?,
        callback: @escaping EmptyCallback, errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(callback: { [weak self] token in
            guard let token = token else { errorCallback(); return }
            UserDefaults.Keys.hiveToken.set(token)
            self?.updateTaskBuildSettings(taskId: taskId, runBuild: runBuild, runTestSuite: runTestSuite, authToken: token,
                callback: callback, errorCallback: errorCallback)
        }, errorCallback: errorCallback)
    }

    // MARK: - Release Pod (POST /api/pool-manager/drop-pod/{workspaceId})

    func releasePod(
        workspaceId: String,
        podId: String,
        taskId: String,
        authToken: String,
        callback: @escaping HiveReleasePodCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard
            let encodedWorkspaceId = workspaceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let encodedPodId = podId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/pool-manager/drop-pod/\(encodedWorkspaceId)?podId=\(encodedPodId)&taskId=\(encodedTaskId)"
        guard let request = createRequest(urlString, bodyParams: nil, method: "POST", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback(); return
            }
            if let statusCode = response.response?.statusCode, statusCode == 409 {
                if case .success(let data) = response.result {
                    let json = JSON(data)
                    if json["reassigned"].bool == true {
                        callback(); return
                    }
                }
                errorCallback(); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if json["success"].bool == true {
                    callback()
                } else {
                    errorCallback()
                }
            case .failure:
                errorCallback()
            }
        }
    }

    func releasePodWithAuth(
        workspaceId: String,
        podId: String,
        taskId: String,
        callback: @escaping HiveReleasePodCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            releasePod(
                workspaceId: workspaceId,
                podId: podId,
                taskId: taskId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndReleasePod(
                        workspaceId: workspaceId,
                        podId: podId,
                        taskId: taskId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndReleasePod(
                workspaceId: workspaceId,
                podId: podId,
                taskId: taskId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndReleasePod(
        workspaceId: String,
        podId: String,
        taskId: String,
        callback: @escaping HiveReleasePodCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.releasePod(
                    workspaceId: workspaceId,
                    podId: podId,
                    taskId: taskId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Fetch Task Detail

    func fetchTaskDetail(
        taskId: String,
        authToken: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/task/\(encodedId)"
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
                if let task = WorkspaceTask(json: json["data"]) {
                    callback(task)
                } else {
                    errorCallback()
                }
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchTaskDetailWithAuth(
        taskId: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let token: String = UserDefaults.Keys.hiveToken.get() {
            fetchTaskDetail(
                taskId: taskId,
                authToken: token,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchTaskDetail(
                        taskId: taskId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchTaskDetail(taskId: taskId, callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndFetchTaskDetail(
        taskId: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchTaskDetail(
                    taskId: taskId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Workspace Search

    func searchWorkspace(
        slug: String,
        query: String,
        authToken: String,
        callback: @escaping HiveSearchResultsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/workspaces/\(encodedSlug)/search?q=\(encodedQuery)"
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
                callback(HiveSearchResults(json: json))
            case .failure:
                errorCallback()
            }
        }
    }

    func searchWorkspaceWithAuth(
        slug: String,
        query: String,
        callback: @escaping HiveSearchResultsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let token: String = UserDefaults.Keys.hiveToken.get() {
            searchWorkspace(
                slug: slug,
                query: query,
                authToken: token,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndSearchWorkspace(
                        slug: slug,
                        query: query,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndSearchWorkspace(slug: slug, query: query, callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndSearchWorkspace(
        slug: String,
        query: String,
        callback: @escaping HiveSearchResultsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.searchWorkspace(
                    slug: slug,
                    query: query,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Fetch Stakwork Workflow

    func fetchStakworkWorkflow(
        projectId: Int,
        authToken: String,
        callback: @escaping StakworkWorkflowCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/stakwork/workflow/\(projectId)"
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
                if let workflowData = StakworkWorkflowData(json: json) {
                    callback(workflowData)
                } else {
                    errorCallback()
                }
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchStakworkWorkflowWithAuth(
        projectId: Int,
        callback: @escaping StakworkWorkflowCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let token: String = UserDefaults.Keys.hiveToken.get() {
            fetchStakworkWorkflow(
                projectId: projectId,
                authToken: token,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchStakworkWorkflow(
                        projectId: projectId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchStakworkWorkflow(projectId: projectId, callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndFetchStakworkWorkflow(
        projectId: Int,
        callback: @escaping StakworkWorkflowCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchStakworkWorkflow(
                    projectId: projectId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Pool Status (GET /api/w/{workspaceSlug}/pool/status)

    func fetchPoolStatus(
        workspaceSlug: String,
        authToken: String,
        callback: @escaping HivePoolStatusCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedSlug = workspaceSlug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "https://hive.sphinx.chat/api/w/\(encodedSlug)/pool/status"
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
                guard json["success"].bool == true,
                      let queuedCount = json["data"]["status"]["queuedCount"].int,
                      let unusedVms   = json["data"]["status"]["unusedVms"].int else {
                    errorCallback(); return
                }
                callback(queuedCount, unusedVms)
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchPoolStatusWithAuth(
        workspaceSlug: String,
        callback: @escaping HivePoolStatusCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchPoolStatus(
                workspaceSlug: workspaceSlug,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchPoolStatus(
                        workspaceSlug: workspaceSlug,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchPoolStatus(
                workspaceSlug: workspaceSlug,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    // MARK: - Pool Workspaces

    func fetchPoolWorkspaces(
        workspaceSlug: String,
        authToken: String,
        callback: @escaping HivePoolWorkspacesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedSlug = workspaceSlug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "https://hive.sphinx.chat/api/w/\(encodedSlug)/pool/workspaces"
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
                guard json["success"].bool == true else {
                    errorCallback(); return
                }
                let hasWarning = json["warning"].string != nil
                let pods: [WorkspacePod] = json["data"]["workspaces"].arrayValue.compactMap { WorkspacePod(json: $0) }
                callback(pods, hasWarning)
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchPoolWorkspacesWithAuth(
        workspaceSlug: String,
        callback: @escaping HivePoolWorkspacesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchPoolWorkspaces(
                workspaceSlug: workspaceSlug,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchPoolWorkspaces(
                        workspaceSlug: workspaceSlug,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchPoolWorkspaces(
                workspaceSlug: workspaceSlug,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchPoolWorkspaces(
        workspaceSlug: String,
        callback: @escaping HivePoolWorkspacesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchPoolWorkspaces(
                    workspaceSlug: workspaceSlug,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Tribe Call Link

    func generateTribeCallLink(
        swarmName: String,
        authToken: String,
        callback: @escaping HiveCallLinkCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedSwarmName = swarmName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/workspaces/_/calls/generate-link?swarmName=\(encodedSwarmName)"
        guard let request = createRequest(urlString, bodyParams: nil, method: "POST", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback(); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                guard let url = json["url"].string else { errorCallback(); return }
                callback(url)
            case .failure:
                errorCallback()
            }
        }
    }

    func generateTribeCallLinkWithAuth(
        swarmName: String,
        callback: @escaping HiveCallLinkCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let token: String = UserDefaults.Keys.hiveToken.get() {
            generateTribeCallLink(
                swarmName: swarmName,
                authToken: token,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndGenerateTribeCallLink(
                        swarmName: swarmName,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndGenerateTribeCallLink(
                swarmName: swarmName,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndGenerateTribeCallLink(
        swarmName: String,
        callback: @escaping HiveCallLinkCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.generateTribeCallLink(
                    swarmName: swarmName,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    private func authenticateAndFetchPoolStatus(
        workspaceSlug: String,
        callback: @escaping HivePoolStatusCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchPoolStatus(
                    workspaceSlug: workspaceSlug,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Device Token Registration

    func registerDeviceToken(
        token: String,
        authToken: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let params: [String: AnyObject] = ["ios_device_token": token as AnyObject]
        guard let request = createRequest(
            "\(API.kHiveBaseUrl)/device-token",
            bodyParams: params as NSDictionary,
            method: "POST",
            token: authToken
        ) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode != 200 {
                print("[HiveAPI] device token set unauthorized (401) - token may be expired")
                errorCallback()
                return
            }
            
            switch response.result {
            case .success:
                callback()
            case .failure:
                errorCallback()
            }
        }
    }

    func registerDeviceTokenWithAuth(
        token: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            registerDeviceToken(
                token: token,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateWithHive(
                        callback: { [weak self] newToken in
                            guard let newToken = newToken else { errorCallback(); return }
                            UserDefaults.Keys.hiveToken.set(newToken)
                            self?.registerDeviceToken(
                                token: token,
                                authToken: newToken,
                                callback: callback,
                                errorCallback: errorCallback
                            )
                        },
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateWithHive(
                callback: { [weak self] newToken in
                    guard let newToken = newToken else { errorCallback(); return }
                    UserDefaults.Keys.hiveToken.set(newToken)
                    self?.registerDeviceToken(
                        token: token,
                        authToken: newToken,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                },
                errorCallback: errorCallback
            )
        }
    }

    // MARK: - Graph Chat Token Resolution

    /// Returns a valid Hive token via `callback`, fetching a fresh one on cache miss / expiry.
    func resolveHiveToken(
        callback: @escaping (String) -> Void,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            callback(storedToken)
        } else {
            authenticateWithHive(
                callback: { token in
                    guard let token = token else { errorCallback(); return }
                    UserDefaults.Keys.hiveToken.set(token)
                    callback(token)
                },
                errorCallback: errorCallback
            )
        }
    }

    // MARK: - Workspace Detail (repositories)

    func fetchWorkspaceDetail(
        slug: String,
        authToken: String,
        callback: @escaping HiveRepositoriesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback()
            return
        }
        let urlString = "\(API.kHiveBaseUrl)/workspaces/\(encodedSlug)"
        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback()
            return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Fetch workspace detail unauthorized (401) - token may be expired")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] Fetch workspace detail error: \(error)")
                    errorCallback()
                    return
                }
                let repos: [WorkspaceRepository] = json["workspace"]["repositories"].arrayValue.compactMap { WorkspaceRepository(json: $0) }
                callback(repos)
            case .failure(let error):
                print("[HiveAPI] Fetch workspace detail failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchWorkspaceDetailWithAuth(
        slug: String,
        callback: @escaping HiveRepositoriesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchWorkspaceDetail(
                slug: slug,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchWorkspaceDetail(
                        slug: slug,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchWorkspaceDetail(
                slug: slug,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchWorkspaceDetail(
        slug: String,
        callback: @escaping HiveRepositoriesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchWorkspaceDetail(
                    slug: slug,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Repository Branches

    func fetchBranches(
        repoUrl: String,
        workspaceSlug: String,
        authToken: String,
        callback: @escaping HiveBranchesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedRepoUrl = repoUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedSlug = workspaceSlug.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            errorCallback()
            return
        }
        fetchBranchesPage(
            encodedRepoUrl: encodedRepoUrl,
            encodedSlug: encodedSlug,
            authToken: authToken,
            page: 1,
            accumulated: [],
            callback: callback,
            errorCallback: errorCallback
        )
    }

    private func fetchBranchesPage(
        encodedRepoUrl: String,
        encodedSlug: String,
        authToken: String,
        page: Int,
        perPage: Int = 100,
        accumulated: [WorkspaceBranch],
        callback: @escaping HiveBranchesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/github/repository/branches?repoUrl=\(encodedRepoUrl)&workspaceSlug=\(encodedSlug)&page=\(page)&per_page=\(perPage)"
        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Fetch branches unauthorized (401) - token may be expired")
                errorCallback(); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] Fetch branches error: \(error)")
                    errorCallback(); return
                }
                let pageBranches = json["branches"].arrayValue.map { WorkspaceBranch(json: $0) }
                let all = accumulated + pageBranches
                if pageBranches.count < perPage {
                    callback(all)
                } else {
                    self.fetchBranchesPage(
                        encodedRepoUrl: encodedRepoUrl,
                        encodedSlug: encodedSlug,
                        authToken: authToken,
                        page: page + 1,
                        perPage: perPage,
                        accumulated: all,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            case .failure(let error):
                print("[HiveAPI] Fetch branches failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchBranchesWithAuth(
        repoUrl: String,
        workspaceSlug: String,
        callback: @escaping HiveBranchesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchBranches(
                repoUrl: repoUrl,
                workspaceSlug: workspaceSlug,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchBranches(
                        repoUrl: repoUrl,
                        workspaceSlug: workspaceSlug,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchBranches(
                repoUrl: repoUrl,
                workspaceSlug: workspaceSlug,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchBranches(
        repoUrl: String,
        workspaceSlug: String,
        callback: @escaping HiveBranchesCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchBranches(
                    repoUrl: repoUrl,
                    workspaceSlug: workspaceSlug,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Create Task

    func createTask(
        title: String,
        workspaceSlug: String,
        repositoryId: String,
        branch: String,
        authToken: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/tasks"
        let params: [String: AnyObject] = [
            "title": title as AnyObject,
            "workspaceSlug": workspaceSlug as AnyObject,
            "repositoryId": repositoryId as AnyObject,
            "branch": branch as AnyObject,
            "status": "active" as AnyObject,
            "mode": "live" as AnyObject,
            "autoMerge": false as AnyObject,
        ]
        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Create task unauthorized (401) - token may be expired")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] Create task error: \(error)")
                    errorCallback()
                    return
                }
                let task = WorkspaceTask(json: json["data"])
                callback(task)
            case .failure(let error):
                print("[HiveAPI] Create task failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func createTaskWithAuth(
        title: String,
        workspaceSlug: String,
        repositoryId: String,
        branch: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            createTask(
                title: title,
                workspaceSlug: workspaceSlug,
                repositoryId: repositoryId,
                branch: branch,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndCreateTask(
                        title: title,
                        workspaceSlug: workspaceSlug,
                        repositoryId: repositoryId,
                        branch: branch,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndCreateTask(
                title: title,
                workspaceSlug: workspaceSlug,
                repositoryId: repositoryId,
                branch: branch,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndCreateTask(
        title: String,
        workspaceSlug: String,
        repositoryId: String,
        branch: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.createTask(
                    title: title,
                    workspaceSlug: workspaceSlug,
                    repositoryId: repositoryId,
                    branch: branch,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Upload Presigned URL

    func requestUploadPresignedUrl(
        taskId: String,
        filename: String,
        contentType: String,
        size: Int,
        authToken: String,
        callback: @escaping (String?, String?) -> Void,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/upload/presigned-url"
        let params: [String: AnyObject] = [
            "taskId": taskId as AnyObject,
            "filename": filename as AnyObject,
            "contentType": contentType as AnyObject,
            "size": size as AnyObject
        ]

        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }

        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Request upload presigned URL unauthorized (401) - token may be expired")
                errorCallback()
                return
            }

            switch response.result {
            case .success(let data):
                let json = JSON(data)

                if let error = json["error"].string {
                    print("[HiveAPI] Request upload presigned URL error: \(error)")
                    errorCallback()
                    return
                }

                guard let presignedUrl = json["presignedUrl"].string,
                      let s3Path = json["s3Path"].string else {
                    print("[HiveAPI] Request upload presigned URL - failed to parse response")
                    errorCallback()
                    return
                }

                callback(presignedUrl, s3Path)
            case .failure(let error):
                print("[HiveAPI] Request upload presigned URL failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func requestUploadPresignedUrlWithAuth(
        taskId: String,
        filename: String,
        contentType: String,
        size: Int,
        callback: @escaping (String?, String?) -> Void,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            requestUploadPresignedUrl(
                taskId: taskId,
                filename: filename,
                contentType: contentType,
                size: size,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndRequestUploadPresignedUrl(
                        taskId: taskId,
                        filename: filename,
                        contentType: contentType,
                        size: size,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndRequestUploadPresignedUrl(
                taskId: taskId,
                filename: filename,
                contentType: contentType,
                size: size,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndRequestUploadPresignedUrl(
        taskId: String,
        filename: String,
        contentType: String,
        size: Int,
        callback: @escaping (String?, String?) -> Void,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.requestUploadPresignedUrl(
                    taskId: taskId,
                    filename: filename,
                    contentType: contentType,
                    size: size,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Upload File to S3

    func uploadFileToS3(
        presignedUrl: String,
        data: Data,
        contentType: String,
        callback: @escaping EmptyCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let url = URL(string: presignedUrl) else {
            errorCallback()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        URLSession.shared.uploadTask(with: request, from: data) { _, response, error in
            if let error = error {
                print("[HiveAPI] Upload file to S3 failed: \(error.localizedDescription)")
                errorCallback()
                return
            }
            if let statusCode = (response as? HTTPURLResponse)?.statusCode,
               statusCode == 200 || statusCode == 204 {
                callback()
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[HiveAPI] Upload file to S3 unexpected status: \(code)")
                errorCallback()
            }
        }.resume()
    }

    // MARK: - Workspace Members

    func fetchWorkspaceMembers(
        slug: String,
        authToken: String,
        callback: @escaping HiveWorkspaceMembersCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            errorCallback(); return
        }
        let urlString = "\(API.kHiveBaseUrl)/workspaces/\(encodedSlug)/members"
        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback(); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] Fetch workspace members failed with status code (401) - token may be expired")
                errorCallback()
                return
            }
            
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                var members: [WorkspaceMember] = []
                if let arr = json["members"].array {
                    members = arr.compactMap { WorkspaceMember(json: $0) }
                }
                if let ownerDict = json["owner"].dictionary {
                    let ownerJson = JSON(ownerDict)
                    if let owner = WorkspaceMember(json: ownerJson) {
                        members.append(owner)
                    }
                }
                callback(members)
            case .failure:
                errorCallback()
            }
        }
    }

    func fetchWorkspaceMembersWithAuth(
        slug: String,
        callback: @escaping HiveWorkspaceMembersCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchWorkspaceMembers(
                slug: slug,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchWorkspaceMembers(
                        slug: slug,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchWorkspaceMembers(slug: slug, callback: callback, errorCallback: errorCallback)
        }
    }

    private func authenticateAndFetchWorkspaceMembers(
        slug: String,
        callback: @escaping HiveWorkspaceMembersCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchWorkspaceMembers(slug: slug, authToken: token, callback: callback, errorCallback: errorCallback)
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Create Workflow Task

    func createWorkflowTask(
        title: String,
        description: String,
        workspaceSlug: String,
        authToken: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/tasks"
        let params: [String: AnyObject] = [
            "title": title as AnyObject,
            "description": description as AnyObject,
            "status": "active" as AnyObject,
            "workspaceSlug": workspaceSlug as AnyObject,
            "mode": "workflow_editor" as AnyObject
        ]
        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] createWorkflowTask unauthorized (401)")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] createWorkflowTask error: \(error)")
                    errorCallback()
                    return
                }
                let task = WorkspaceTask(json: json["data"])
                callback(task)
            case .failure(let error):
                print("[HiveAPI] createWorkflowTask failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func createWorkflowTaskWithAuth(
        title: String,
        description: String,
        workspaceSlug: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            createWorkflowTask(
                title: title,
                description: description,
                workspaceSlug: workspaceSlug,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndCreateWorkflowTask(
                        title: title,
                        description: description,
                        workspaceSlug: workspaceSlug,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndCreateWorkflowTask(
                title: title,
                description: description,
                workspaceSlug: workspaceSlug,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndCreateWorkflowTask(
        title: String,
        description: String,
        workspaceSlug: String,
        callback: @escaping HiveTaskCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.createWorkflowTask(
                    title: title,
                    description: description,
                    workspaceSlug: workspaceSlug,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Save Task Message

    func saveTaskMessage(
        taskId: String,
        message: String,
        role: String,
        artifacts: [[String: AnyObject]],
        authToken: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let encodedTaskId = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskId
        let urlString = "\(API.kHiveBaseUrl)/tasks/\(encodedTaskId)/messages/save"
        let params: [String: AnyObject] = [
            "message": message as AnyObject,
            "role": role as AnyObject,
            "artifacts": artifacts as AnyObject
        ]
        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] saveTaskMessage unauthorized (401)")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] saveTaskMessage error: \(error)")
                    errorCallback()
                    return
                }
                guard json["success"].bool == true else {
                    print("[HiveAPI] saveTaskMessage returned success=false")
                    errorCallback()
                    return
                }
                let savedMessage = HiveChatMessage(json: json["message"])
                callback(savedMessage)
            case .failure(let error):
                print("[HiveAPI] saveTaskMessage failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func saveTaskMessageWithAuth(
        taskId: String,
        message: String,
        role: String,
        artifacts: [[String: AnyObject]],
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            saveTaskMessage(
                taskId: taskId,
                message: message,
                role: role,
                artifacts: artifacts,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndSaveTaskMessage(
                        taskId: taskId,
                        message: message,
                        role: role,
                        artifacts: artifacts,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndSaveTaskMessage(
                taskId: taskId,
                message: message,
                role: role,
                artifacts: artifacts,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndSaveTaskMessage(
        taskId: String,
        message: String,
        role: String,
        artifacts: [[String: AnyObject]],
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.saveTaskMessage(
                    taskId: taskId,
                    message: message,
                    role: role,
                    artifacts: artifacts,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Workflow Editor Debug Message

    func sendWorkflowEditorDebugMessage(
        taskId: String,
        message: String,
        workflowId: Int,
        workflowName: String,
        workflowRefId: String,
        workflowVersionId: String,
        authToken: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let urlString = "\(API.kHiveBaseUrl)/workflow-editor"
        let params: [String: AnyObject] = [
            "taskId": taskId as AnyObject,
            "message": message as AnyObject,
            "workflowId": workflowId as AnyObject,
            "workflowName": workflowName as AnyObject,
            "workflowRefId": workflowRefId as AnyObject,
            "workflowVersionId": workflowVersionId as AnyObject
        ]
        guard let request = createRequest(urlString, bodyParams: params as NSDictionary, method: "POST", token: authToken) else {
            errorCallback()
            return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] sendWorkflowEditorDebugMessage unauthorized (401)")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] sendWorkflowEditorDebugMessage error: \(error)")
                    errorCallback()
                    return
                }
                guard json["success"].bool == true else {
                    print("[HiveAPI] sendWorkflowEditorDebugMessage returned success=false")
                    errorCallback()
                    return
                }
                guard let sentMessage = HiveChatMessage(json: json["message"]) else {
                    print("[HiveAPI] sendWorkflowEditorDebugMessage - failed to parse returned message")
                    errorCallback()
                    return
                }
                callback(sentMessage)
            case .failure(let error):
                print("[HiveAPI] sendWorkflowEditorDebugMessage failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func sendWorkflowEditorDebugMessageWithAuth(
        taskId: String,
        message: String,
        workflowId: Int,
        workflowName: String,
        workflowRefId: String,
        workflowVersionId: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            sendWorkflowEditorDebugMessage(
                taskId: taskId,
                message: message,
                workflowId: workflowId,
                workflowName: workflowName,
                workflowRefId: workflowRefId,
                workflowVersionId: workflowVersionId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndSendWorkflowEditorDebugMessage(
                        taskId: taskId,
                        message: message,
                        workflowId: workflowId,
                        workflowName: workflowName,
                        workflowRefId: workflowRefId,
                        workflowVersionId: workflowVersionId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndSendWorkflowEditorDebugMessage(
                taskId: taskId,
                message: message,
                workflowId: workflowId,
                workflowName: workflowName,
                workflowRefId: workflowRefId,
                workflowVersionId: workflowVersionId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndSendWorkflowEditorDebugMessage(
        taskId: String,
        message: String,
        workflowId: Int,
        workflowName: String,
        workflowRefId: String,
        workflowVersionId: String,
        callback: @escaping HiveChatMessageCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.sendWorkflowEditorDebugMessage(
                    taskId: taskId,
                    message: message,
                    workflowId: workflowId,
                    workflowName: workflowName,
                    workflowRefId: workflowRefId,
                    workflowVersionId: workflowVersionId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }

    // MARK: - Fetch Workflow Versions

    func fetchWorkflowVersions(
        workspaceSlug: String,
        workflowId: Int,
        authToken: String,
        callback: @escaping HiveWorkflowVersionsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let encodedSlug = workspaceSlug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? workspaceSlug
        let urlString = "\(API.kHiveBaseUrl)/workspaces/\(encodedSlug)/workflows/\(workflowId)/versions"
        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback()
            return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[HiveAPI] fetchWorkflowVersions unauthorized (401)")
                errorCallback()
                return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                if let error = json["error"].string {
                    print("[HiveAPI] fetchWorkflowVersions error: \(error)")
                    errorCallback()
                    return
                }
                let versions = (json["data"]["versions"].array ?? []).compactMap { WorkflowVersion(json: $0) }
                callback(versions)
            case .failure(let error):
                print("[HiveAPI] fetchWorkflowVersions failed: \(error.localizedDescription)")
                errorCallback()
            }
        }
    }

    func fetchWorkflowVersionsWithAuth(
        workspaceSlug: String,
        workflowId: Int,
        callback: @escaping HiveWorkflowVersionsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchWorkflowVersions(
                workspaceSlug: workspaceSlug,
                workflowId: workflowId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] in
                    self?.authenticateAndFetchWorkflowVersions(
                        workspaceSlug: workspaceSlug,
                        workflowId: workflowId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchWorkflowVersions(
                workspaceSlug: workspaceSlug,
                workflowId: workflowId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchWorkflowVersions(
        workspaceSlug: String,
        workflowId: Int,
        callback: @escaping HiveWorkflowVersionsCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback(); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchWorkflowVersions(
                    workspaceSlug: workspaceSlug,
                    workflowId: workflowId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: errorCallback
        )
    }


    // MARK: - Fetch Stakwork Project

    func fetchStakworkProject(
        projectId: String,
        authToken: String,
        callback: @escaping ([String: Any]) -> Void,
        errorCallback: @escaping (String) -> Void
    ) {
        let urlString = "\(API.kHiveBaseUrl)/stakwork/projects/\(projectId)"
        guard let request = createRequest(urlString, bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback("Invalid request"); return
        }
        session()?.request(request).responseData { response in
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                errorCallback("Unauthorized"); return
            }
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                guard json["success"].bool == true,
                      let project = json["data"]["project"].dictionaryObject else {
                    errorCallback(json["error"].string ?? "Failed to load project"); return
                }
                var result = project
                result["current_transition_completion"] = json["data"]["current_transition_completion"].doubleValue
                callback(result)
            case .failure(let error):
                errorCallback(error.localizedDescription)
            }
        }
    }

    func fetchStakworkProjectWithAuth(
        projectId: String,
        callback: @escaping ([String: Any]) -> Void,
        errorCallback: @escaping (String) -> Void
    ) {
        if let storedToken: String = UserDefaults.Keys.hiveToken.get() {
            fetchStakworkProject(
                projectId: projectId,
                authToken: storedToken,
                callback: callback,
                errorCallback: { [weak self] _ in
                    self?.authenticateAndFetchStakworkProject(
                        projectId: projectId,
                        callback: callback,
                        errorCallback: errorCallback
                    )
                }
            )
        } else {
            authenticateAndFetchStakworkProject(
                projectId: projectId,
                callback: callback,
                errorCallback: errorCallback
            )
        }
    }

    private func authenticateAndFetchStakworkProject(
        projectId: String,
        callback: @escaping ([String: Any]) -> Void,
        errorCallback: @escaping (String) -> Void
    ) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { errorCallback("Authentication failed"); return }
                UserDefaults.Keys.hiveToken.set(token)
                self?.fetchStakworkProject(
                    projectId: projectId,
                    authToken: token,
                    callback: callback,
                    errorCallback: errorCallback
                )
            },
            errorCallback: { errorCallback("Authentication failed") }
        )
    }

}

// MARK: - Workspace Image Cache

class WorkspaceImageCache: @unchecked Sendable {
    nonisolated(unsafe) static let shared = WorkspaceImageCache()

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
