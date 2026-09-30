//
//  API+HivePlanExtension.swift
//  sphinx
//
//  Result types, pure status mapping and async wrappers used by the
//  Sphinx Agent plan tools.
//

import Foundation
import SwiftyJSON

// MARK: - Result types

enum FeatureChatSendResult {
    case sent(HiveChatMessage)
    case plannerBusy(String?)
    case notFound
    case forbidden
    case failed
}

enum HiveCreateFeatureResult {
    case created(HiveFeature)
    case createdUnparseable
    case failed(Int?)
}

// MARK: - Pure helpers

enum HiveRetryPolicy {
    /// Only an expired token justifies a re-auth + retry. Never retry 409/5xx (no double-posts).
    static func shouldReauthenticate(statusCode: Int?) -> Bool { statusCode == 401 }
}

enum HiveStatusMapper {
    static func sendResult(statusCode: Int, body: Data?) -> FeatureChatSendResult {
        switch statusCode {
        case 409: return .plannerBusy(errorMessage(from: body))
        case 404: return .notFound
        case 403: return .forbidden
        default: return .failed
        }
    }

    static func errorMessage(from body: Data?) -> String? {
        guard let body = body, !body.isEmpty else { return nil }
        let json = JSON(body)
        return json["error"].string ?? json["message"].string
    }
}

enum HiveFeatureParser {
    /// Parses a create response: `data`-wrapped first, falling back to a top-level feature.
    static func parseCreated(json: JSON) -> HiveFeature? {
        if let feature = HiveFeature(json: json["data"]) { return feature }
        return HiveFeature(json: json)
    }

    static func parseCreated(data: Data) -> HiveFeature? {
        parseCreated(json: JSON(data))
    }
}

// MARK: - API async wrappers

extension API {

    private func currentHiveToken() async -> String? { await currentHiveTokenInternal() }

    private func reauthenticateHive() async -> String? { await reauthenticateHiveInternal() }

    // MARK: send chat message

    private func sendChatAttempt(
        featureId: String,
        message: String,
        selectedRepositoryIds: [String]?,
        token: String
    ) async -> (FeatureChatSendResult, Int?) {
        await withCheckedContinuation { continuation in
            sendFeatureChatMessage(
                featureId: featureId,
                message: message,
                selectedRepositoryIds: selectedRepositoryIds,
                authToken: token,
                callback: { sent in
                    if let sent = sent {
                        continuation.resume(returning: (.sent(sent), 200))
                    } else {
                        continuation.resume(returning: (.failed, nil))
                    }
                },
                errorCallback: { continuation.resume(returning: (.failed, nil)) },
                statusErrorCallback: { status in
                    continuation.resume(
                        returning: (HiveStatusMapper.sendResult(statusCode: status ?? -1, body: nil), status)
                    )
                },
                errorBodyCallback: { status, body in
                    continuation.resume(
                        returning: (HiveStatusMapper.sendResult(statusCode: status ?? -1, body: body), status)
                    )
                }
            )
        }
    }

    /// Sends a plan chat message. Re-authenticates and retries ONLY on 401.
    func sendFeatureChatMessageResult(
        featureId: String,
        message: String,
        selectedRepositoryIds: [String]? = nil
    ) async -> FeatureChatSendResult {
        guard let token = await currentHiveToken() else { return .failed }
        var (result, status) = await sendChatAttempt(
            featureId: featureId, message: message,
            selectedRepositoryIds: selectedRepositoryIds, token: token
        )
        if HiveRetryPolicy.shouldReauthenticate(statusCode: status),
           let fresh = await reauthenticateHive() {
            (result, status) = await sendChatAttempt(
                featureId: featureId, message: message,
                selectedRepositoryIds: selectedRepositoryIds, token: fresh
            )
        }
        switch result {
        case .plannerBusy, .notFound, .forbidden:
            print("[HiveAPI] sendFeatureChatMessageResult status=\(status ?? -1) feature=\(featureId)")
        default: break
        }
        return result
    }

    // MARK: create feature

    private func createAttempt(
        workspaceId: String,
        title: String,
        description: String?,
        token: String
    ) async -> HiveCreateFeatureResult {
        await withCheckedContinuation { continuation in
            createFeature(
                workspaceId: workspaceId,
                title: title,
                authToken: token,
                callback: { feature in
                    if let feature = feature {
                        continuation.resume(returning: .created(feature))
                    } else {
                        continuation.resume(returning: .createdUnparseable)
                    }
                },
                errorCallback: { continuation.resume(returning: .failed(nil)) },
                statusErrorCallback: { continuation.resume(returning: .failed($0)) },
                description: description
            )
        }
    }

