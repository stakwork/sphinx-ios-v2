//
//  WorkflowDiagramModel.swift
//  sphinx
//
//  Data model for the workflow diagram feature.
//

import Foundation
import UIKit

// MARK: - Node Type

enum WorkflowNodeType {
    case automated, human, api, condition, loop
}

// MARK: - Edge

struct WorkflowEdge {
    let fromId: String
    let toId: String
    let label: String?  // branch label e.g. "true" / "false"
}

// MARK: - JSON byte scanner for ordered key extraction
//
// NSJSONSerialization → [String: Any] destroys key order (NSDictionary is unordered).
// JSONDecoder.allKeys on Apple platforms has the same problem (backed by NSJSONSerialization).
// The ONLY reliable approach is to scan the raw UTF-8 bytes character by character.

private struct JSONScanner {
    private let chars: [Character]
    var pos: Int = 0

    init(_ data: Data) {
        chars = Array(String(data: data, encoding: .utf8) ?? "")
    }

    private var current: Character? { pos < chars.count ? chars[pos] : nil }
    private mutating func advance() { if pos < chars.count { pos += 1 } }

    private mutating func skipWhitespace() {
        while let c = current, c.isWhitespace { advance() }
    }

    // Reads a JSON string (pos must be at the opening `"`).
    mutating func readString() -> String {
        skipWhitespace()
        guard current == "\"" else { return "" }
        advance()
        var out = ""
        while let c = current {
            advance()
            if c == "\"" { break }
            if c == "\\" { if let esc = current { out.append(esc); advance() } }
            else { out.append(c) }
        }
        return out
    }

    // Skips any JSON value (string, number, bool, null, object, array).
    mutating func skipValue() {
        skipWhitespace()
        guard let c = current else { return }
        if c == "\"" {
            _ = readString()
        } else if c == "{" || c == "[" {
            let open = c; let close: Character = c == "{" ? "}" : "]"
            advance(); var depth = 1
            while let sc = current, depth > 0 {
                if sc == "\"" { _ = readString() }
                else { if sc == open { depth += 1 } else if sc == close { depth -= 1 }; advance() }
            }
        } else {
            // number, bool, null — ends at structural character
            while let c = current, c != "," && c != "}" && c != "]" { advance() }
        }
    }

    // Enters an object (consumes `{`). Returns false if not positioned at `{`.
    mutating func enterObject() -> Bool {
        skipWhitespace()
        guard current == "{" else { return false }
        advance(); return true
    }

    // Enters an array (consumes `[`). Returns false if not positioned at `[`.
    mutating func enterArray() -> Bool {
        skipWhitespace()
        guard current == "[" else { return false }
        advance(); return true
    }

    // Returns the next key inside an already-entered object, or nil when `}` is reached.
    // Consumes the key string and the `:` separator; pos is left at the value.
    mutating func nextKey() -> String? {
        skipWhitespace()
        while let c = current, c == "," { advance(); skipWhitespace() }
        guard let c = current, c != "}" else { return nil }
        guard c == "\"" else { skipValue(); return nil }
        let key = readString()
        skipWhitespace()
        guard current == ":" else { return nil }
        advance()   // consume ":"
        return key
    }

    // Non-destructively returns the top-level key names of the object at current pos.
    // Saves and restores pos so caller can still consume the object normally.
    mutating func peekObjectKeyNames() -> [String] {
        let saved = pos
        var keys: [String] = []
        guard enterObject() else { pos = saved; return [] }
        while let key = nextKey() { keys.append(key); skipValue() }
        pos = saved     // ← restore — caller will consume the object itself
        return keys
    }

    // Main entry point: scans the entire document and builds
    // stepId → (ordered attribute keys excl. "vars", ordered var keys).
    mutating func extractAttributeKeyMap() -> [String: ([String], [String])] {
        var result: [String: ([String], [String])] = [:]
        guard enterObject() else { return result }

        // Navigate to "transitions" value
        while let key = nextKey() {
            if key == "transitions" { break }
            skipValue()
        }
        guard enterArray() else { return result }

        // Iterate each transition object
        while true {
            skipWhitespace()
            guard let c = current else { break }
            if c == "]" { break }
            if c == "," { advance(); continue }
            guard enterObject() else { skipValue(); continue }

            var stepId:   String?   = nil
            var attrKeys: [String]  = []
            var varKeys:  [String]  = []

            stepLoop: while let key = nextKey() {
                switch key {
                case "id":
                    stepId = readString()
                case "attributes":
                    // First pass (non-destructive): collect attribute key names
                    attrKeys = peekObjectKeyNames().filter { $0 != "vars" }
                    // Second pass (consuming): dig into "vars"
                    if !enterObject() { skipValue(); continue stepLoop }
                    while let attrKey = nextKey() {
                        if attrKey == "vars" {
                            varKeys = peekObjectKeyNames()
                            skipValue()     // consume vars object
                        } else {
                            skipValue()
                        }
                    }
                    if current == "}" { advance() }   // consume closing `}` of attributes
                default:
                    skipValue()
                }
            }
            if current == "}" { advance() }   // consume closing `}` of transition

            if let id = stepId {
                result[id] = (attrKeys, varKeys)
            }
        }
        return result
    }
}

