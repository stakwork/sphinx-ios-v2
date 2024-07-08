//
//  API.swift
//  sphinx
//
//  Created by Tomas Timinskas on 12/09/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

typealias ContactsResultsCallback = (([JSON], [JSON], [JSON]) -> ())
typealias LatestContactsResultsCallback = (([JSON], [JSON], [JSON], [JSON]) -> ())
typealias ChatContactsCallback = (([JSON]) -> ())
typealias SphinxMessagesResultsCallback = ((JSON) -> ())
typealias SphinxHistoryResultsCallback = (([JSON]) -> ())
typealias DirectPaymentResultsCallback = ((JSON?) -> ())
typealias EmptyCallback = (() -> ())
typealias VideoFileExistsCallback = ((String?) -> ())
typealias GetBadgeCallback = (([Badge]) -> ())
typealias BalanceCallback = ((Int) -> ())
typealias BalancesCallback = ((Int, Int) -> ())
typealias CreateInvoiceCallback = ((JSON?, String?) -> ())
typealias PayInvoiceCallback = ((JSON) -> ())
typealias MessageObjectCallback = ((JSON) -> ())
typealias DeleteMessageCallback = ((Bool, JSON) -> ())
typealias GetMessagesCallback = (([JSON], [JSON], [JSON]) -> ())
typealias GetAllMessagesCallback = (([JSON]) -> ())
typealias GetMessagesPaginatedCallback = ((Int, [JSON]) -> ())
typealias CreateInviteCallback = ((JSON) -> ())
typealias UpdateUserCallback = ((JSON) -> ())
typealias UploadProgressCallback = ((Int) -> ())
typealias UploadCallback = ((Bool, String?) -> ())
typealias SuccessCallback = ((Bool) -> ())
typealias FetchRoutingInfoCallback = ((String?) -> ())
typealias UpdateRoutingInfoCallback = ((String?, String?) -> ())
typealias CreateSubscriptionCallback = ((JSON) -> ())
typealias GetSubscriptionsCallback = (([JSON]) -> ())
typealias MuteChatCallback = ((JSON) -> ())
typealias NotificationLevelCallback = ((JSON) -> ())
typealias GetAllTribesCallback = (([NSDictionary]) -> ())
typealias CreateGroupCallback = ((JSON) -> ())
typealias CreateTribeBadgeCallback = ((Bool) -> ())
typealias GetTribeBadgesCallback = (([NSDictionary]) -> ())
typealias GetTransactionsCallback = (([PaymentTransaction]) -> ())
typealias LogsCallback = ((String) -> ())
typealias TemplatesCallback = (([ImageTemplate]) -> ())
typealias AllContentFeedStatusCallback = (([ContentFeedStatus]) -> ())
typealias ContentFeedStatusCallback = ((ContentFeedStatus) -> ())
typealias ContentFeedCallback = ((JSON) -> ())
typealias PodcastInfoCallback = ((JSON) -> ())
typealias OnchainAddressCallback = ((String) -> ())
typealias AppVersionsCallback = ((String) -> ())
typealias TransportKeyCallback = ((String) -> ())
typealias HMACKeyCallback = ((String) -> ())
typealias HardwarePublicKeyCallback = ((String) -> ())
typealias HardwareSeedCallback = ((Bool) -> ())
typealias SyncActionsCallback = ((Bool) -> ())
typealias RecommendationsCallback = (([RecommendationResult]) -> ())
typealias PinMessageCallback = ((String) -> ())
typealias ErrorCallback = ((String) -> ())

// HUB calls
typealias SignupWithCodeCallback = ((JSON, String, String) -> ())
typealias LowestPriceCallback = ((Double) -> ())
typealias PayInviteCallback = ((JSON) -> ())
typealias KarmaPurchaseValidationCallback = (Result<Void, API.RequestError>) -> ()
typealias NodePurchaseInvoiceCallback = (Result<API.HUBNodeInvoice, API.RequestError>) -> ()
typealias NodePurchaseValidationCallback = (Result<API.SphinxInviteCode, API.RequestError>) -> ()

//Attachments
typealias AskAuthenticationCallback = ((String?, String?) -> ())
typealias SignChallengeCallback = ((String?) -> ())
typealias VerifyAuthenticationCallback = ((String?) -> ())
typealias UploadAttachmentCallback = ((Bool, NSDictionary?) -> ())
typealias MediaInfoCallback = ((Int, String?, Int?) -> ())

typealias FeedSearchCompletionHandler = (
    Result<[FeedSearchResult], API.RequestError>
) -> ()

typealias BTSearchCompletionHandler = (
    Result<[BTMedia], API.RequestError>
) -> ()

typealias GetHasAdminCompletionHandler = (
    Result<Bool, API.RequestError>
) -> ()

typealias PodcastEpisodeSearchCompletionHandler = (
    Result<[ContentFeedItem], API.RequestError>
) -> ()



class API {
    typealias HUBNodeInvoice = String
    typealias SphinxInviteCode = String
    
    class var sharedInstance : API {
        struct Static {
            static let instance = API()
        }
        return Static.instance
    }

