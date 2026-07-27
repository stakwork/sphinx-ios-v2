//
//  PodcastPlayerController+Payments.swift
//  sphinx
//
//  Created by Tomas Timinskas on 18/01/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation

@MainActor
extension PodcastPlayerController {
    func resetPlayedSeconds() {
        self.playedSeconds = 0
    }
    
    @objc func updatePlayedTime() {
        playedSeconds = playedSeconds + 1
        
        if playedSeconds > 0 && playedSeconds % kSecondsBeforePMT == 0 {
            processPayment()
        }
    }
    
    func processPayment(amount: Int? = nil) {
        guard let podcast = podcast, let podcastData = podcastData else {
            return
        }
        
        podcastPaymentsHelper.processPaymentsFor(
            podcastFeed: podcast,
            boostAmount: amount,
            itemId: podcastData.episodeId,
            currentTime: podcastData.currentTime ?? 0,
            clipSenderPubKey: podcastData.clipInfo?.clipSenderPubKey,
            uuid: podcastData.clipInfo?.messageUUID
        )
    }
}
