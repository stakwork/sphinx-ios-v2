//
//  HiveChatMessage.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct HiveChatMessage {
    let id: String
    let message: String
    let role: String // "user" or "assistant"
    let timestamp: String?
    
    init?(json: JSON) {
        guard let id = json["id"].string,
              let message = json["message"].string,
              let role = json["role"].string else { return nil }
        self.id = id
        self.message = message
        self.role = role
        self.timestamp = json["timestamp"].string
    }
}
