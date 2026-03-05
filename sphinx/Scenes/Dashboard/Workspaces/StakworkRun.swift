//
//  StakworkRun.swift
//  sphinx
//
//  Created on 2026-03-05.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct StakworkRun {
    let id: String
    let type: String
    let status: String
    let featureId: String?

    init?(json: JSON) {
        guard let id = json["id"].string,
              let type = json["type"].string,
              let status = json["status"].string else { return nil }
        self.id = id
        self.type = type
        self.status = status
        self.featureId = json["featureId"].string
    }
}
