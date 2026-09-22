//
//  CachingPlayerItem.swift
//  sphinx
//
//  Created by Tomas Timinskas on 13/02/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation
import AVFoundation

fileprivate extension URL {
    
    func withScheme(_ scheme: String) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = scheme
        return components?.url
    }
    
}

@objc protocol CachingPlayerItemDelegate {
    
    /// Is called when the media file is fully downloaded.
    @objc optional func playerItem(_ playerItem: CachingPlayerItem, didFinishDownloadingData data: Data)
    
    /// Is called every time a new portion of data is received.
    @objc optional func playerItem(_ playerItem: CachingPlayerItem, didDownloadBytesSoFar bytesDownloaded: Int, outOf bytesExpected: Int)
    
    /// Is called after initial prebuffering is finished, means
    /// we are ready to play.
    @objc optional func playerItemReadyToPlay(_ playerItem: CachingPlayerItem)
    
    /// Is called when the data being downloaded did not arrive in time to
    /// continue playback.
    @objc optional func playerItemPlaybackStalled(_ playerItem: CachingPlayerItem)
    
    /// Is called on downloading error.
    @objc optional func playerItem(_ playerItem: CachingPlayerItem, downloadingFailedWith error: Error)
    
}

open class CachingPlayerItem: AVPlayerItem {
    
    // URLSession and resource-loader callbacks are serialized on DispatchQueue.main.
    class ResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
        
        static let resourceLoadErrorDomain = "com.sphinx.CachingPlayerItem"
        static let resourceLoadErrorCode = 1
        
        static func resourceLoadError(_ message: String) -> NSError {
            NSError(
                domain: resourceLoadErrorDomain,
                code: resourceLoadErrorCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        
        var playingFromData = false
        var mimeType: String? // is required when playing from Data
        var session: URLSession?
        var mediaData: Data?
        var response: URLResponse?
        var pendingRequests = Set<AVAssetResourceLoadingRequest>()
        weak var owner: CachingPlayerItem?
        
        func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
            
            if playingFromData {
                
                // Nothing to load.
                
            } else if session == nil {
                
                // If we're playing from a url, we need to download the file.
                // We start loading the file on first request only.
                guard canStartDataRequest(), let initialUrl = owner?.url else {
                    let error = Self.resourceLoadError("media URL is missing")
                    print("[CachingPlayerItem] resource load failed: media URL is missing")
                    loadingRequest.finishLoading(with: error)
                    return true
                }

                startDataRequest(with: initialUrl)
            }
            
            pendingRequests.insert(loadingRequest)
            processPendingRequests()
            return true
            
        }
        
        func canStartDataRequest() -> Bool {
            owner?.url != nil
        }
        
        func startDataRequest(with url: URL) {
            let configuration = URLSessionConfiguration.default
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
            session?.dataTask(with: url).resume()
        }
        
        func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
            pendingRequests.remove(loadingRequest)
        }
        
