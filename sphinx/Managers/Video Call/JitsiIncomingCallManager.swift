//
//  CallManager.swift
//  Alamofire
//
//  Created by James Carucci on 2/20/23.
//

import Foundation
import CallKit
import UIKit

@available(iOS 14.0, *)
final class JitsiIncomingCallManager: NSObject, CXProviderDelegate, @unchecked Sendable {

    class var sharedInstance : JitsiIncomingCallManager {
        struct Static {
            nonisolated(unsafe) static let instance = JitsiIncomingCallManager()
        }
        return Static.instance
    }
    
    let provider = CXProvider(configuration: CXProviderConfiguration())
    let callController = CXCallController()
    var currentJitsiURL: String? = nil
    var hasVideo: Bool = false
    var uuid: UUID? = nil
    
    override init(){
        super.init()
        
        provider.setDelegate(self, queue: nil)
    }
    
    
    public func reportIncomingCall(
        uuid: UUID,
        handle: String
    ){
        self.uuid = uuid
        
        let update = CXCallUpdate()
        update.hasVideo = hasVideo
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        
        provider.configuration.supportsVideo = hasVideo
        provider.reportNewIncomingCall(with: uuid, update: update, completion: { error in
            if let error = error{
                print(String(describing: error))
            }
        })
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction){
        let hangUpAction = CXEndCallAction(call: action.callUUID)
        hangUpAction.fulfill()

        let callURL = currentJitsiURL
        let audioOnly = !hasVideo
        Task { @MainActor in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let callURL = callURL {
                appDelegate.handleAcceptedCall(
                    callLink: callURL,
                    audioOnly: audioOnly
                )
            }
        }

        finishCall()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction){
        self.uuid = nil
        action.fulfill()
    }
    
    
    func providerDidReset(_ provider: CXProvider) {
        self.uuid = nil
        print("Provider reset.")
    }
    
    func finishCall() {
        if let uuid = self.uuid {
            let callController = CXCallController()

            let endCallAction = CXEndCallAction(call: uuid)
            callController.request(
                CXTransaction(action: endCallAction),
                completion: { error in
                    if let error = error {
                        print("Error: \(error)")
                    } else {
                        print("Success")
                    }
                })
        }
    }
}
