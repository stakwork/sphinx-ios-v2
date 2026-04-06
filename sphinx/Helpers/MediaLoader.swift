//
//  MediaLoader.swift
//  sphinx
//
//  Created by Tomas Timinskas on 20/09/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import SDWebImage
import AVFoundation
import Photos

class MediaLoader {
    
    nonisolated(unsafe) static let cache = SphinxCache()
    
    class func isAuthenticated() -> (Bool, String?) {
        if let token: String = UserDefaults.Keys.attachmentsToken.get() {
            let expDate: Date? = UserDefaults.Keys.attachmentsTokenExpDate.get()
            
            if let expDate = expDate, expDate > Date() {
                return (true, token)
            }
        }
        return (false, nil)
    }
    
    nonisolated class func loadDataFrom(
        URL: URL,
        includeToken: Bool = true,
        completion: @escaping @MainActor (Data, String?) -> (),
        errorCompletion: @escaping @MainActor () -> ()
    ) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        var request = URLRequest(url: URL as URL)
        
        let isAuthenticated = MediaLoader.isAuthenticated()
        
        if !isAuthenticated.0 {
            AttachmentsManager.sharedInstance.authenticate(completion: {
                self.loadDataFrom(
                    URL: URL,
                    includeToken: includeToken,
                    completion: completion,
                    errorCompletion: errorCompletion
                )
            }, errorCompletion: {
                Task { @MainActor in errorCompletion() }
            })
            return
        }
        
        if let token: String = isAuthenticated.1, includeToken {
            request.addValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }
        
        request.httpMethod = "GET"
        
