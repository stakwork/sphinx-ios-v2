//
//  PodcastPlayerController+AudioPlayer.swift
//  sphinx
//
//  Created by Tomas Timinskas on 13/01/2023.
//  Copyright © 2023 sphinx. All rights reserved.
//

import Foundation
import AVKit

@MainActor
extension PodcastPlayerController {
    func setAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch _ {}
        
        let session = AVAudioSession.sharedInstance()
        
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleInterruption(notification:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
    }
    
    @objc func handleInterruption(notification: NSNotification) {
        if notification.name != AVAudioSession.interruptionNotification ||
            notification.userInfo == nil {
            
            return
        }
        let info = notification.userInfo!

        // Safe optional cast — a force-cast here crashes on any absent or
        // malformed AVAudioSessionInterruptionTypeKey value, regardless of call state.
        guard let rawValue = (info[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: rawValue) else {
            print("PodcastPlayerController: handleInterruption — missing or malformed interruption type key; ignoring")
            return
        }

        print("PodcastPlayerController: handleInterruption — type=\(interruptionType.rawValue)")

        switch interruptionType {
        case .began:
            if let podcastData = self.podcastData {
                self.pause(podcastData)
            }
        default:
            break
        }
    }
}