    let interceptor = SphinxInterceptor()
    var onionConnector = SphinxOnionConnector.sharedInstance
    var cancellableRequest: DataRequest?
    var podcastSearchRequest: DataRequest?
    var currentRequestType : API.CancellableRequestType = API.CancellableRequestType.messages
    var uploadRequest: UploadRequest?

    let messageBubbleHelper = NewMessageBubbleHelper()

    enum CancellableRequestType {
        case contacts
        case messages
    }

    public static var kAttachmentsServerUrl : String {
        get {
            if let fileServerURL = UserDefaults.Keys.fileServerURL.get(defaultValue: ""), fileServerURL != "" {
                return fileServerURL
            }
            return "https://memes.sphinx.chat"
        }
        set {
            UserDefaults.Keys.fileServerURL.set(newValue)
        }
    }

    public static var kHUBServerUrl : String {
        get {
            if let inviteServerURL = UserDefaults.Keys.inviteServerURL.get(defaultValue: ""), inviteServerURL != "" {
                return inviteServerURL
            }
            return "https://hub.sphinx.chat"
        }
        set {
            UserDefaults.Keys.inviteServerURL.set(newValue)
        }
    }

    public static var kVideoCallServer : String {
        get {
            if let meetingServerURL = UserDefaults.Keys.meetingServerURL.get(defaultValue: ""), meetingServerURL != "" {
                return meetingServerURL
            }
            return "https://jitsi.sphinx.chat"
        }
        set {
            UserDefaults.Keys.meetingServerURL.set(newValue)
        }
    }
    
    public static let kPodcastIndexURL = "https://api.podcastindex.org"    
    

    class func getUrl(route: String) -> String {
        if let url = URL(string: route), let _ = url.scheme {
            return url.absoluteString
        }
        return "https://\(route)"
        
    }

    func session() -> Alamofire.Session? {
        return Alamofire.Session.default
    }

    var errorCounter = 0
    let successStatusCode = 200
    let unauthorizedStatusCode = 401
    let notFoundStatusCode = 404
    let badGatewayStatusCode = 502
    let connectionLostError = "The network connection was lost"

    public enum ConnectionStatus: Int {
        case Connecting
        case Connected
        case NotConnected
        case Unauthorize
        case NoNetwork
    }

    var connectionStatus = ConnectionStatus.Connecting

    func sphinxRequest(
        _ urlRequest: URLRequest,
        completionHandler: @escaping (AFDataResponse<Any>) -> Void
    ) {
        unauthorizedHandledRequest(urlRequest, completionHandler: completionHandler)
    }
    
    func unauthorizedHandledRequest(
        _ urlRequest: URLRequest,
        completionHandler: @escaping (AFDataResponse<Any>) -> Void
    ) {
        session()?.request(
            urlRequest,
            interceptor: interceptor
        ).responseJSON { (response) in
            
            let statusCode = (response.response?.statusCode ?? -1)
            
            switch statusCode {
            case self.successStatusCode:
                self.connectionStatus = .Connected
            case self.unauthorizedStatusCode:
                self.connectionStatus = .Unauthorize
            default:
                if response.response == nil ||
                    statusCode == self.notFoundStatusCode  ||
                    statusCode == self.badGatewayStatusCode {
                    
                    self.connectionStatus = response.response == nil ?
                        self.connectionStatus :
                        .NotConnected

                    if self.errorCounter < 5 {
                        self.errorCounter = self.errorCounter + 1
                    } else if response.response != nil {
                        return
                    }
                    completionHandler(response)
                    return
                } else {
                    self.connectionStatus = .NotConnected
                }
            }

            self.errorCounter = 0

            if let _ = response.response {
                completionHandler(response)
            }
        }
    }

    func networksConnectionLost() {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let centerVC = appDelegate.getCurrentVC()

            if centerVC?.isKind(of: DashboardRootViewController.self) ?? false {
                self.messageBubbleHelper.showGenericMessageView(text: "network.connection.lost".localized, delay: 3)
            }

            self.connectionStatus = .NoNetwork
        }
    }
    
    func postMQTTStatusChange(){
        NotificationCenter.default.post(name: .onMQTTConnectionStatusChanged, object: nil)
    }

    func createRequest(
        _ url: String,
        bodyParams: NSDictionary?,
        headers: [String: String] = .init(),
        method: String,
        contentType: String = "application/json",
        token: String? = nil
    ) -> URLRequest? {
        
        if !ConnectivityHelper.isConnectedToInternet {
            networksConnectionLost()
            return nil
        }

        if onionConnector.usingTor() && !onionConnector.isReady() {
            onionConnector.startIfNeeded()
            return nil
        }

        if let nsURL = URL(string: url) {
            var request = URLRequest(url: nsURL)
            request.httpMethod = method
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")

            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }

            if let p = bodyParams {
                do {
                    try request.httpBody = JSONSerialization.data(withJSONObject: p, options: [])
                } catch let error as NSError {
                    print("Error: " + error.localizedDescription)
                }
            }

            return request
        } else {
            return nil
        }
    }
}

class SphinxInterceptor : RequestInterceptor {
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        completion(.success(urlRequest))
    }

    public func retry(_ request: Request,
                      for session: Session,
                      dueTo error: Error,
                      completion: @escaping (RetryResult) -> Void) {
        completion(.doNotRetry)
    }
}
