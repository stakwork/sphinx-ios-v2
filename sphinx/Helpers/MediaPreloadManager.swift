//
//  MediaPreloadManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 17/02/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import UIKit

/// Manages media preloading and tracks in-progress downloads to prevent duplicates.
/// Downloads continue even when views are deallocated, ensuring images are cached.
class MediaPreloadManager: @unchecked Sendable {

    nonisolated(unsafe) static let sharedInstance = MediaPreloadManager()

    /// Completion handler type for image loads
    typealias ImageCompletion = (Int, UIImage) -> Void
    typealias ErrorCompletion = (Int) -> Void

    /// Tracks in-progress image downloads
    private var inProgressImageLoads: [String: [(completion: ImageCompletion, errorCompletion: ErrorCompletion, messageId: Int)]] = [:]

    /// Tracks in-progress video downloads
    private var inProgressVideoLoads: [String: [(completion: (Int, Data, UIImage?) -> Void, errorCompletion: ErrorCompletion, messageId: Int)]] = [:]

    /// Tracks in-progress file downloads
    private var inProgressFileLoads: [String: [(completion: (Int, Data, MessageTableCellState.FileInfo) -> Void, errorCompletion: ErrorCompletion, messageId: Int)]] = [:]

    /// Serial queue for thread-safe access to tracking dictionaries
    private let queue = DispatchQueue(label: "com.sphinx.mediaPreloadManager")

    private init() {}

    // MARK: - Image Loading

    /// Loads an image, deduplicating requests for the same URL.
    /// If a download is already in progress for the URL, the completion handlers are queued.
    /// Downloads continue even if the original caller is deallocated.
    func loadImage(
        url: URL,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping ImageCompletion,
        errorCompletion: @escaping ErrorCompletion
    ) {
        let urlString = url.absoluteString
        let messageId = message.id
        // Extract CoreData scalar properties on the calling thread before crossing queue.async boundary
        let isGif = message.isGif()
        let isExpired = message.isMediaExpired()

        queue.async { [weak self] in
            guard let self = self else { return }

            // Check if download is already in progress
            if var existingHandlers = self.inProgressImageLoads[urlString] {
                // Add completion handlers to existing download
                existingHandlers.append((completion, errorCompletion, messageId))
                self.inProgressImageLoads[urlString] = existingHandlers
                return
            }

            // Start new download and track it
            self.inProgressImageLoads[urlString] = [(completion, errorCompletion, messageId)]

            // Perform the actual load
            self.performImageLoad(
                url: url,
                messageId: messageId,
                isGif: isGif,
                isExpired: isExpired,
                mediaKey: mediaKey,
                urlString: urlString
            )
        }
    }

    private func performImageLoad(
        url: URL,
        messageId: Int,
        isGif: Bool,
        isExpired: Bool,
        mediaKey: String?,
        urlString: String
    ) {
        // Check if expired using pre-extracted scalar
        if isExpired {
            MediaLoader.clearImageCacheFor(url: urlString)
            notifyImageError(for: urlString)
            return
        }

        // Check cache first
        if let cachedImage = MediaLoader.getImageFromCachedUrl(url: urlString) {
            if !isGif || (isGif && MediaLoader.getMediaDataFromCachedUrl(url: urlString) != nil) {
                notifyImageSuccess(for: urlString, image: cachedImage)
                return
            }
        }

        // Load from network
        MediaLoader.loadDataFrom(URL: url, completion: { [weak self] (data, fileName) in
            self?.processImageData(
                data: data,
                url: url,
                messageId: messageId,
                fileName: fileName,
                mediaKey: mediaKey,
                urlString: urlString
            )
        }, errorCompletion: { [weak self] in
            self?.notifyImageError(for: urlString)
        })
    }

