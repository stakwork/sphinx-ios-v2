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
              let transitions = dict["transitions"] as? [String: Any] else {
            return nil
        }

        var steps: [String: WorkflowStep] = [:]
        var edges: [WorkflowEdge] = []

        for (stepId, value) in transitions {
            guard let t = value as? [String: Any] else { continue }

            let position = t["position"] as? [String: Any]
            let skill    = t["skill"]    as? [String: Any]
            let status   = t["status"]   as? [String: Any]

            let step = WorkflowStep(
                id:          (t["id"] as? String) ?? stepId,
                uniqueId:    t["unique_id"]   as? String,
                displayId:   t["display_id"]  as? String,
                displayName: t["display_name"] as? String,
                name:        (t["name"] as? String) ?? "",
                positionX:   CGFloat((position?["x"] as? Double) ?? 0),
                positionY:   CGFloat((position?["y"] as? Double) ?? 0),
                skillType:   skill?["type"]        as? String,
                stepState:   status?["step_state"] as? String,
                rawJSON:     t
            )
            steps[stepId] = step

            // Build edges — prefer connection_edges, fall back to connections
            if let connEdges = t["connection_edges"] as? [[String: Any]] {
                for edge in connEdges {
                    if let targetId = edge["target_id"] as? String {
                        edges.append(WorkflowEdge(
                            fromId: stepId,
                            toId:   targetId,
                            label:  edge["name"] as? String
                        ))
                    }
                }
            } else if let connections = t["connections"] as? [String: Any] {
                // connections can be [String: String] or [String: Any] — extract first string value
                for (_, val) in connections {
                    if let targetId = val as? String {
                        edges.append(WorkflowEdge(fromId: stepId, toId: targetId, label: nil))
                        break
                    }
                }
            }
        }

        return WorkflowDiagramData(steps: steps, edges: edges)
    }
}
