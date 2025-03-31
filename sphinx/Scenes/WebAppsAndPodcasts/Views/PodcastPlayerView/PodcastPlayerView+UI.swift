//
//  PodcastPlayerView+UI.swift
//  sphinx
//
//  Created by Tomas Timinskas on 16/01/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import UIKit
import AVFoundation

extension PodcastPlayerView {
    func showInfo() {
        if let imageURL = podcast.getImageURL() {
            loadImage(imageURL: imageURL)
        }

        episodeLabel.text = podcast.getCurrentEpisode()?.title ?? ""
        
        loadTime()
        loadMessages()
    }
    
    func loadTime() {
        let episode = podcast.getCurrentEpisode()
        
        if let duration = episode?.duration {
            setProgress(
                duration: duration,
                currentTime: episode?.currentTime ?? 0
            )
        } else if let url = episode?.getAudioUrl() {
            audioLoading = true
            
            setProgress(
                duration: 0,
                currentTime: 0
            )
            
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVAsset(url: url)
                asset.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: {
                    let duration = Int(Double(asset.duration.value) / Double(asset.duration.timescale))
                    episode?.duration = duration
                    
                    DispatchQueue.main.async {
                        self.setProgress(
                            duration: duration,
                            currentTime: episode?.currentTime ?? 0
                        )
                        self.audioLoading = false
                    }
                })
            }
        }
    }
    
    func loadImage(imageURL: URL?) {
        guard let imageURL = imageURL else {
            self.episodeImageView.image = UIImage(named: "podcastPlaceholder")!
            return
        }
        
        MediaLoader.asyncLoadImage(imageView: episodeImageView, nsUrl: imageURL, placeHolderImage: nil, completion: { img in
            self.episodeImageView.image = img
        }, errorCompletion: { _ in
            self.episodeImageView.image = UIImage(named: "podcastPlaceholder")!
        })
    }
    
    func loadMessages() {
        guard let chat = chat else { return }
        
        if livePodcastDataSource == nil {
            livePodcastDataSource = PodcastLiveDataSource(tableView: liveTableView, chat: chat)
        }
        
        let episodeId = podcast.getCurrentEpisode()?.itemID ?? ""
        
        if (episodeId != livePodcastDataSource?.episodeId) {
            
            livePodcastDataSource?.episodeId = episodeId
            
            let messages = TransactionMessage.getLiveMessagesFor(chat: chat, episodeId: episodeId)
            
            liveMessages = [:]
            
            for m in messages {
                addToLiveMessages(message: m)
            }
            
            livePodcastDataSource?.resetData()
        }
    }
    
    func configureControls(
        playing: Bool? = nil
    ) {
        let isPlaying = playing ?? podcastPlayerController.isPlaying(podcastId: podcast.feedID)
        
        UIView.performWithoutAnimation {
            self.playPauseButton.setTitle(isPlaying ? "pause" : "play_arrow", for: .normal)
            self.speedButton.setTitle(self.podcast.playerSpeed.speedDescription + "x", for: .normal)
            
            self.playPauseButton.layoutIfNeeded()
            self.speedButton.layoutIfNeeded()
        }
    }
    
    func setProgress(
        duration: Int,
        currentTime: Int
    ) {
        if skipAdvertIfNeeded(duration: duration, currentTime: currentTime) {
            return
        }
        
        let currentTimeString = currentTime.getPodcastTimeString()
        
        currentTimeLabel.text = currentTimeString
        durationLabel.text = duration.getPodcastTimeString()
        
        let progress = (Double(currentTime) * 100 / Double(duration))/100
        let durationLineWidth = UIScreen.main.bounds.width - 64
        var progressWidth = durationLineWidth * CGFloat(progress)
        
        if !progressWidth.isFinite || progressWidth < 0 {
            progressWidth = 0
        }
        
        progressLineWidth.constant = progressWidth
        progressLine.layoutIfNeeded()
        
        addChaptersDots(duration: duration)
    }
    
    func addChaptersDots(
        duration: Int
    ) {
        guard let episode = podcast.getCurrentEpisode() else {
            return
        }
        
        if chapterInfoEpisodeId != episode.itemID {
            for view in chaptersContainer.subviews {
                view.removeFromSuperview()
            }
        }
        
        chapterInfoEpisodeId = episode.itemID
        
        if chaptersContainer.subviews.count == (episode.chapters ?? []).count {
            return
        }
        
        let chapters = episode.chapters ?? []
        
        for chapter in chapters {
            guard let chapterTime = chapter.timestamp.timeStringToSeconds() else {
                continue
            }
            let progress = (Double(chapterTime) * 100 / Double(duration))/100
            let durationLineWidth = UIScreen.main.bounds.width - 64
            let progressWidth = durationLineWidth * CGFloat(progress)
            
            let dotSize: CGFloat = 10
            let dotHalfSize: CGFloat = 5
            let containerHeight: CGFloat = 28
            let chapterDot = UIView(frame: CGRect(x: progressWidth - dotHalfSize, y: (containerHeight / 2) - dotHalfSize, width: dotSize, height: dotSize))
            chapterDot.backgroundColor = chapter.isAd ? UIColor.Sphinx.SecondaryText : UIColor.white
            chapterDot.layer.cornerRadius = dotHalfSize
            chaptersContainer.addSubview(chapterDot)
        }
    }
    
    func skipAdvertIfNeeded(
        duration: Int,
        currentTime: Int
    ) -> Bool {
        if !podcast.skipAds {
            return false
        }
        
        guard let episode = podcast.getCurrentEpisode() else {
            return false
        }
        
        if skippingAdvert {
            return true
        }
        
        let adTimestamps: [(Int, Int)] = episode.getAdTimestamps()
        let addTimestampStarts = adTimestamps.map({ $0.0 })
        
        if addTimestampStarts.contains(currentTime + 2) {
            advertLabel.text = "Ad detected"
            advertContainer.isHidden = false
        } else if addTimestampStarts.contains(currentTime) {
            if let currentAddTimestamps = adTimestamps.first(where: { $0.0 == currentTime }) {
                skippingAdvert = true
                advertLabel.text = "Skipping Ad"
                advertContainer.isHidden = false

                let newTime = currentAddTimestamps.1
                
                let progress = (Double(newTime) * 100 / Double(duration))/100
                let durationLineWidth = UIScreen.main.bounds.width - 64
                var progressWidth = durationLineWidth * CGFloat(progress)
                
                if !progressWidth.isFinite || progressWidth < 0 {
                    progressWidth = 0
                }
                
                progressLineWidth.constant = progressWidth
                
                togglePlayState()
                
                UIView.animate(withDuration: 1.0, animations: {
                    self.progressLine.superview?.layoutIfNeeded()
                }, completion: { _ in
                    guard let podcastData = self.podcast.getPodcastData(
                        currentTime: newTime
                    ) else {
                        return
                    }
                    
                    self.setProgress(
                        duration: podcastData.duration ?? 0,
                        currentTime: newTime
                    )
                    
                    self.podcastPlayerController.submitAction(
                        UserAction.Seek(podcastData)
                    )
                    
                    self.togglePlayState()
                    self.skippingAdvert = false
                    self.hideAdvertLabel()
                })
                return true
            } else {
                advertContainer.isHidden = true
                return false
            }
        }
        return false
    }
    
    func hideAdvertLabel() {
        DelayPerformedHelper.performAfterDelay(seconds: 1.0, completion: {
            self.advertContainer.isHidden = true
        })
    }
    
    func addMessagesFor(ts: Int) {
        if !podcastPlayerController.isPlaying(podcastId: podcast.feedID) {
            return
        }
        
        if let liveM = liveMessages[ts] {
            livePodcastDataSource?.insert(messages: liveM)
        }
    }
}