    private func processImageData(
        data: Data,
        url: URL,
        messageId: Int,
        fileName: String?,
        mediaKey: String?,
        urlString: String
    ) {
        // Re-fetch managed object fresh on whatever thread this completion runs on
        guard let message = TransactionMessage.getMessageWith(id: messageId) else {
            notifyImageError(for: urlString)
            return
        }
        message.saveFileName(fileName)

        let isGif = message.isGif()
        let isPDF = message.isPDF()
        var decryptedImage: UIImage? = nil

        if let image = UIImage(data: data) {
            decryptedImage = image
        } else if let mediaKey = mediaKey, mediaKey != "" {
            if let decryptedData = SymmetricEncryptionManager.sharedInstance.decryptData(data: data, key: mediaKey) {
                message.saveFileSize(decryptedData.count)

                if isGif || isPDF {
                    MediaLoader.storeMediaDataInCache(data: decryptedData, url: urlString)
                }
                decryptedImage = MediaLoader.getImageFromData(decryptedData, isPdf: isPDF)
            }
        }

        if let decryptedImage = decryptedImage {
            // Cache the image BEFORE notifying - this ensures it's cached even if all handlers are gone
            MediaLoader.storeImageInCache(
                img: decryptedImage,
                url: urlString,
                message: message
            )

            notifyImageSuccess(for: urlString, image: decryptedImage)
        } else {
            notifyImageError(for: urlString)
        }
    }

    private func notifyImageSuccess(for urlString: String, image: UIImage) {
        queue.async { [weak self] in
            guard let self = self,
                  let handlers = self.inProgressImageLoads.removeValue(forKey: urlString) else {
                return
            }

            DispatchQueue.main.async {
                for handler in handlers {
                    handler.completion(handler.messageId, image)
                }
            }
        }
    }

