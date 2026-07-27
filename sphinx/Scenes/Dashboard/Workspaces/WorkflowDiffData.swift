//
//  WorkflowDiffData.swift
//  sphinx
//
//  Created on 2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation

// MARK: - WorkflowDiffData

struct WorkflowDiffData {
    let originalJson: String
    let updatedJson: String
    var hasChanges: Bool { originalJson != updatedJson }
}

// MARK: - DiffLineType / DiffLine

enum DiffLineType {
    case added
    case removed
    case unchanged
}

struct DiffLine {
    let prefix: String
    let content: String
    let type: DiffLineType
}

// MARK: - JSON cleaning

/// Strips cosmetic fields from each transition entry and re-serialises with sorted keys +
/// pretty printing — matching the web client behaviour.
func cleanJsonForDiff(_ jsonString: String) -> String? {
    guard let data = jsonString.data(using: .utf8),
          var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    let cosmetic: Set<String> = ["position", "unique_id", "subskill_id", "skill_icon"]

    if var transitions = obj["transitions"] as? [[String: Any]] {
        transitions = transitions.map { t in
            var cleaned = t
            cosmetic.forEach { cleaned.removeValue(forKey: $0) }
            return cleaned
        }
        obj["transitions"] = transitions
    }

    guard let cleaned = try? JSONSerialization.data(
        withJSONObject: obj,
        options: [.prettyPrinted, .sortedKeys]
    ) else { return nil }

    return String(data: cleaned, encoding: .utf8)
}

// MARK: - LCS-based diff

/// Computes a line-by-line diff of two strings using the Longest Common Subsequence algorithm.
func computeDiff(original: String, updated: String) -> [DiffLine] {
    let oldLines = original.components(separatedBy: "\n")
    let newLines = updated.components(separatedBy: "\n")

    let m = oldLines.count
    let n = newLines.count

    // Build LCS table
    var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
    for i in 1...m {
        for j in 1...n {
            if oldLines[i - 1] == newLines[j - 1] {
                dp[i][j] = dp[i - 1][j - 1] + 1
            } else {
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
            }
        }
    }

    // Backtrack
    var result: [DiffLine] = []
    var i = m, j = n
    while i > 0 || j > 0 {
        if i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1] {
            result.append(DiffLine(prefix: " ", content: oldLines[i - 1], type: .unchanged))
            i -= 1; j -= 1
        } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
            result.append(DiffLine(prefix: "+", content: newLines[j - 1], type: .added))
            j -= 1
        } else {
            result.append(DiffLine(prefix: "-", content: oldLines[i - 1], type: .removed))
            i -= 1
        }
    }

    return result.reversed()
}
