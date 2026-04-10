//
//  MarkdownContentSplitter.swift
//  sphinx
//
//  Created on 2026-04-09.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation

// MARK: - Segment type

enum MessageContentSegment: Sendable {
    case text(String)
    case table(headers: [String], rows: [[String]])
}

// MARK: - Splitter

struct MarkdownContentSplitter {

    /// Splits raw message text into ordered `.text` and `.table` segments.
    static func split(_ raw: String) -> [MessageContentSegment] {
        // Preprocess escape sequences (same as MarkdownRenderer.preprocess)
        let preprocessed = raw.replacingOccurrences(of: "\\n", with: "\n")

        let lines = preprocessed.components(separatedBy: "\n")
        var segments: [MessageContentSegment] = []
        var textAccumulator: [String] = []

        var i = 0
        while i < lines.count {
            let line = lines[i]

            // Check if this looks like a table header line
            if isTableLine(line) && i + 2 < lines.count && isSeparatorLine(lines[i + 1]) {
                // Collect all consecutive table lines starting from header
                var tableLines: [String] = [line, lines[i + 1]]
                var j = i + 2
                while j < lines.count && isTableLine(lines[j]) {
                    tableLines.append(lines[j])
                    j += 1
                }

                // Valid table: header + separator + ≥1 data row
                if tableLines.count >= 3 {
                    // Flush accumulated text
                    let text = textAccumulator.joined(separator: "\n")
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        segments.append(.text(text))
                    }
                    textAccumulator.removeAll()

                    // Parse table: tableLines[0] = header, tableLines[1] = separator, tableLines[2...] = data rows
                    let headers = parseCells(tableLines[0])
                    let rows = tableLines.dropFirst(2).map { parseCells($0) }
                    segments.append(.table(headers: headers, rows: Array(rows)))

                    i = j
                    continue
                }
            }

            textAccumulator.append(line)
            i += 1
        }

        // Flush remaining text
        let remaining = textAccumulator.joined(separator: "\n")
        let trimmedRemaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRemaining.isEmpty {
            segments.append(.text(remaining))
        }

        return segments
    }

    // MARK: - Private helpers

    /// Returns true if the line looks like a GFM table row (starts with `|`)
    private static func isTableLine(_ line: String) -> Bool {
        return line.trimmingCharacters(in: .whitespaces).hasPrefix("|")
    }

    /// Returns true if the line is a GFM separator row (cells contain only `-`, `:`, spaces)
    private static func isSeparatorLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        // Remove leading/trailing pipes, then check each cell
        let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "| "))
        let cells = stripped.components(separatedBy: "|")
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
        }
    }

    /// Splits a GFM table row on `|`, trims whitespace, and drops empty leading/trailing cells.
    private static func parseCells(_ line: String) -> [String] {
        var cells = line.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        // Drop empty leading cell (from leading `|`)
        if cells.first == "" { cells.removeFirst() }
        // Drop empty trailing cell (from trailing `|`)
        if cells.last == "" { cells.removeLast() }
        return cells
    }
}
