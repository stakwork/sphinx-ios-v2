//
//  VideoCallHelper.swift
//  sphinx
//
//  Created by Tomas Timinskas on 10/07/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

class VideoCallHelper {
    
    public enum CallMode: Int {
        case Audio
        case All
    }
    
    public static func getCallMode(link: String) -> CallMode {
        var mode = CallMode.All
        
        if link.contains("startAudioOnly") {
            mode = CallMode.Audio
        }
        
        return mode
    }
    
    public static func extractSwarmName(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else { return nil }
        let components = host.split(separator: ".").map(String.init)
        guard components.count > 1 else { return nil }
        return components[0]
    }

    /// Shows the audio / video mode popup for an already-built room link.
    @MainActor
    public static func showCallModePopup(
        link: String,
        button: UIButton,
        callback: @escaping (String) -> ()
    ) {
        let audioCallback: (() -> ()) = {
            if link.contains("?") {
                callback(link + "&startAudioOnly=true")
            } else {
                callback(link + "?startAudioOnly=true")
            }
        }
        let videoCallback: (() -> ()) = {
            callback(link)
        }
        AlertHelper.showOptionsPopup(
            title: "create.call".localized,
            message: "select.call.mode".localized,
            options: ["audio".localized, "video.or.audio".localized],
            callbacks: [audioCallback, videoCallback],
            sourceView: button
        )
    }

    @MainActor
    public static func createCallMessage(
        button: UIButton,
        secondBrainUrl: String? = nil,
        appUrl: String? = nil,
        callback: @escaping (String) -> ()
    ) {
        let time = Date.timeIntervalSinceReferenceDate
        var graphUrl: String? = nil
        
        if let secondBrainUrl = secondBrainUrl, !secondBrainUrl.isEmpty {
            if let url = URL(string: secondBrainUrl), let host = url.host {
                graphUrl = host
            } else {
                graphUrl = secondBrainUrl
            }
        } else if let appUrl = appUrl, !appUrl.isEmpty {
            if let url = URL(string: appUrl), let host = url.host {
                graphUrl = host
            } else {
                graphUrl = appUrl
            }
        }
        
        var room = "\(API.sharedInstance.kVideoCallServer)/rooms\(TransactionMessage.kCallRoomName).\(time)"
        
        if let graphUrl = graphUrl {
            room = "\(API.sharedInstance.kVideoCallServer)/rooms\(TransactionMessage.kCallRoomName).-\(graphUrl)-.\(time)"
        }

        showCallModePopup(link: room, button: button, callback: callback)
    }
    
}
