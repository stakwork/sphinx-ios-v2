//
//  AttachmentsManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 27/11/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import UIKit
import SwiftyJSON
import AVFoundation

@objc protocol AttachmentsManagerDelegate: class {
    @objc optional func didUpdateUploadProgressFor(messageId: Int, progress: Int)
    @objc optional func didUpdateUploadProgress(progress: Int)
    @objc optional func didFailSendingMessage(provisionalMessage: TransactionMessage?, errorMessage: String)
    @objc optional func didSuccessSendingAttachment(message: TransactionMessage, image: UIImage?, provisionalMessageId: Int)
    @objc optional func didSuccessUploadingImage(url: String)
    @objc optional func shouldReplaceMediaDataFor(provisionalMessageId: Int, and messageId: Int)
}

class AttachmentsManager {
    
    class var sharedInstance : AttachmentsManager {
        struct Static {
            static let instance = AttachmentsManager()
        }
        return Static.instance
    }
    
    public enum AttachmentType: Int {
        case Photo
        case Video
        case Audio
        case Gif
        case Text
        case PDF
        case GenericFile
    }
    
    var uploading = false
    var provisionalMessage: TransactionMessage? = nil
    var contact: UserContact? = nil
    var chat: Chat? = nil
    var uploadedImage: UIImage? = nil
    
    weak var delegate: AttachmentsManagerDelegate?
    
    func setData(delegate: AttachmentsManagerDelegate, contact: UserContact?, chat: Chat?, provisionalMessage: TransactionMessage? = nil) {
        self.delegate = delegate
        self.provisionalMessage = provisionalMessage
        self.contact = contact
        self.chat = chat
        self.uploadedImage = nil
    }
    
    func setDelegate(delegate: AttachmentsManagerDelegate) {
        self.delegate = delegate
    }
    
    func authenticate(
        completion: @escaping () -> (),
        errorCompletion: @escaping () -> ()
    ) {
        if let token: String = UserDefaults.Keys.attachmentsToken.get() {
            let expDate: Date? = UserDefaults.Keys.attachmentsTokenExpDate.get()
            
            if let expDate = expDate, expDate > Date() {
                completion()
                return
            }
        }
        
        guard let _ = SphinxOnionManager.sharedInstance.getAccountSeed() else {
            errorCompletion()
            return
        }
        
        guard let pubkey = UserContact.getOwner()?.publicKey else {
            errorCompletion()
            return
        }
        
        API.sharedInstance.askAuthentication(callback: { id, challenge in
            if let id = id, let challenge = challenge {
                
                self.delegate?.didUpdateUploadProgressFor?(messageId: self.provisionalMessage?.id ?? -1, progress: 10)
                
                guard let sig = SphinxOnionManager.sharedInstance.signChallenge(challenge: challenge) else{
                    errorCompletion()
                    return
                }
                
                self.delegate?.didUpdateUploadProgressFor?(messageId: self.provisionalMessage?.id ?? -1, progress: 15)
                
                API.sharedInstance.verifyAuthentication(id: id, sig: sig, pubkey: pubkey, callback: { token in
                    if let token = token {
                        UserDefaults.Keys.attachmentsToken.set(token)
                        
                        if let ts = token.decodeJWT().payload?["exp"] as? Int64 {
                            let timestamp = TimeInterval(integerLiteral: ts)
                            let date = Date(timeIntervalSince1970: timestamp)
                            UserDefaults.Keys.attachmentsTokenExpDate.set(date)
                        }
                        
                        completion()
                    } else {
                        errorCompletion()
                    }
                })
                
            } else {
                errorCompletion()
            }
        })
    }
    
    func cancelUpload() {
        API.sharedInstance.cancelUploadRequest()
        uploading = false
        provisionalMessage = nil
        delegate = nil
        uploadedImage = nil
    }
    
    func isAuthenticated() -> (Bool, String?) {
        if let token: String = UserDefaults.Keys.attachmentsToken.get() {
            let expDate: Date? = UserDefaults.Keys.attachmentsTokenExpDate.get()
            
            if let expDate = expDate, expDate > Date() {
                return (true, token)
            }
        }
        return (false, nil)
    }
    
