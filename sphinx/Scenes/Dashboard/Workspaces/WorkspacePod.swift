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
            self.available      = json["available"].bool ?? true
            self.requestsCPU    = json["requests_cpu"].string    ?? json["requestsCPU"].string    ?? "0"
            self.requestsMemory = json["requests_memory"].string ?? json["requestsMemory"].string ?? "0"
            self.usageCPU       = json["usage_cpu"].string       ?? json["usageCPU"].string       ?? "0"
            self.usageMemory    = json["usage_memory"].string    ?? json["usageMemory"].string    ?? "0"
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
        let requests = parseMilliCores(resourceUsage.requestsCPU)
        let usage    = parseMilliCores(resourceUsage.usageCPU)
        guard requests > 0 else { return 0 }
        return min((usage / requests) * 100, 100)
    }

    /// Normalises a CPU value to milli-cores regardless of whether
    /// the raw string uses the "m" suffix (milli-cores) or bare number (cores).
    private func parseMilliCores(_ raw: String) -> Double {
        if raw.hasSuffix("m") {
            return Double(raw.dropLast()) ?? 0
        }
        return (Double(raw) ?? 0) * 1000   // cores → milli-cores
    }

    // MARK: - Computed: Memory

    var memoryPercentage: Double {
        guard resourceUsage.available else { return 0 }
        let requests = parseMemoryToBytes(resourceUsage.requestsMemory)
        let usage    = parseMemoryToBytes(resourceUsage.usageMemory)
        guard requests > 0 else { return 0 }
        return min((usage / requests) * 100, 100)
    }

    private func parseMemoryToBytes(_ value: String) -> Double {
        if value.hasSuffix("Gi") {
            return (Double(value.dropLast(2)) ?? 0) * 1_073_741_824
        } else if value.hasSuffix("Mi") {
            return (Double(value.dropLast(2)) ?? 0) * 1_048_576
        } else if value.hasSuffix("Ki") {
            return (Double(value.dropLast(2)) ?? 0) * 1_024
        } else {
            return Double(value) ?? 0
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