    private func notifyImageError(for urlString: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let handlers = self.inProgressImageLoads.removeValue(forKey: urlString) else {
                return
            }

            DispatchQueue.main.async {
                for handler in handlers {
                    handler.errorCompletion(handler.messageId)
                }
            }
        }
    }

    // MARK: - Video Loading

    func loadVideo(
        url: URL,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping (Int, Data, UIImage?) -> Void,
        errorCompletion: @escaping ErrorCompletion
    ) {
        let urlString = url.absoluteString
        let messageId = message.id
        // Extract CoreData scalar property on the calling thread before crossing queue.async boundary
        let isExpired = message.isMediaExpired()

        queue.async { [weak self] in
            guard let self = self else { return }

            if var existingHandlers = self.inProgressVideoLoads[urlString] {
                existingHandlers.append((completion, errorCompletion, messageId))
                self.inProgressVideoLoads[urlString] = existingHandlers
                return
            }

            self.inProgressVideoLoads[urlString] = [(completion, errorCompletion, messageId)]

            self.performVideoLoad(
                url: url,
                messageId: messageId,
                isExpired: isExpired,
                mediaKey: mediaKey,
                urlString: urlString
            )
        }
    }

    private func performVideoLoad(
        url: URL,
        messageId: Int,
        isExpired: Bool,
        mediaKey: String?,
        urlString: String
    ) {
        // Check if expired using pre-extracted scalar
        if isExpired {
            MediaLoader.clearImageCacheFor(url: urlString)
            MediaLoader.clearMediaDataCacheFor(url: urlString)
            notifyVideoError(for: urlString)
            return
        }

        // Check cache
        if let data = MediaLoader.getMediaDataFromCachedUrl(url: urlString) {
            let image = MediaLoader.getImageFromCachedUrl(url: urlString)
            if image == nil {
                MediaLoader.getThumbnailImageFromVideoData(data: data, videoUrl: urlString) { [weak self] thumbnail in
                    self?.notifyVideoSuccess(for: urlString, data: data, image: thumbnail)
                }
            } else {
                notifyVideoSuccess(for: urlString, data: data, image: image)
            }
            return
        }

        // Load from network
        MediaLoader.loadDataFrom(URL: url, completion: { [weak self] (data, fileName) in
            self?.processVideoData(
                data: data,
                url: url,
                messageId: messageId,
                fileName: fileName,
                mediaKey: mediaKey,
                urlString: urlString
            )
        }, errorCompletion: { [weak self] in
            self?.notifyVideoError(for: urlString)
        })
    }

    private func processVideoData(
        data: Data,
        url: URL,
        messageId: Int,
        fileName: String?,
        mediaKey: String?,
        urlString: String
    ) {
        // Re-fetch managed object fresh on whatever thread this completion runs on
        guard let message = TransactionMessage.getMessageWith(id: messageId) else {
            notifyVideoError(for: urlString)
            return
        }
        message.saveFileName(fileName)

        if let mediaKey = mediaKey, mediaKey != "" {
            if let decryptedData = SymmetricEncryptionManager.sharedInstance.decryptData(data: data, key: mediaKey) {
                message.saveFileSize(decryptedData.count)

                MediaLoader.storeMediaDataInCache(
                    data: decryptedData,
                    url: urlString,
                    message: message
                )

                MediaLoader.getThumbnailImageFromVideoData(data: decryptedData, videoUrl: urlString) { [weak self] thumbnail in
                    self?.notifyVideoSuccess(for: urlString, data: decryptedData, image: thumbnail)
                }
                return
            }
        } else {
            MediaLoader.storeMediaDataInCache(data: data, url: urlString)

            MediaLoader.getThumbnailImageFromVideoData(data: data, videoUrl: urlString) { [weak self] thumbnail in
                self?.notifyVideoSuccess(for: urlString, data: data, image: thumbnail)
            }
            return
        }

        notifyVideoError(for: urlString)
    }

    private func notifyVideoSuccess(for urlString: String, data: Data, image: UIImage?) {
        queue.async { [weak self] in
            guard let self = self,
                  let handlers = self.inProgressVideoLoads.removeValue(forKey: urlString) else {
                return
            }

            DispatchQueue.main.async {
                for handler in handlers {
                    handler.completion(handler.messageId, data, image)
                }
            }
        }
    }

    private func notifyVideoError(for urlString: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let handlers = self.inProgressVideoLoads.removeValue(forKey: urlString) else {
                return
            }

            DispatchQueue.main.async {
                for handler in handlers {
                    handler.errorCompletion(handler.messageId)
                }
            }
        }
    }

    // MARK: - File Loading

    func loadFile(
        url: URL,
        isPdf: Bool,
        message: TransactionMessage,
        mediaKey: String?,
        completion: @escaping (Int, Data, MessageTableCellState.FileInfo) -> Void,
        errorCompletion: @escaping ErrorCompletion
    ) {
        let urlString = url.absoluteString
        let messageId = message.id
        // Extract CoreData scalar properties on the calling thread before crossing queue.async boundary
        let isExpired = message.isMediaExpired()
        let mediaFileSize = message.mediaFileSize
        let mediaFileName = message.mediaFileName ?? ""

        queue.async { [weak self] in
            guard let self = self else { return }

            if var existingHandlers = self.inProgressFileLoads[urlString] {
                existingHandlers.append((completion, errorCompletion, messageId))
                self.inProgressFileLoads[urlString] = existingHandlers
                return
            }

            self.inProgressFileLoads[urlString] = [(completion, errorCompletion, messageId)]

            self.performFileLoad(
                url: url,
                isPdf: isPdf,
                messageId: messageId,
                isExpired: isExpired,
                mediaFileSize: mediaFileSize,
                mediaFileName: mediaFileName,
                mediaKey: mediaKey,
                urlString: urlString
            )
        }
    }

    private func performFileLoad(
        url: URL,
        isPdf: Bool,
        messageId: Int,
        isExpired: Bool,
        mediaFileSize: Int,
        mediaFileName: String,
        mediaKey: String?,
        urlString: String
    ) {
        // Check if expired using pre-extracted scalar
        if isExpired {
            MediaLoader.clearMediaDataCacheFor(url: urlString)
            notifyFileError(for: urlString)
            return
        }

        // Check cache using pre-extracted scalars
        if let data = MediaLoader.getMediaDataFromCachedUrl(url: urlString) {
            let fileInfo = MessageTableCellState.FileInfo(
                fileSize: mediaFileSize,
                fileName: mediaFileName,
                pagesCount: isPdf ? data.getPDFPagesCount() : nil,
                previewImage: isPdf ? data.getPDFThumbnail() : nil
            )
            notifyFileSuccess(for: urlString, data: data, fileInfo: fileInfo)
            return
        }

        // Load from network
        MediaLoader.loadDataFrom(URL: url, completion: { [weak self] (data, fileName) in
            self?.processFileData(
                data: data,
                url: url,
                isPdf: isPdf,
                messageId: messageId,
                fileName: fileName,
                mediaKey: mediaKey,
                urlString: urlString
            )
        }, errorCompletion: { [weak self] in
            self?.notifyFileError(for: urlString)
        })
    }

    private func processFileData(
        data: Data,
        url: URL,
        isPdf: Bool,
        messageId: Int,
        fileName: String?,
        mediaKey: String?,
        urlString: String
    ) {
        // Re-fetch managed object fresh on whatever thread this completion runs on
        guard let message = TransactionMessage.getMessageWith(id: messageId) else {
            notifyFileError(for: urlString)
            return
        }
        message.saveFileName(fileName)

        var finalData: Data? = nil

        if let mediaKey = mediaKey, mediaKey != "" {
            if let decryptedData = SymmetricEncryptionManager.sharedInstance.decryptData(data: data, key: mediaKey) {
                message.saveFileSize(decryptedData.count)
                finalData = decryptedData
            }
        } else {
            finalData = data
        }

        if let finalData = finalData {
            MediaLoader.storeMediaDataInCache(
                data: finalData,
                url: urlString,
                message: message
            )

            let fileInfo = MessageTableCellState.FileInfo(
                fileSize: message.mediaFileSize,
                fileName: message.mediaFileName ?? "",
                pagesCount: isPdf ? finalData.getPDFPagesCount() : nil,
                previewImage: isPdf ? finalData.getPDFThumbnail() : nil
            )

            notifyFileSuccess(for: urlString, data: finalData, fileInfo: fileInfo)
        } else {
            notifyFileError(for: urlString)
        }
    }

    private func notifyFileSuccess(for urlString: String, data: Data, fileInfo: MessageTableCellState.FileInfo) {
        queue.async { [weak self] in
            guard let self = self,
                  let handlers = self.inProgressFileLoads.removeValue(forKey: urlString) else {
                return
            }

            DispatchQueue.main.async {
                for handler in handlers {
                    handler.completion(handler.messageId, data, fileInfo)
                }
            }
        }
    }

    private func notifyFileError(for urlString: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let handlers = self.inProgressFileLoads.removeValue(forKey: urlString) else {
                return
            }

            DispatchQueue.main.async {
                for handler in handlers {
                    handler.errorCompletion(handler.messageId)
                }
            }
        }
    }

    // MARK: - Status Checking

    /// Check if an image load is in progress for a URL
    func isImageLoadInProgress(for url: String) -> Bool {
        var result = false
        queue.sync {
            result = inProgressImageLoads[url] != nil
        }
        return result
    }

    /// Check if a video load is in progress for a URL
    func isVideoLoadInProgress(for url: String) -> Bool {
        var result = false
        queue.sync {
            result = inProgressVideoLoads[url] != nil
        }
        return result
    }

    /// Check if a file load is in progress for a URL
    func isFileLoadInProgress(for url: String) -> Bool {
        var result = false
        queue.sync {
            result = inProgressFileLoads[url] != nil
        }
        return result
    }
}