    func getMediaItemInfo(message: TransactionMessage, callback: @escaping MediaInfoCallback) {
        let isAuthenticated = isAuthenticated()
        
        if !isAuthenticated.0 {
            self.authenticate(completion: {
                self.getMediaItemInfo(message: message, callback: callback)
            }, errorCompletion: {
                UserDefaults.Keys.attachmentsToken.removeValue()
            })
            return
        }
        
        guard let token = isAuthenticated.1 else {
            return
        }
        
        API.sharedInstance.getMediaItemInfo(message: message, token: token, callback: callback)
    }
    
    func uploadImage(attachmentObject: AttachmentObject, route: String = "file") {
        delegate?.didUpdateUploadProgress?(progress: 5)
        
        let isAuthenticated = isAuthenticated()
        
        if !isAuthenticated.0 {
            self.authenticate(completion: {
                self.uploadImage(attachmentObject: attachmentObject, route: route)
            }, errorCompletion: {
                UserDefaults.Keys.attachmentsToken.removeValue()
                self.uploadFailed(errorMessage: "Could not authenticate with Memes server")
            })
            return
        }
        delegate?.didUpdateUploadProgress?(progress: 10)
        
        guard let token = isAuthenticated.1 else {
            return
        }
        
        if let _ = attachmentObject.data {
            uploadData(attachmentObject: attachmentObject, route: route, token: token) { fileJSON, _ in
                if let muid = fileJSON["muid"] as? String {
                    self.delegate?.didSuccessUploadingImage?(url: "\(API.kAttachmentsServerUrl)/public/\(muid)")
                }
            }
        }
    }
    
    func uploadAndSendAttachment(
        attachmentObject: AttachmentObject,
        chat: Chat?,
        provisionalMessage: TransactionMessage? = nil,
        replyingMessage: TransactionMessage? = nil,
        threadUUID: String? = nil
    ) {
        uploading = true
        delegate?.didUpdateUploadProgress?(progress: 5)
        
        let isAuthenticated = isAuthenticated()
        
        if !isAuthenticated.0 {
            self.authenticate(completion: {
                self.uploadAndSendAttachment(
                    attachmentObject: attachmentObject,
                    chat: chat,
                    provisionalMessage: provisionalMessage,
                    replyingMessage: replyingMessage
                )
            }, errorCompletion: {
                UserDefaults.Keys.attachmentsToken.removeValue()
                self.uploadFailed(errorMessage: "Could not authenticate with Memes server")
            })
            return
        }
        delegate?.didUpdateUploadProgress?(progress: 10)
        
        guard let token = isAuthenticated.1 else {
            return
        }
        
        if let _ = attachmentObject.data {
            uploadEncryptedData(attachmentObject: attachmentObject, token: token) { fileJSON, AttachmentObject in
                let (msg, errorMessage) = self.sendAttachment(
                    file: fileJSON,
                    chat: chat,
                    attachmentObject: attachmentObject,
                    provisionalMessage: provisionalMessage,
                    replyingMessage: replyingMessage,
                    threadUUID: threadUUID
                )
                
                if let errorMessage = errorMessage, msg == nil {
                    self.uploadFailed(errorMessage: errorMessage)
                }
            }
        }
    }
    
    func uploadEncryptedData(attachmentObject: AttachmentObject, token: String, completion: @escaping (NSDictionary, AttachmentObject) -> ()) {
        uploadData(attachmentObject: attachmentObject, route: "file", token: token, completion: completion)
    }
    
    func uploadPublicData(attachmentObject: AttachmentObject, token: String, completion: @escaping (NSDictionary, AttachmentObject) -> ()) {
        uploadData(attachmentObject: attachmentObject, route: "public", token: token, completion: completion)
    }
    
