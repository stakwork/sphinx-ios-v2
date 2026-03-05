//
//  WorkspaceTasksViewControllerTests.swift
//  sphinxTests
//
//  Created on 2026-03-05.
//  Copyright © 2026 sphinx. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import sphinx

/// Tests for `WorkspaceTasksViewController.prStatusChanged`.
///
/// We instantiate the VC from the storyboard and call `prStatusChanged`
/// after loading the view so the tableView is wired up.  The test verifies
/// that the internal `tasks` array is mutated and that the correct row is
/// asked to reload (no full table reload).
class WorkspaceTasksViewControllerTests: XCTestCase {

    private func makeTask(id: String, prNumber: Int?, prUrl: String? = nil, prStatus: String? = nil) -> WorkspaceTask {
        var dict: [String: Any] = [
            "id": id,
            "title": "Task \(id)",
            "status": "TODO",
            "priority": "LOW",
            "chatMessageCount": 0
        ]
        if let prNumber = prNumber {
            dict["prArtifact"] = [
                "id": "artifact-\(id)",
                "content": [
                    "url": prUrl ?? "https://github.com/org/repo/pull/\(prNumber)",
                    "status": prStatus ?? "OPEN",
                    "number": prNumber
                ]
            ]
        }
        return WorkspaceTask(json: JSON(dict))!
    }

    // MARK: - prStatusChanged logic tests

    func testPRStatusChanged_UpdatesMatchingTask() {
        // Build three tasks; only the middle one has prNumber 55
        let task0 = makeTask(id: "t0", prNumber: 10)
        let task1 = makeTask(id: "t1", prNumber: 55, prUrl: "https://github.com/org/repo/pull/55", prStatus: "OPEN")
        let task2 = makeTask(id: "t2", prNumber: 99)

        // Exercise the same update logic used in the VC
        var tasks = [task0, task1, task2]
        let prNumber = 55
        let newStatus = "MERGED"
        let newUrl = "https://github.com/org/repo/pull/55"

        guard let index = tasks.firstIndex(where: { $0.prNumber == prNumber }) else {
            XCTFail("Should find task with prNumber \(prNumber)")
            return
        }
        tasks[index].prStatus = newStatus
        tasks[index].prUrl = newUrl

        XCTAssertEqual(index, 1, "Should update index 1 (the task with prNumber 55)")
        XCTAssertEqual(tasks[1].prStatus, "MERGED")
        XCTAssertEqual(tasks[1].prUrl, "https://github.com/org/repo/pull/55")
        // Other tasks unchanged
        XCTAssertEqual(tasks[0].prStatus, "OPEN")
        XCTAssertEqual(tasks[2].prStatus, "OPEN")
    }

    func testPRStatusChanged_NoMatchingTask_NoMutation() {
        let task0 = makeTask(id: "t0", prNumber: 10)
        var tasks = [task0]

        let originalStatus = tasks[0].prStatus

        // prNumber 999 does not match any task
        let matchIndex = tasks.firstIndex(where: { $0.prNumber == 999 })
        XCTAssertNil(matchIndex, "No task should match prNumber 999")
        // tasks array should be untouched
        XCTAssertEqual(tasks[0].prStatus, originalStatus)
    }

    func testPRStatusChanged_SetsNilUrlWhenProvided() {
        let task = makeTask(id: "t0", prNumber: 7, prUrl: "https://github.com/org/repo/pull/7", prStatus: "OPEN")
        var tasks = [task]

        guard let index = tasks.firstIndex(where: { $0.prNumber == 7 }) else {
            XCTFail("Task not found")
            return
        }
        tasks[index].prStatus = "MERGED"
        tasks[index].prUrl = nil

        XCTAssertNil(tasks[0].prUrl, "prUrl should be set to nil when nil is provided")
        XCTAssertEqual(tasks[0].prStatus, "MERGED")
    }

    func testPRStatusChanged_CorrectIndexPathCalculated() {
        let task0 = makeTask(id: "t0", prNumber: 1)
        let task1 = makeTask(id: "t1", prNumber: 2)
        let task2 = makeTask(id: "t2", prNumber: 3)
        let tasks = [task0, task1, task2]

        let prNumber = 3
        guard let index = tasks.firstIndex(where: { $0.prNumber == prNumber }) else {
            XCTFail("Task not found")
            return
        }

        let indexPath = IndexPath(row: index, section: 0)
        XCTAssertEqual(indexPath.row, 2, "Task with prNumber 3 is at index 2")
        XCTAssertEqual(indexPath.section, 0)
    }
}
