//
//  HiveFeature.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

struct HiveFeature {
    let id: String
    let name: String
    let brief: String?
    let userStories: String?
    let requirements: String?
    let architecture: String?
    let workflowStatus: String? // e.g. "IN_PROGRESS", "COMPLETED"
    let createdAt: String?
    let updatedAt: String?
    
    init?(json: JSON) {
        guard let id = json["id"].string,
              let name = json["name"].string else { return nil }
        self.id = id
        self.name = name
        self.brief = json["brief"].string
        self.userStories = json["userStories"].string
        self.requirements = json["requirements"].string
        self.architecture = json["architecture"].string
        self.workflowStatus = json["workflowStatus"].string
        self.createdAt = json["createdAt"].string
        self.updatedAt = json["updatedAt"].string
    }
}