    /// Creates a feature. Re-authenticates and retries ONLY on 401.
    func createFeatureResult(
        workspaceId: String,
        title: String,
        description: String? = nil
    ) async -> HiveCreateFeatureResult {
        guard let token = await currentHiveToken() else { return .failed(nil) }
        var result = await createAttempt(
            workspaceId: workspaceId, title: title, description: description, token: token
        )
        if case .failed(let status) = result,
           HiveRetryPolicy.shouldReauthenticate(statusCode: status),
           let fresh = await reauthenticateHive() {
            result = await createAttempt(
                workspaceId: workspaceId, title: title, description: description, token: fresh
            )
        }
        return result
    }

    // MARK: orgs

    /// Returns every org's githubLogin from `/orgs` (unlike `fetchOrgs`, which returns only the first).
    func fetchAllOrgs(authToken: String) async -> [String]? {
        guard let request = createRequest(
            "\(API.kHiveBaseUrl)/orgs", bodyParams: nil, method: "GET", token: authToken
        ) else { return nil }
        guard let activeSession = session() else { return nil }
        return await withCheckedContinuation { continuation in
            activeSession.request(request).responseData { response in
                if response.response?.statusCode == 401 {
                    continuation.resume(returning: nil)
                    return
                }
                guard case .success(let data) = response.result,
                      let array = JSON(data).array else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: array.compactMap { $0["githubLogin"].string })
            }
        }
    }

    func fetchAllOrgsWithAuth() async -> [String]? {
        if let stored: String = UserDefaults.Keys.hiveToken.get(),
           let logins = await fetchAllOrgs(authToken: stored) { return logins }
        guard let fresh = await reauthenticateHive() else { return nil }
        return await fetchAllOrgs(authToken: fresh)
    }
}

// MARK: - Status-aware async fetches (401-only retry)

extension API {

    func fetchFeatureDetailResult(featureId: String) async -> (HiveFeature?, Int?) {
        func attempt(_ token: String) async -> (HiveFeature?, Int?) {
            await withCheckedContinuation { continuation in
                fetchFeatureDetail(
                    featureId: featureId,
                    authToken: token,
                    callback: { continuation.resume(returning: ($0, 200)) },
                    errorCallback: { continuation.resume(returning: (nil, nil)) },
                    statusErrorCallback: { continuation.resume(returning: (nil, $0)) }
                )
            }
        }
        guard let token = await currentHiveTokenInternal() else { return (nil, nil) }
        var result = await attempt(token)
        if HiveRetryPolicy.shouldReauthenticate(statusCode: result.1),
           let fresh = await reauthenticateHiveInternal() {
            result = await attempt(fresh)
        }
        return result
    }

    func fetchFeatureChatResult(featureId: String) async -> ([HiveChatMessage]?, Int?) {
        func attempt(_ token: String) async -> ([HiveChatMessage]?, Int?) {
            await withCheckedContinuation { continuation in
                fetchFeatureChat(
                    featureId: featureId,
                    authToken: token,
                    callback: { continuation.resume(returning: ($0, 200)) },
                    errorCallback: { continuation.resume(returning: (nil, nil)) },
                    statusErrorCallback: { continuation.resume(returning: (nil, $0)) }
                )
            }
        }
        guard let token = await currentHiveTokenInternal() else { return (nil, nil) }
        var result = await attempt(token)
        if HiveRetryPolicy.shouldReauthenticate(statusCode: result.1),
           let fresh = await reauthenticateHiveInternal() {
            result = await attempt(fresh)
        }
        return result
    }

    fileprivate func currentHiveTokenInternal() async -> String? {
        if let stored: String = UserDefaults.Keys.hiveToken.get() { return stored }
        return await reauthenticateHiveInternal()
    }

    fileprivate func reauthenticateHiveInternal() async -> String? {
        let token: String? = await withCheckedContinuation { continuation in
            authenticateWithHive(
                callback: { continuation.resume(returning: $0) },
                errorCallback: { continuation.resume(returning: nil) }
            )
        }
        if let token = token { storeHiveToken(token) }
        return token
    }
}
