//
//  WorkspacePod.swift
//  sphinx
//
//  Created on 2025-03-25.
//  Copyright © 2025 sphinx. All rights reserved.
//

import UIKit
import SwiftyJSON

struct WorkspacePod {

    // MARK: - Nested Types

    struct ResourceUsage {
        let available: Bool
        let requestsCPU: String
        let requestsMemory: String
        let usageCPU: String
        let usageMemory: String

        init(json: JSON) {
            self.available = json["available"].bool ?? true
            // API returns nested objects: resource_usage.requests.cpu / resource_usage.usage.cpu
            self.requestsCPU    = json["requests"]["cpu"].string    ?? "0"
            self.requestsMemory = json["requests"]["memory"].string ?? "0"
            self.usageCPU       = json["usage"]["cpu"].string       ?? "0"
            self.usageMemory    = json["usage"]["memory"].string    ?? "0"
        }
    }

    // MARK: - Properties

    let id: String
    let subdomain: String
    let state: String
    let internalState: String
    let usageStatus: String
    let userInfo: String?
    let markedAt: String?
    let url: String?
    let password: String?
    let repoName: String?
    let primaryRepo: String?
    let repositories: [String]
    let branches: [String]
    let created: String?
    let resourceUsage: ResourceUsage

    // MARK: - Computed: CPU

    var cpuPercentage: Double {
        guard resourceUsage.available else { return 0 }
        let requests = parseLeadingNumber(resourceUsage.requestsCPU)
        let usage    = parseLeadingNumber(resourceUsage.usageCPU)
        guard requests > 0 else { return 0 }
        return min((usage / requests) * 100, 100)
    }

    // MARK: - Computed: Memory

    var memoryPercentage: Double {
        guard resourceUsage.available else { return 0 }
        let requests = parseLeadingNumber(resourceUsage.requestsMemory)
        let usage    = parseLeadingNumber(resourceUsage.usageMemory)
        guard requests > 0 else { return 0 }
        return min((usage / requests) * 100, 100)
    }

    /// Mirrors JS parseFloat(): strips any trailing unit suffix and returns the numeric prefix.
    /// e.g. "500m" → 500, "1Gi" → 1, "256Mi" → 256, "0.5" → 0.5
    private func parseLeadingNumber(_ raw: String) -> Double {
        let numeric = raw.prefix(while: { $0.isNumber || $0 == "." })
        return Double(numeric) ?? 0
    }

    // MARK: - Computed: Sort Order (green=0, yellow=1, grey/other=2, red=3)

    var sortOrder: Int {
        switch state {
        case "running" where usageStatus == "used":   return 0  // green
        case "pending":                                return 1  // yellow
        case "running":                                return 2  // grey (unused)
        case "failed":                                 return 3  // red
        default:                                       return 2
        }
    }

    // MARK: - Computed: Status Dot Color

    var statusDotColor: UIColor {
        switch state {
        case "pending":
            return UIColor.Sphinx.SphinxOrange
        case "failed":
            return UIColor.Sphinx.PrimaryRed
        case "running":
            return usageStatus == "used"
                ? UIColor.Sphinx.PrimaryGreen
                : UIColor.Sphinx.SecondaryText
        default:
            return UIColor.Sphinx.SecondaryText
        }
    }

    // MARK: - Computed: Subtitle

    var subtitle: String? {
        if state == "pending" {
            return "Preparing your environment…"
        }
        if state == "running", usageStatus == "used", let info = userInfo, !info.isEmpty {
            return info
        }
        return nil
    }

    // MARK: - Init

    init?(json: JSON) {
        guard let id        = json["id"].string,
              let subdomain = json["subdomain"].string,
              let state     = json["state"].string else {
            return nil
        }

        self.id            = id
        self.subdomain     = subdomain
        self.state         = state
        self.internalState = json["internalState"].string ?? json["internal_state"].string ?? ""
        self.usageStatus   = json["usageStatus"].string   ?? json["usage_status"].string   ?? ""
        self.userInfo      = json["userInfo"].string      ?? json["user_info"].string
        self.markedAt      = json["markedAt"].string      ?? json["marked_at"].string
        self.url           = json["url"].string
        self.password      = json["password"].string
        self.repoName      = json["repoName"].string      ?? json["repo_name"].string
        self.primaryRepo   = json["primaryRepo"].string   ?? json["primary_repo"].string
        self.created       = json["created"].string

        self.repositories  = json["repositories"].arrayValue.compactMap { $0.string }
        self.branches      = json["branches"].arrayValue.compactMap { $0.string }

        let usageJSON = json["resource_usage"].exists()
            ? json["resource_usage"]
            : json["resourceUsage"]
        self.resourceUsage = ResourceUsage(json: usageJSON)
    }
}
