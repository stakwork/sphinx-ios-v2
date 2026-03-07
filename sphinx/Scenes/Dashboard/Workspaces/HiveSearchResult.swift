//
//  HiveSearchResult.swift
//  sphinx
//
//  Created on 2026-03-07.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import SwiftyJSON

struct HiveSearchResultItem {
    let id: String
    let type: String        // "feature" | "task"
    let title: String
    let featureTitle: String?   // metadata.featureTitle (tasks only)
    let status: String?

    init?(json: JSON) {
        guard let id = json["id"].string,
              let type = json["type"].string,
              let title = json["title"].string else { return nil }
        self.id = id
        self.type = type
        self.title = title
        self.status = json["metadata"]["status"].string
        self.featureTitle = json["metadata"]["featureTitle"].string
    }
}

struct HiveSearchResults {
    let total: Int
    let features: [HiveSearchResultItem]
    let tasks: [HiveSearchResultItem]

    init(json: JSON) {
        self.total = json["data"]["total"].int ?? 0
        self.features = json["data"]["features"].arrayValue.compactMap { HiveSearchResultItem(json: $0) }
        self.tasks = json["data"]["tasks"].arrayValue.compactMap { HiveSearchResultItem(json: $0) }
        // phases intentionally ignored
    }
}
