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

// MARK: - Ordered key extraction

/// A `CodingKey` that accepts any string — used to enumerate all keys in JSON order.
private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}

/// Returns the keys of a JSON object in their original document order by decoding
/// with `KeyedDecodingContainer.allKeys`, which preserves insertion order in
/// Apple's `JSONDecoder` implementation.
private func orderedKeys(fromJSONObject jsonObject: [String: Any]) -> [String] {
    guard let data = try? JSONSerialization.data(withJSONObject: jsonObject),
          let decoded = try? JSONDecoder().decode(OrderedKeys.self, from: data) else {
        return Array(jsonObject.keys)
    }
    return decoded.keys
}

private struct OrderedKeys: Decodable {
    let keys: [String]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        keys = container.allKeys.map { $0.stringValue }
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
        // Unwrap potential double-encoding: keep parsing until we get a dictionary
        guard let initialData = workflowJson.data(using: .utf8),
              let initialObj = try? JSONSerialization.jsonObject(with: initialData) else {
            return nil
        }

        var current: Any = initialObj
        while let str = current as? String,
              let data = str.data(using: .utf8),
              let inner = try? JSONSerialization.jsonObject(with: data) {
            current = inner
        }

        guard let dict = current as? [String: Any],
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
            let attrs    = t["attributes"] as? [String: Any]
            let vars     = attrs?["vars"] as? [String: Any]

            let attrKeys = attrs.map { orderedKeys(fromJSONObject: $0).filter { $0 != "vars" } } ?? []
            let varKeys  = vars.map  { orderedKeys(fromJSONObject: $0) } ?? []

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
                orderedAttributeKeys: attrKeys,
                orderedVarKeys:       varKeys
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
