//
//  StakworkWorkflowData.swift
//  sphinx
//
//  Created on 2026-03-06.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct StakworkWorkflowTransition {
    let id: String
    let title: String
    let status: String
    let uniqueId: String?
    let displayName: String?
    let stepType: String?

    init?(json: JSON) {
        guard let id = json["id"].string,
              let title = json["title"].string,
              let status = json["status"].string else { return nil }
        self.id = id
        self.title = title
        self.status = status
        self.uniqueId = json["unique_id"].string
        self.displayName = json["display_name"].string
        self.stepType = json["type"].string
    }
}

struct StakworkWorkflowData {
    let transitions: [StakworkWorkflowTransition]
    let overallStatus: String

    var inProgressTitle: String? {
        return transitions.first(where: { $0.status == "in_progress" })?.title
    }

    init?(json: JSON) {
        self.overallStatus = json["status"].string ?? ""
        self.transitions = json["workflowData"]["transitions"].arrayValue.compactMap {
            StakworkWorkflowTransition(json: $0)
        }
    }
}
