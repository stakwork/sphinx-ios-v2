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
        
        let audioCallback: (() -> ()) = {
            callback(room + "?startAudioOnly=true")
        }
        
        let videoCallback: (() -> ()) = {
            callback(room)
        }
        
        AlertHelper.showOptionsPopup(
            title: "create.call".localized,
            message: "select.call.mode".localized,
            options: ["audio".localized, "video.or.audio".localized],
            callbacks: [audioCallback, videoCallback],
            sourceView: button
        )
    }
    
}