        // MARK: URLSession delegate
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let progress = appendSessionData(data, bytesExpected: Int(dataTask.countOfBytesExpectedToReceive)) else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                if let owner = self?.owner {
                    owner.delegate?.playerItem?(owner, didDownloadBytesSoFar: progress.bytesDownloaded, outOf: progress.bytesExpected)
                }
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            completionHandler(Foundation.URLSession.ResponseDisposition.allow)
            mediaData = Data()
            self.response = response
            processPendingRequests()
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            completeSession(error: error)
        }
        
        // MARK: - Testable nil-safe helpers
        
        @discardableResult
        func appendSessionData(_ data: Data, bytesExpected: Int) -> (bytesDownloaded: Int, bytesExpected: Int)? {
            guard mediaData != nil else {
                print("[CachingPlayerItem] resource load failed: data arrived before response (mediaData is nil)")
                return nil
            }
            // Mutate through the optional directly (`mediaData?.append`), not via a
            // separate `var` copy — binding the value into a local var keeps a second
            // reference alive during the append, which defeats Data's copy-on-write
            // and turns every chunk into a full-buffer copy (O(n) per chunk instead
            // of amortized O(1)) for the whole download.
            mediaData?.append(data)
            processPendingRequests()
            return (bytesDownloaded: mediaData?.count ?? 0, bytesExpected: bytesExpected)
        }
        
        func completeSession(error: Error?) {
            if let error {
                print("[CachingPlayerItem] resource load failed: \(error.localizedDescription)")
                failPendingRequests(with: error)
                notifyDownloadingFailed(with: error)
                return
            }
            
            guard let mediaData else {
                let loadError = Self.resourceLoadError("media data is nil on session completion")
                print("[CachingPlayerItem] resource load failed: media data is nil on session completion")
                failPendingRequests(with: loadError)
                notifyDownloadingFailed(with: loadError)
                return
            }
            
            processPendingRequests()
            DispatchQueue.main.async { [weak self] in
                if let owner = self?.owner {
                    owner.delegate?.playerItem?(owner, didFinishDownloadingData: mediaData)
                }
            }
        }
        
        func failPendingRequests(with error: Error) {
            for request in pendingRequests {
                request.finishLoading(with: error)
            }
            pendingRequests.removeAll()
        }
        
        private func notifyDownloadingFailed(with error: Error) {
            DispatchQueue.main.async { [weak self] in
                if let owner = self?.owner {
                    owner.delegate?.playerItem?(owner, downloadingFailedWith: error)
                }
            }
        }
        
        // MARK: -
        
        func processPendingRequests() {
            
            var requestsFulfilled = Set<AVAssetResourceLoadingRequest>()
            
            for request in pendingRequests {
                fillInContentInformationRequest(request.contentInformationRequest)
                
                if let dataRequest = request.dataRequest {
                    if haveEnoughDataToFulfillRequest(dataRequest) {
                        request.finishLoading()
                        requestsFulfilled.insert(request)
                    }
                } else if canFillContentInformation {
                    // Content-information-only request from AVPlayer.
                    request.finishLoading()
                    requestsFulfilled.insert(request)
                }
                // Otherwise leave the request pending until content info is available.
            }
            
            for request in requestsFulfilled {
                pendingRequests.remove(request)
            }

        }
        
        var canFillContentInformation: Bool {
            if response != nil { return true }
            if playingFromData && mediaData != nil { return true }
            return false
        }
        
        func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?) {
            
            // if we play from Data we make no url requests, therefore we have no responses, so we need to fill in contentInformationRequest manually
            if playingFromData {
                guard let mediaData else {
                    print("[CachingPlayerItem] resource load failed: mediaData is nil while playing from data")
                    return
                }
                contentInformationRequest?.contentType = self.mimeType
                contentInformationRequest?.contentLength = Int64(mediaData.count)
                contentInformationRequest?.isByteRangeAccessSupported = true
                return
            }
            
            guard let responseUnwrapped = response else {
                // have no response from the server yet
                return
            }
            
            contentInformationRequest?.contentType = responseUnwrapped.mimeType
            contentInformationRequest?.contentLength = responseUnwrapped.expectedContentLength
            contentInformationRequest?.isByteRangeAccessSupported = true
            
        }
        
        func haveEnoughDataToFulfillRequest(_ dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
            
            let requestedOffset = Int(dataRequest.requestedOffset)
            let requestedLength = dataRequest.requestedLength
            let currentOffset = Int(dataRequest.currentOffset)
            
            guard let songDataUnwrapped = mediaData,
                songDataUnwrapped.count > currentOffset else {
                // Don't have any data at all for this request.
                return false
            }
            
            let bytesToRespond = min(songDataUnwrapped.count - currentOffset, requestedLength)
            let dataToRespond = songDataUnwrapped.subdata(in: Range(uncheckedBounds: (currentOffset, currentOffset + bytesToRespond)))
            dataRequest.respond(with: dataToRespond)
            
            return songDataUnwrapped.count >= requestedLength + requestedOffset
            
        }
        
        deinit {
            session?.invalidateAndCancel()
        }
        
    }
    
    fileprivate let resourceLoaderDelegate = ResourceLoaderDelegate()
    fileprivate let url: URL
    fileprivate let initialScheme: String?
    fileprivate var customFileExtension: String?
    
    weak var delegate: CachingPlayerItemDelegate?
    
    open func download() {
        if resourceLoaderDelegate.session == nil {
            resourceLoaderDelegate.startDataRequest(with: url)
        }
    }
    
    private let cachingPlayerItemScheme = "cachingPlayerItemScheme"
    
    /// Override/append custom file extension to URL path.
    /// This is required for the player to work correctly with the intended file type.
    init?(url: URL, customFileExtension: String?) {
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme,
            var urlWithCustomScheme = url.withScheme(cachingPlayerItemScheme) else {
            print("[CachingPlayerItem] resource load failed: Urls without a scheme are not supported")
            return nil
        }
        
        self.url = url
        self.initialScheme = scheme
        
        if let ext = customFileExtension {
            urlWithCustomScheme.deletePathExtension()
            urlWithCustomScheme.appendPathExtension(ext)
            self.customFileExtension = ext
        }
        
        let asset = AVURLAsset(url: urlWithCustomScheme)
        asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: DispatchQueue.main)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        
        resourceLoaderDelegate.owner = self
        
        addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStalledHandler), name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: self)
        
    }
    
    /// Is used for playing from Data.
    init?(data: Data, mimeType: String, fileExtension: String) {
        
        guard let fakeUrl = URL(string: cachingPlayerItemScheme + "://whatever/file.\(fileExtension)") else {
            print("[CachingPlayerItem] resource load failed: internal inconsistency")
            return nil
        }
        
        self.url = fakeUrl
        self.initialScheme = nil
        
        resourceLoaderDelegate.mediaData = data
        resourceLoaderDelegate.playingFromData = true
        resourceLoaderDelegate.mimeType = mimeType
        
        let asset = AVURLAsset(url: fakeUrl)
        asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: DispatchQueue.main)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        resourceLoaderDelegate.owner = self
        
        addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStalledHandler), name:NSNotification.Name.AVPlayerItemPlaybackStalled, object: self)
        
    }
    
    // MARK: KVO
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.playerItemReadyToPlay?(self)
        }
    }
    
    // MARK: Notification hanlers
    
    @objc func playbackStalledHandler() {
        delegate?.playerItemPlaybackStalled?(self)
    }

    // MARK: -
    
    override init(asset: AVAsset, automaticallyLoadedAssetKeys: [String]?) {
        self.url = URL(fileURLWithPath: "")
        self.initialScheme = nil
        super.init(asset: asset, automaticallyLoadedAssetKeys: automaticallyLoadedAssetKeys)
        
        addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStalledHandler), name:NSNotification.Name.AVPlayerItemPlaybackStalled, object: self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removeObserver(self, forKeyPath: "status")
        resourceLoaderDelegate.session?.invalidateAndCancel()
    }
    
}
