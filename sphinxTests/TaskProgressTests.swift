//
//  TaskProgressTests.swift
//  sphinxTests
//
//  Created on 2025-03-05.
//  Copyright © 2025 sphinx. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import sphinx

class TaskProgressTests: XCTestCase {

    // MARK: - Helpers

    /// Build a minimal WorkspaceTask JSON for a given status.
    private func makeTask(id: String, status: String, assigneeId: String? = nil) -> WorkspaceTask? {
        var dict: [String: Any] = ["id": id, "title": "Task \(id)", "status": status]
        if let aid = assigneeId {
            dict["assignee"] = ["id": aid]
        }
        return WorkspaceTask(json: JSON(dict))
    }

    // MARK: - Tests

    func testAllDone() {
        let tasks = (1...3).compactMap { makeTask(id: "t\($0)", status: "DONE") }
        XCTAssertEqual(tasks.count, 3)

        let progress = TaskProgress(tasks: tasks)

        XCTAssertEqual(progress.total, 3)
        XCTAssertEqual(progress.doneCount, 3)
        XCTAssertEqual(progress.inProgressCount, 0)
        XCTAssertEqual(progress.todoCount, 0)
        XCTAssertEqual(progress.cancelledCount, 0)
        XCTAssertEqual(progress.activeTotal, 3)
        XCTAssertEqual(progress.completePercent, 100)
        XCTAssertEqual(progress.doneSegmentWidth, 1.0, accuracy: 0.001)
        XCTAssertEqual(progress.inProgressSegmentWidth, 0.0, accuracy: 0.001)
    }

    func testMixedStatuses() {
        // 2 DONE, 1 IN_PROGRESS, 1 TODO, 1 CANCELLED => total=5, activeTotal=4, completePercent=50
        var tasks: [WorkspaceTask] = []
        tasks.append(contentsOf: (1...2).compactMap { makeTask(id: "d\($0)", status: "DONE") })
        tasks.append(contentsOf: (1...1).compactMap { makeTask(id: "ip\($0)", status: "IN_PROGRESS") })
        tasks.append(contentsOf: (1...1).compactMap { makeTask(id: "td\($0)", status: "TODO") })
        tasks.append(contentsOf: (1...1).compactMap { makeTask(id: "c\($0)", status: "CANCELLED") })

        XCTAssertEqual(tasks.count, 5)

        let progress = TaskProgress(tasks: tasks)

        XCTAssertEqual(progress.total, 5)
        XCTAssertEqual(progress.doneCount, 2)
        XCTAssertEqual(progress.inProgressCount, 1)
        XCTAssertEqual(progress.todoCount, 1)
        XCTAssertEqual(progress.cancelledCount, 1)
        XCTAssertEqual(progress.activeTotal, 4)
        XCTAssertEqual(progress.completePercent, 50)  // round(2/4 * 100) = 50

        // doneSegmentWidth = 2/5 = 0.4
        XCTAssertEqual(Double(progress.doneSegmentWidth), 0.4, accuracy: 0.001)
        // inProgressSegmentWidth = 1/5 = 0.2
        XCTAssertEqual(Double(progress.inProgressSegmentWidth), 0.2, accuracy: 0.001)
    }

    func testAllCancelled_completePercentIsZero() {
        let tasks = (1...4).compactMap { makeTask(id: "c\($0)", status: "CANCELLED") }
        XCTAssertEqual(tasks.count, 4)

        let progress = TaskProgress(tasks: tasks)

        XCTAssertEqual(progress.total, 4)
        XCTAssertEqual(progress.cancelledCount, 4)
        XCTAssertEqual(progress.activeTotal, 0)
        XCTAssertEqual(progress.completePercent, 0, "Guard activeTotal > 0 should return 0")
        XCTAssertEqual(progress.doneSegmentWidth, 0.0, accuracy: 0.001)
        XCTAssertEqual(progress.inProgressSegmentWidth, 0.0, accuracy: 0.001)
    }

    func testEmptyTaskArray() {
        let progress = TaskProgress(tasks: [])

        XCTAssertEqual(progress.total, 0)
        XCTAssertEqual(progress.doneCount, 0)
        XCTAssertEqual(progress.inProgressCount, 0)
        XCTAssertEqual(progress.todoCount, 0)
        XCTAssertEqual(progress.cancelledCount, 0)
        XCTAssertEqual(progress.activeTotal, 0)
        XCTAssertEqual(progress.completePercent, 0)
        XCTAssertEqual(progress.doneSegmentWidth, 0.0, accuracy: 0.001)
        XCTAssertEqual(progress.inProgressSegmentWidth, 0.0, accuracy: 0.001)
    }

    func testCompletePercentRounding() {
        // 1 DONE, 2 TODO => activeTotal=3, completePercent = round(1/3*100) = round(33.33) = 33
        var tasks: [WorkspaceTask] = []
        tasks.append(contentsOf: (1...1).compactMap { makeTask(id: "d\($0)", status: "DONE") })
        tasks.append(contentsOf: (1...2).compactMap { makeTask(id: "td\($0)", status: "TODO") })

        let progress = TaskProgress(tasks: tasks)
        XCTAssertEqual(progress.completePercent, 33)
    }

    func testCompletePercent_roundsUp() {
        // 2 DONE, 1 TODO => activeTotal=3, completePercent = round(2/3*100) = round(66.67) = 67
        var tasks: [WorkspaceTask] = []
        tasks.append(contentsOf: (1...2).compactMap { makeTask(id: "d\($0)", status: "DONE") })
        tasks.append(contentsOf: (1...1).compactMap { makeTask(id: "td\($0)", status: "TODO") })

        let progress = TaskProgress(tasks: tasks)
        XCTAssertEqual(progress.completePercent, 67)
    }
}
