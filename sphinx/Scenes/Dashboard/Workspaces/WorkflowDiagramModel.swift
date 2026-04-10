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

// MARK: - Ordered pairs container (named struct avoids Swift tuple label erasure in dictionaries)

private struct StepOrderedPairs {
    let attrs: [(String, String)]   // (key, rawJSONValue) in document order, excl. "vars"
    let vars:  [(String, String)]   // (key, rawJSONValue) in document order
}

// MARK: - JSON byte scanner
//
// NSJSONSerialization → [String: Any] destroys key order (NSDictionary is unordered).
// The ONLY reliable approach is to scan raw UTF-8 bytes and capture raw value substrings.
// This gives us both order-preserved keys AND order-preserved nested JSON values.

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

    /// Reads a JSON string value (pos must be at the opening `"`). Returns unescaped content.
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

    /// Captures the raw JSON text of any value (string, number, bool, null, object, array)
    /// including surrounding quotes/braces exactly as it appears in the source bytes.
    mutating func readRawValue() -> String {
        skipWhitespace()
        guard let c = current else { return "" }
        let start = pos
        if c == "\"" {
            // String — walk to closing unescaped quote
            advance()
            while let sc = current {
                if sc == "\\" { advance(); advance() }
                else if sc == "\"" { advance(); break }
                else { advance() }
            }
        } else if c == "{" || c == "[" {
            let open = c; let close: Character = c == "{" ? "}" : "]"
            advance(); var depth = 1
            while let sc = current, depth > 0 {
                if sc == "\"" {
                    advance()
                    while let qc = current {
                        if qc == "\\" { advance(); advance() }
                        else if qc == "\"" { advance(); break }
                        else { advance() }
                    }
                } else {
                    if sc == open { depth += 1 } else if sc == close { depth -= 1 }
                    advance()
                }
            }
        } else {
            // number, bool, null
            while let sc = current, sc != "," && sc != "}" && sc != "]" { advance() }
        }
        return String(chars[start..<pos])
    }

    /// Skips any JSON value without capturing it.
    mutating func skipValue() {
        _ = readRawValue()
    }

    /// Enters an object (consumes `{`). Returns false if not positioned at `{`.
    mutating func enterObject() -> Bool {
        skipWhitespace()
        guard current == "{" else { return false }
        advance(); return true
    }

    /// Enters an array (consumes `[`). Returns false if not positioned at `[`.
    mutating func enterArray() -> Bool {
        skipWhitespace()
        guard current == "[" else { return false }
        advance(); return true
    }

    /// Returns the next key inside an already-entered object, or nil when `}` is reached.
    /// Consumes the key and the `:` separator; pos is left at the value start.
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

    /// Non-destructively returns ordered (key, rawValue) pairs for the object at current pos.
    /// Saves and restores pos — caller can still consume the object normally.
    mutating func peekObjectPairs() -> [(String, String)] {
        let saved = pos
        var pairs: [(String, String)] = []
        guard enterObject() else { pos = saved; return [] }
        while let key = nextKey() {
            let raw = readRawValue()
            pairs.append((key, raw))
        }
        pos = saved
        return pairs
    }

    // MARK: - Main extraction

    /// Scans the full document and returns, for each step id:
    ///   - ordered (key, rawValue) pairs for `attributes` (excluding "vars")
    ///   - ordered (key, rawValue) pairs for `attributes.vars`
    mutating func extractOrderedPairs() -> [String: StepOrderedPairs] {
        var result: [String: StepOrderedPairs] = [:]
        guard enterObject() else { return result }

        // Navigate to "transitions"
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

            var stepId:   String?                = nil
            var attrPairs: [(String, String)]    = []
            var varPairs:  [(String, String)]    = []

            stepLoop: while let key = nextKey() {
                switch key {
                case "id":
                    stepId = readString()
                case "attributes":
                    // Peek to get all attribute pairs (including vars) in order
                    let allPairs = peekObjectPairs()
                    attrPairs = allPairs.filter { $0.0 != "vars" }

                    // Now consume, diving into vars for ordered var pairs
                    if !enterObject() { skipValue(); continue stepLoop }
                    while let attrKey = nextKey() {
                        if attrKey == "vars" {
                            varPairs = peekObjectPairs()
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
                result[id] = StepOrderedPairs(attrs: attrPairs, vars: varPairs)
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
    let rawJSON: [String: Any]  // full step object for value lookup (not display order)

    /// Ordered (name, rawJSON) pairs for `attributes` (excl. "vars") — display order preserved
    let orderedAttributes: [(String, String)]
    /// Ordered (name, rawJSON) pairs for `attributes.vars` — display order preserved
    let orderedVars: [(String, String)]

    var nodeType: WorkflowNodeType {
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

    static func parse(from workflowJson: String) -> WorkflowDiagramData? {
        guard var rawData = workflowJson.data(using: .utf8) else { return nil }

        // Unwrap potential double-encoding
        while let str = try? JSONSerialization.jsonObject(with: rawData) as? String,
              let inner = str.data(using: .utf8) {
            rawData = inner
        }

        // Extract ordered key+rawValue pairs directly from bytes (order preserved)
        var scanner = JSONScanner(rawData)
        let orderedPairMap = scanner.extractOrderedPairs()

        // Parse values via JSONSerialization (order irrelevant here — only used for non-display fields)
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
            let entry    = orderedPairMap[stepId]

            let step = WorkflowStep(
                id:                 stepId,
                uniqueId:           t["unique_id"]    as? String,
                displayId:          t["display_id"]   as? String,
                displayName:        t["display_name"] as? String,
                name:               (t["name"] as? String) ?? "",
                positionX:          CGFloat((position?["x"] as? Double) ?? 0),
                positionY:          CGFloat((position?["y"] as? Double) ?? 0),
                skillType:          skill?["type"]        as? String,
                stepState:          status?["step_state"] as? String,
                rawJSON:            t,
                orderedAttributes:  entry.map { $0.attrs } ?? [],
                orderedVars:        entry.map { $0.vars  } ?? []
            )
            steps[stepId] = step
        }

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
