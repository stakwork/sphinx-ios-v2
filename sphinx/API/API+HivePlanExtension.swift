//
//  API+HivePlanExtension.swift
//  sphinx
//
//  Status-aware Hive wrappers used by the Sphinx Agent plan tools.
//

import Foundation
import SwiftyJSON

enum FeatureChatSendResult {
    case sent(HiveChatMessage)
    case plannerBusy(String?)
    case notFound
    case forbidden
    case failed
}

enum CreateFeatureResult {
    case created(HiveFeature)
    case createdUnparseable
    case failed(Int?)
}

enum HiveStatusMapper {

    static func sendResult(statusCode: Int?, body: JSON?) -> FeatureChatSendResult {
        switch statusCode {
        case 409:
            return .plannerBusy(body?["error"].string ?? body?["message"].string)
        case 404: return .notFound
        case 403: return .forbidden
        case .some(let code) where (200..<300).contains(code):
            if let body = body, body["success"].bool == true,
               let m = HiveChatMessage(json: body["message"]) {
                return .sent(m)
            }
            return .failed
        default: return .failed
        }
    }

    /// Only an expired token justifies re-authenticating and retrying.
    static func shouldReauthAndRetry(statusCode: Int?) -> Bool {
        return statusCode == 401
    }

    static func createResult(statusCode: Int?, body: JSON?) -> CreateFeatureResult {
        guard let code = statusCode, (200..<300).contains(code) else { return .failed(statusCode) }
        guard let body = body else { return .createdUnparseable }
        if let f = HiveFeature(json: body["data"]) ?? HiveFeature(json: body) { return .created(f) }
        return .createdUnparseable
    }
}

extension API {

    private func withHiveToken(
        onFailure: @escaping () -> Void,
        attempt: @escaping (String, Bool) -> Void
    ) {
        if let token: String = UserDefaults.Keys.hiveToken.get() {
            attempt(token, true)
        } else {
            reauthenticateHive(onFailure: onFailure) { attempt($0, false) }
        }
    }

    private func reauthenticateHive(onFailure: @escaping () -> Void, then: @escaping (String) -> Void) {
        authenticateWithHive(
            callback: { [weak self] token in
                guard let token = token else { onFailure(); return }
                self?.storeHiveToken(token)
                then(token)
            },
            errorCallback: { onFailure() }
        )
    }

    /// Sends a chat message. Re-authenticates and retries ONLY on 401.
    func sendFeatureChatMessageResult(
        featureId: String,
        message: String,
        selectedRepositoryIds: [String]? = nil,
        completion: @escaping (FeatureChatSendResult) -> Void
    ) {
        withHiveToken(onFailure: { completion(.failed) }) { token, canRetry in
            self.sendFeatureChatMessage(
                featureId: featureId,
                message: message,
                selectedRepositoryIds: selectedRepositoryIds,
                authToken: token,
                callback: { sent in
                    if let sent = sent { completion(.sent(sent)) } else { completion(.failed) }
                },
                errorCallback: { completion(.failed) },
                statusErrorCallback: { status, body in
                    if canRetry, HiveStatusMapper.shouldReauthAndRetry(statusCode: status) {
                        self.reauthenticateHive(onFailure: { completion(.failed) }) { newToken in
                            self.sendFeatureChatMessageResult(
                                featureId: featureId, message: message,
                                selectedRepositoryIds: selectedRepositoryIds, completion: completion)
                        }
                        return
                    }
                    if let status = status, [403, 404, 409].contains(status) {
                        print("[HiveAPI] send chat message status \(status) feature=\(featureId)")
                    }
                    completion(HiveStatusMapper.sendResult(statusCode: status, body: body))
                }
            )
        }
    }

    /// Creates a feature. Re-authenticates and retries ONLY on 401 (never on 5xx/network).
    func createFeatureResult(
        workspaceId: String,
        title: String,
        description: String?,
        completion: @escaping (CreateFeatureResult) -> Void
    ) {
        withHiveToken(onFailure: { completion(.failed(401)) }) { token, canRetry in
            self.createFeature(
                workspaceId: workspaceId,
                title: title,
                description: description,
                authToken: token,
                callback: { feature in
                    if let feature = feature { completion(.created(feature)) } else { completion(.createdUnparseable) }
                },
                errorCallback: { completion(.failed(nil)) },
                statusErrorCallback: { status, _ in
                    if canRetry, HiveStatusMapper.shouldReauthAndRetry(statusCode: status) {
                        self.reauthenticateHive(onFailure: { completion(.failed(401)) }) { _ in
                            self.createFeatureResult(
                                workspaceId: workspaceId, title: title,
                                description: description, completion: completion)
                        }
                        return
                    }
                    completion(.failed(status))
                }
            )
        }
    }

    /// Every org the user belongs to (`/orgs`); `fetchOrgs` keeps only the first.
    func fetchAllOrgs(
        authToken: String,
        callback: @escaping ([HiveOrg]) -> Void,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let request = createRequest("\(API.kHiveBaseUrl)/orgs", bodyParams: nil, method: "GET", token: authToken) else {
            errorCallback()
            return
        }
        session()?.request(request).responseData { response in
            guard response.response?.statusCode != 401, case .success(let data) = response.result,
                  let arr = JSON(data).array else { errorCallback(); return }
            callback(arr.compactMap { HiveOrg(json: $0) })
        }
    }
}