// MARK: - Step

struct WorkflowStep {
    let id: String
    let uniqueId: String?
    let displayId: String?
    let displayName: String?
    let name: String
    let positionX: CGFloat
    let positionY: CGFloat
    let skillType: String?      // "human" | "automated" | "api" | "loop"
    let stepState: String?      // "finished" | "in_progress" | "error" | "skipped"
    let rawJSON: [String: Any]  // full step object for stepData payload

    /// Keys of `rawJSON["attributes"]` in original JSON order (excluding "vars")
    let orderedAttributeKeys: [String]
    /// Keys of `rawJSON["attributes"]["vars"]` in original JSON order
    let orderedVarKeys: [String]

    var nodeType: WorkflowNodeType {
        // Loop: attributes contain both workflow_id and workflow_name
        if let attrs = rawJSON["attributes"] as? [String: Any],
           attrs["workflow_id"] != nil,
           attrs["workflow_name"] != nil {
            return .loop
        }
        if name == "IfCondition" || name == "IfElseCondition" {
            return .condition
        }
        switch skillType {
        case "human": return .human
        case "api":   return .api
        default:      return .automated
        }
    }
}

// MARK: - Diagram Data

struct WorkflowDiagramData {
    let steps: [String: WorkflowStep]
    let edges: [WorkflowEdge]

    /// Parse workflow JSON, handling single and double-encoded JSON strings.
    static func parse(from workflowJson: String) -> WorkflowDiagramData? {
        // Resolve raw bytes (unwrap potential double-encoding)
        guard var rawData = workflowJson.data(using: .utf8) else { return nil }

        // If the top-level value is a JSON string, keep unwrapping until we reach an object
        while let str = try? JSONSerialization.jsonObject(with: rawData) as? String,
              let inner = str.data(using: .utf8) {
            rawData = inner
        }

        // Extract ordered keys by scanning raw bytes — the ONLY approach that preserves JSON key order
        var scanner = JSONScanner(rawData)
        let orderedKeyMap = scanner.extractAttributeKeyMap()   // [stepId: ([attrKeys], [varKeys])]

        // Now parse the full object via JSONSerialization (order doesn't matter for value lookup)
        guard let dict = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
              let transitionsArray = dict["transitions"] as? [[String: Any]] else {
            return nil
        }

        var steps: [String: WorkflowStep] = [:]
        var edges: [WorkflowEdge] = []

        for t in transitionsArray {
            guard let stepId = t["id"] as? String else { continue }

            let position = t["position"] as? [String: Any]
            let skill    = t["skill"]    as? [String: Any]
            let status   = t["status"]   as? [String: Any]

            let keyEntry = orderedKeyMap[stepId]

            let step = WorkflowStep(
                id:                   stepId,
                uniqueId:             t["unique_id"]    as? String,
                displayId:            t["display_id"]   as? String,
                displayName:          t["display_name"] as? String,
                name:                 (t["name"] as? String) ?? "",
                positionX:            CGFloat((position?["x"] as? Double) ?? 0),
                positionY:            CGFloat((position?["y"] as? Double) ?? 0),
                skillType:            skill?["type"]        as? String,
                stepState:            status?["step_state"] as? String,
                rawJSON:              t,
                orderedAttributeKeys: keyEntry?.attrKeys ?? [],
                orderedVarKeys:       keyEntry?.varKeys  ?? []
            )
            steps[stepId] = step
        }

        // Build edges from top-level connections array
        if let connectionsArray = dict["connections"] as? [[String: Any]] {
            for conn in connectionsArray {
                if let source = conn["source"] as? String,
                   let target = conn["target"] as? String {
                    edges.append(WorkflowEdge(fromId: source, toId: target, label: conn["name"] as? String))
                }
            }
        }

        return WorkflowDiagramData(steps: steps, edges: edges)
    }
}