        let task = session.dataTask(
            with: request,
            completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                if let _ = error {
                    Task { @MainActor in errorCompletion() }
                } else if let data = data {
                    let fileName = response?.getFileName()
                    Task { @MainActor in completion(data, fileName) }
                }
            }
        )
        
        task.resume()
    }
    
    @MainActor class func asyncLoadImage(
        imageView: UIImageView,
        nsUrl: URL,
        placeHolderImage: UIImage?,
        completion: (() -> ())? = nil
    ) {
        imageView.sd_setImage(
            with: nsUrl,
            placeholderImage: placeHolderImage,
            options: SDWebImageOptions.progressiveLoad,
            completed: { (image, error, _, _) in
                if let completion = completion, let _ = image {
                    Task { @MainActor in
                        completion()
                    }
                }
            }
        )
    }
    
    @MainActor class func asyncLoadImage(
        imageView: UIImageView,
        nsUrl: URL,
        placeHolderImage: UIImage?,
        completion: @escaping ((UIImage) -> ()),
        errorCompletion: ((Error) -> ())? = nil
    ) {
        imageView.sd_setImage(
            with: nsUrl,
            placeholderImage: placeHolderImage,
            options: SDWebImageOptions.progressiveLoad,
            completed: { (image, error, _, _) in
                if let image = image {
                    Task { @MainActor in
                        completion(image)
                    }
                } else if let errorCompletion = errorCompletion, let error = error {
                    errorCompletion(error)
                }
            }
        )
    }
    
    @MainActor class func asyncLoadImage(
        imageView: UIImageView,
        nsUrl: URL,
        placeHolderImage: UIImage?,
        id: Int,
        completion: @escaping @MainActor (UIImage, Int) -> (),
        errorCompletion: ((Error) -> ())? = nil
    ) {
        imageView.sd_setImage(
            with: nsUrl,
            placeholderImage: placeHolderImage,
            options: SDWebImageOptions.progressiveLoad,
            completed: { (image, error, _, _) in
                if let image = image {
                    Task { @MainActor in
                        completion(image, id)
                    }
                } else if let errorCompletion = errorCompletion, let error = error {
                    Task { @MainActor in
                        errorCompletion(error)
                    }
                }
            }
        )
    }
    
    @MainActor
    class func loadImage(
        url: URL,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping @MainActor (Int, UIImage) -> (),
        errorCompletion: @escaping @MainActor (Int) -> ()
    ) {
        let messageId = message.id
        let isGif = message.isGif()
        
        if message.isMediaExpired() {
            clearImageCacheFor(url: url.absoluteString)
            Task { @MainActor in errorCompletion(messageId) }
            return
        } else if let cachedImage = getImageFromCachedUrl(url: url.absoluteString) {
            if !isGif || (isGif && getMediaDataFromCachedUrl(url: url.absoluteString) != nil) {
                Task { @MainActor in completion(messageId, cachedImage) }
                return
            }
        }
        
        loadDataFrom(URL: url, completion: { (data, fileName) in
            message.saveFileName(fileName)
            
            loadImageFromData(
                data: data,
                url: url,
                message: message,
                mediaKey: mediaKey,
                completion: completion,
                errorCompletion: errorCompletion
            )
        }, errorCompletion: {
            errorCompletion(messageId)
        })
    }
    
    @MainActor class func loadImageFromData(
        data: Data,
        url: URL,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping @MainActor (Int, UIImage) -> (),
        errorCompletion: @escaping @MainActor (Int) -> ()
    ) {
        let messageId = message.id
        let isGif = message.isGif()
        let isPDF = message.isPDF()
        var decryptedImage:UIImage? = nil
        
        if let image = UIImage(data: data) {
            decryptedImage = image
        } else if let mediaKey = mediaKey, mediaKey != "" {
            if let decryptedData = SymmetricEncryptionManager.sharedInstance.decryptData(data: data, key: mediaKey) {
                message.saveFileSize(decryptedData.count)
                
                if isGif || isPDF {
                    storeMediaDataInCache(data: decryptedData, url: url.absoluteString)
                }
                decryptedImage = getImageFromData(decryptedData, isPdf: isPDF)
            }
        }
        
        if let decryptedImage = decryptedImage {
            storeImageInCache(
                img: decryptedImage,
                url: url.absoluteString,
                message: message
            )
            
            Task { @MainActor in completion(messageId, decryptedImage) }
        } else {
            Task { @MainActor in errorCompletion(messageId) }
        }
    }
    
    class func getImageFromData(
        _ data: Data,
        isPdf: Bool
    ) -> UIImage? {
        if isPdf {
            if let image = data.getPDFThumbnail() {
                return image
            }
        }
        return UIImage(data: data)
    }
    
    @MainActor
    class func loadMessageData(
        url: URL,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping @MainActor (Int, String) -> (),
        errorCompletion: @escaping @MainActor (Int) -> ()
    ) {
        let messageId = message.id
        
        loadDataFrom(URL: url, completion: { (data, _) in
            if let mediaKey = mediaKey, mediaKey.isNotEmpty {
                if let data = SymmetricEncryptionManager.sharedInstance.decryptData(data: data, key: mediaKey) {
                    let str = String(decoding: data, as: UTF8.self)
                    if str != "" {
                        Task { @MainActor in
                            message.messageContent = str
                            completion(message.id, str)
                        }
                        return
                    }
                }
            }
            Task { @MainActor in errorCompletion(messageId) }
        }, errorCompletion: {
            Task { @MainActor in errorCompletion(messageId) }
        })
    }
    
    @MainActor
    class func loadVideo(
        url: URL,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping @MainActor (Int, Data, UIImage?) -> (),
        errorCompletion: @escaping @MainActor (Int) -> ()
    ) {
        let messageId = message.id
        
        if message.isMediaExpired() {
            clearImageCacheFor(url: url.absoluteString)
            clearMediaDataCacheFor(url: url.absoluteString)
            Task { @MainActor in errorCompletion(messageId) }
        } else if let data = getMediaDataFromCachedUrl(url: url.absoluteString) {
            let image = self.getImageFromCachedUrl(url: url.absoluteString) ?? nil
            if image == nil {
                self.getThumbnailImageFromVideoData(data: data, videoUrl: url.absoluteString, completion: { image in
                    Task { @MainActor in completion(messageId, data, image) }
                })
            } else {
                Task { @MainActor in completion(messageId, data, image) }
            }
        } else {
            loadDataFrom(URL: url, completion: { (data, fileName) in
                message.saveFileName(fileName)
                
                self.loadMediaFromData(
                    data: data,
                    url: url,
                    message: message,
                    mediaKey: mediaKey,
                    isVideo: true,
                    completion: { data in
                        self.getThumbnailImageFromVideoData(data: data, videoUrl: url.absoluteString, completion: { image in
                            Task { @MainActor in completion(messageId, data, image) }
                        })
                    },
                    errorCompletion: errorCompletion
                )
            }, errorCompletion: {
                Task { @MainActor in errorCompletion(messageId) }
            })
        }
    }
    
    @MainActor
    class func loadFileData(
        url: URL,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping @MainActor (Int, Data) -> (),
        errorCompletion: @escaping @MainActor (Int) -> ()
    ) {
        let messageId = message.id
        
        if message.isMediaExpired() {
            clearMediaDataCacheFor(url: url.absoluteString)
            Task { @MainActor in errorCompletion(messageId) }
        } else if let data = getMediaDataFromCachedUrl(url: url.absoluteString) {
            Task { @MainActor in completion(messageId, data) }
        } else {
            loadDataFrom(URL: url, completion: { (data, fileName) in
                message.saveFileName(fileName)
                
                self.loadMediaFromData(
                    data: data,
                    url: url,
                    message: message,
                    mediaKey: mediaKey,
                    completion: { data in
                        Task { @MainActor in completion(messageId, data) }
                    },
                    errorCompletion: errorCompletion
                )
            }, errorCompletion: {
                Task { @MainActor in errorCompletion(messageId) }
            })
        }
    }
    
    @MainActor
    class func loadFileData(
        url: URL,
        isPdf: Bool,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping @MainActor (Int, Data, MessageTableCellState.FileInfo) -> (),
        errorCompletion: @escaping @MainActor (Int) -> ()
    ) {
        let messageId = message.id
        
        if message.isMediaExpired() {
            clearMediaDataCacheFor(url: url.absoluteString)
            Task { @MainActor in errorCompletion(messageId) }
        } else if let data = getMediaDataFromCachedUrl(url: url.absoluteString) {
            
            let fileInfo = MessageTableCellState.FileInfo(
                fileSize: message.mediaFileSize,
                fileName: message.mediaFileName ?? "",
                pagesCount: isPdf ? data.getPDFPagesCount() : nil,
                previewImage: isPdf ? data.getPDFThumbnail() : nil
            )
            
            Task { @MainActor in completion(messageId, data, fileInfo) }
        } else {
            loadDataFrom(URL: url, completion: { (data, fileName) in
                message.saveFileName(fileName)
                
                self.loadMediaFromData(
                    data: data,
                    url: url,
                    message: message,
                    mediaKey: mediaKey,
                    completion: { data in
                        let fileInfo = MessageTableCellState.FileInfo(
                            fileSize: message.mediaFileSize,
                            fileName: message.mediaFileName ?? "",
                            pagesCount: isPdf ? data.getPDFPagesCount() : nil,
                            previewImage: isPdf ? data.getPDFThumbnail() : nil
                        )
                        
                        Task { @MainActor in completion(messageId, data, fileInfo) }
                    },
                    errorCompletion: errorCompletion
                )
            }, errorCompletion: {
                Task { @MainActor in errorCompletion(messageId) }
            })
        }
    }
    
    @MainActor class func loadMediaFromData(
        data: Data,
        url: URL, message: TransactionMessage,
        mediaKey: String? = nil,
        isVideo: Bool = false,
        completion: @escaping @MainActor (Data) -> (),
        errorCompletion: @escaping @MainActor (Int) -> ()
    ) {
        if let mediaKey = mediaKey, mediaKey != "" {
            
            if let decryptedData = SymmetricEncryptionManager.sharedInstance.decryptData(
                data: data,
                key: mediaKey
            ) {
                message.saveFileSize(decryptedData.count)

                storeMediaDataInCache(
                    data: decryptedData,
                    url: url.absoluteString,
                    message: message
                )

                Task { @MainActor in completion(decryptedData) }
                return
            }
        } else {
            storeMediaDataInCache(
                data: data,
                url: url.absoluteString
            )
            
            Task { @MainActor in completion(data) }
        }
    }
    
    class func loadTemplate(
        row: Int,
        muid: String,
        completion: @escaping @MainActor (Int, String, UIImage) -> ()
    ) {
        let urlString = "\(API.kAttachmentsServerUrl)/template/\(muid)"
        
        if let url = URL(string: urlString) {
            if let cachedImage = getImageFromCachedUrl(url: url.absoluteString) {
                Task { @MainActor in completion(row, muid, cachedImage) }
            } else {
                loadDataFrom(URL: url, includeToken: true, completion: { (data, _) in
                    if let image = UIImage(data: data) {
                        self.storeImageInCache(
                            img: image,
                            url: url.absoluteString,
                            message: nil
                        )
                        
                        Task { @MainActor in completion(row, muid, image) }
                        return
                    }
                }, errorCompletion: {})
            }
        }
    }
    
    class func loadPublicImage(
        url: URL,
        messageId: Int,
        completion: @escaping @MainActor (Int, UIImage) -> (),
        errorCompletion: @escaping @MainActor  (Int) -> ()
    ) {
        if let cachedImage = getImageFromCachedUrl(url: url.absoluteString) {
            Task { @MainActor in completion(messageId, cachedImage) }
        } else {
            loadDataFrom(URL: url, includeToken: true, completion: { (data, _) in
                if let image = UIImage(data: data) {
                    self.storeImageInCache(
                        img: image,
                        url: url.absoluteString,
                        message: nil
                    )
                    
                    Task { @MainActor in completion(messageId, image) }
                    return
                }
            }, errorCompletion: {})
        }
    }
    
    nonisolated class func getDataFromUrl(
        url: URL
    ) -> Data? {
        var data: Data?
        do {
            data = try Data(contentsOf: url as URL, options: Data.ReadingOptions.alwaysMapped)
        } catch _ {
            data = nil
        }
        
        guard let data = data else {
            return nil
        }
        return data
    }
    
    nonisolated class func saveFileInMemory(
        data: Data,
        name: String
    ) -> URL? {
        guard var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        url.appendPathComponent(name)
        do {
            try data.write(to: url)
        } catch {
            return nil
        }
        return url
    }
    
    nonisolated class func getThumbnailImageFromVideoData(
        data: Data,
        videoUrl: String,
        completion: @escaping ((_ image: UIImage?)->Void)
    ) {
        if let url = saveFileInMemory(data: data, name: "video.mov") {
            let asset = AVAsset(url: url)
            
            DispatchQueue.global().async {
                let avAssetImageGenerator = AVAssetImageGenerator(asset: asset)
                avAssetImageGenerator.appliesPreferredTrackTransform = true
                let thumnailTime = CMTimeMake(value: 5, timescale: 1)
                do {
                    let cgThumbImage = try avAssetImageGenerator.copyCGImage(at: thumnailTime, actualTime: nil)
                    let thumbImage = UIImage(cgImage: cgThumbImage)
                    deleteItemAt(url: url)
                    
                    storeImageInCache(
                        img: thumbImage,
                        url: videoUrl,
                        message: nil
                    )
                    
                    Task { @MainActor in completion(thumbImage) }
                } catch {
                    deleteItemAt(url: url)
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        } else {
            completion(nil)
        }
    }
    
    nonisolated class func clearMessageMediaCache(message: TransactionMessage) {
        if let url = message.getPurchaseAcceptItem()?.getMediaUrlFromMediaToken() ?? message.getMediaUrlFromMediaToken() {
            clearImageCacheFor(url: url.absoluteString)
            clearMediaDataCacheFor(url: url.absoluteString)
        }
    }
    
    nonisolated class func clearImageCacheFor(url: String) {
        SDImageCache.shared.removeImage(forKey: url, withCompletion: nil)
        cache.removeValue(forKey: url)
        
    }
    
    nonisolated class func storeImageInCache(
        img: UIImage,
        url: String,
        message: TransactionMessage? = nil
    ) {
        SDImageCache.shared.store(img, forKey: url, completion: nil)
        
        if
            let message = message,
            let chat = message.chat?.getChat(),
            let path = getDiskImagePath(forKey: url)
        {
            
            let randomInt = Int.random(in: 0...Int(1e9))
            let name = message.getFileName()
            
            CachedMedia.createObject(
                id: randomInt,
                chat: chat,
                filePath: path,
                fileExtension: "png",
                key: url,
                fileName: name
            )
        }
    }
    
    nonisolated class func getDiskImagePath(forKey key: String)->String? {
        return SDImageCache.shared.cachePath(forKey: key)
    }
    
    nonisolated class func getImageFromCachedUrl(url: String) -> UIImage? {
        return SDImageCache.shared.imageFromCache(forKey: url)
    }
    
    nonisolated class func storeMediaDataInCache(
        data: Data,
        url: String,
        message: TransactionMessage? = nil
    ) {
        cache[url] = data
        
        if
            let message = message,
            let chat = message.chat?.getChat(),
            let path = getDiskImagePath(forKey: url)
        {
            let randomInt = Int.random(in: 0...Int(1e9))
            let fileExtension = message.getCMExtensionAssignment()
            let name = message.getFileName()
            
            CachedMedia.createObject(
                id: randomInt,
                chat: chat,
                filePath: path,
                fileExtension: fileExtension,
                key: url,
                fileName: name
            )
        }
    }
    
    nonisolated class func getMediaDataFromCachedUrl(url: String) -> Data? {
        return cache[url]
    }
    
    nonisolated class func clearMediaDataCacheFor(url: String) {
        return cache.removeValue(forKey: url)
    }
        
    nonisolated class func deleteItemAt(url: URL) {
        do {
            try FileManager().removeItem(at: url)
        } catch {
            
        }
    }
}
