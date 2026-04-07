//
//  TaskDependencyDiagramViewTests.swift
//  sphinxTests
//
//  Created on 2025-04-07.
//  Copyright © 2025 sphinx. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import sphinx

class TaskDependencyDiagramViewTests: XCTestCase {

    var view: TaskDependencyDiagramView!

    override func setUp() {
        super.setUp()
        view = TaskDependencyDiagramView()
    }

    override func tearDown() {
        view = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTask(id: String, dependsOnTaskIds: [String] = []) -> WorkspaceTask {
        let json = JSON([
            "id": id,
            "title": "Task \(id)",
            "status": "TODO",
            "priority": "LOW",
            "chatMessageCount": 0,
            "dependsOnTaskIds": dependsOnTaskIds
        ])
        return WorkspaceTask(json: json)!
    }

    // MARK: - Column Assignment Tests

    /// All independent tasks → all in column 0
    func testColumnAssignment_ParallelIndependent() {
        let a = makeTask(id: "A")
        let b = makeTask(id: "B")
        let tasks = [a, b]

        let columns = view.computeColumnAssignments(for: tasks)

        XCTAssertEqual(columns["A"], 0, "Independent task A should be in column 0")
        XCTAssertEqual(columns["B"], 0, "Independent task B should be in column 0")
    }

    /// Linear chain A → B → C → columns 0, 1, 2
    func testColumnAssignment_LinearChain() {
        let a = makeTask(id: "A")
        let b = makeTask(id: "B", dependsOnTaskIds: ["A"])
        let c = makeTask(id: "C", dependsOnTaskIds: ["B"])
        let tasks = [a, b, c]

        let columns = view.computeColumnAssignments(for: tasks)

        XCTAssertEqual(columns["A"], 0, "A (no deps) should be in column 0")
        XCTAssertEqual(columns["B"], 1, "B depends on A (col 0) → should be col 1")
        XCTAssertEqual(columns["C"], 2, "C depends on B (col 1) → should be col 2")
    }

    /// Diamond: A→B, A→C, B→D, C→D — D should be in column 2
    func testColumnAssignment_Diamond() {
        let a = makeTask(id: "A")
        let b = makeTask(id: "B", dependsOnTaskIds: ["A"])
        let c = makeTask(id: "C", dependsOnTaskIds: ["A"])
        let d = makeTask(id: "D", dependsOnTaskIds: ["B", "C"])
        let tasks = [a, b, c, d]

        let columns = view.computeColumnAssignments(for: tasks)

        XCTAssertEqual(columns["A"], 0, "A should be in column 0")
        XCTAssertEqual(columns["B"], 1, "B depends on A → column 1")
        XCTAssertEqual(columns["C"], 1, "C depends on A → column 1")
        XCTAssertEqual(columns["D"], 2, "D depends on B and C (both col 1) → column 2")
    }

    /// Task with unknown dependency ID — should not crash, should default to 0 (no valid predecessor found)
    func testColumnAssignment_UnknownDependencyId() {
        let a = makeTask(id: "A", dependsOnTaskIds: ["NONEXISTENT"])
        let tasks = [a]

        let columns = view.computeColumnAssignments(for: tasks)
        // If dependsOnTaskIds has no resolvable tasks, defaults to 0
        XCTAssertEqual(columns["A"], 0, "Task with unresolved dependency should default to column 0")
    }

    /// Empty task list — should not crash
    func testColumnAssignment_EmptyTasks() {
        let columns = view.computeColumnAssignments(for: [])
        XCTAssertTrue(columns.isEmpty, "Empty task list should produce empty column assignments")
    }
}