    func uploadData(attachmentObject: AttachmentObject, route: String, token: String, completion: @escaping (NSDictionary, AttachmentObject) -> ()) {
        API.sharedInstance.uploadData(attachmentObject: attachmentObject, route: route, token: token, progressCallback: { progress in
            let totalProgress = (progress * 85) / 100 + 10
            self.delegate?.didUpdateUploadProgressFor?(messageId: self.provisionalMessage?.id ?? -1, progress: totalProgress)
        }, callback: { success, fileJSON in
            AttachmentsManager.sharedInstance.uploading = false
            if let fileJSON = fileJSON, success {
                self.uploadedImage = attachmentObject.image
                
                self.delegate?.didUpdateUploadProgressFor?(messageId: self.provisionalMessage?.id ?? -1, progress: 100)

                completion(fileJSON, attachmentObject)
            } else {
                self.uploadFailed(errorMessage: "Failed to upload data to Memes server")
            }
        })
    }
    
    func sendAttachment(
        file: NSDictionary,
        chat:Chat?,
        attachmentObject: AttachmentObject,
        provisionalMessage: TransactionMessage? = nil,
        replyingMessage: TransactionMessage? = nil,
        threadUUID: String? = nil
    ) -> (TransactionMessage?, String?) {
        return SphinxOnionManager.sharedInstance.sendAttachment(
            file: file,
            attachmentObject: attachmentObject,
            chat: chat,
            provisionalMessage: provisionalMessage,
            replyingMessage: replyingMessage,
            threadUUID: threadUUID
        )
        
    }
    
    func payAttachment(message: TransactionMessage, chat: Chat?, callback: @escaping (TransactionMessage?) -> ()) {
        guard let price = message.getAttachmentPrice() else {
            return
        }
        SphinxOnionManager.sharedInstance.payAttachment(message: message, price: price)
    }
    
    func createLocalMessage(
        message: JSON,
        attachmentObject: AttachmentObject
    ) {
        let provisionalMessageId = provisionalMessage?.id
        
        if let provisionalMessage = provisionalMessage {
            delegate?.shouldReplaceMediaDataFor?(
                provisionalMessageId: provisionalMessage.id,
                and: message["id"].intValue
            )
        }
        
        if let message = TransactionMessage.insertMessage(
            m: message,
            existingMessage: provisionalMessage
        ).0 {
            delegate?.didUpdateUploadProgress?(progress: 100)
            cacheImageAndMediaData(message: message, attachmentObject: attachmentObject)
            uploadSucceed(message: message)
            deleteMessageWith(id: provisionalMessageId)
        }
    }
    
    func deleteMessageWith(id: Int?) {
        if let id = id {
            TransactionMessage.deleteMessageWith(id: id)
        }
    }
    
    func cacheImageAndMediaData(
        message: TransactionMessage,
        attachmentObject: AttachmentObject
    ) {
        if let mediaUrl = message.getMediaUrlFromMediaToken()?.absoluteString {
            if let data = attachmentObject.data {
                if let mediaKey = message.mediaKey {
                    if let decryptedData = SymmetricEncryptionManager.sharedInstance.decryptData(data: data, key: mediaKey) {
                        MediaLoader.storeMediaDataInCache(data: decryptedData, url: mediaUrl,message: message)
                    }
                }
            }
            
            if let image = uploadedImage {
                MediaLoader.storeImageInCache(
                    img: image,
                    url: mediaUrl,
                    message: message
                )
            }
        }
    }
    
    func uploadFailed(errorMessage: String) {
        uploading = false
        delegate?.didFailSendingMessage?(provisionalMessage: provisionalMessage, errorMessage: errorMessage)
    }
    
    func uploadSucceed(message: TransactionMessage) {
        uploading = false
        
        delegate?.didSuccessSendingAttachment?(
            message: message,
            image: self.uploadedImage,
            provisionalMessageId: provisionalMessage?.id ?? -1
        )
    }
    
    func getThumbnailFromVideo(videoURL: URL) -> UIImage? {
        var thumbnailImage: UIImage? = nil
        do {
            let asset = AVURLAsset(url: videoURL, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            thumbnailImage = UIImage(cgImage: cgImage)
        } catch _ {}
        
        return thumbnailImage
    }
}
