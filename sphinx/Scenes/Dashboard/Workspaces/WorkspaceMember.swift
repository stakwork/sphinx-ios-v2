//
//  WorkspaceMember.swift
//  sphinx
//
//  Created on 2025-03-18.
//  Copyright © 2025 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct WorkspaceMember {
    let id: String
    let userId: String
    let role: String
    let joinedAt: String?
    let lightningPubkey: String?   // from json["user"]["lightningPubkey"]

    init?(json: JSON) {
        guard let id = json["id"].string,
              let userId = json["userId"].string else { return nil }
        self.id = id
        self.userId = userId
        self.role = json["role"].string ?? ""
        self.joinedAt = json["joinedAt"].string
        self.lightningPubkey = json["user"]["lightningPubkey"].string
    }
}
