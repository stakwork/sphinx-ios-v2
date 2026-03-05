//
//  WorkspaceTaskTests.swift
//  sphinxTests
//
//  Created on 2026-03-05.
//  Copyright © 2026 sphinx. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import sphinx

class WorkspaceTaskTests: XCTestCase {

    // MARK: - PR Artifact Parsing Tests

    func testInit_WithPRArtifact_ParsesAllPRFields() {
        let json = JSON([
            "id": "task-1",
            "title": "Fix bug",
            "status": "IN_PROGRESS",
            "priority": "HIGH",
            "chatMessageCount": 0,
            "prArtifact": [
                "id": "artifact-123",
                "content": [
                    "url": "https://github.com/org/repo/pull/42",
                    "status": "OPEN",
                    "number": 42
                ]
            ]
        ])

        guard let task = WorkspaceTask(json: json) else {
            XCTFail("WorkspaceTask init should succeed with valid JSON")
            return
        }

        XCTAssertEqual(task.prArtifactId, "artifact-123")
        XCTAssertEqual(task.prUrl, "https://github.com/org/repo/pull/42")
        XCTAssertEqual(task.prStatus, "OPEN")
        XCTAssertEqual(task.prNumber, 42)
    }

    func testInit_WithoutPRArtifact_PRFieldsAreNil() {
        let json = JSON([
            "id": "task-2",
            "title": "Another task",
            "status": "TODO",
            "priority": "LOW",
            "chatMessageCount": 0
        ])

        guard let task = WorkspaceTask(json: json) else {
            XCTFail("WorkspaceTask init should succeed with valid JSON")
            return
        }

        XCTAssertNil(task.prArtifactId, "prArtifactId should be nil when prArtifact is absent")
        XCTAssertNil(task.prUrl, "prUrl should be nil when prArtifact is absent")
        XCTAssertNil(task.prStatus, "prStatus should be nil when prArtifact is absent")
        XCTAssertNil(task.prNumber, "prNumber should be nil when prArtifact is absent")
    }

    func testInit_WithEmptyPRArtifact_PRFieldsAreNil() {
        let json = JSON([
            "id": "task-3",
            "title": "Empty PR",
            "status": "TODO",
            "priority": "LOW",
            "chatMessageCount": 0,
            "prArtifact": [:]
        ])

        guard let task = WorkspaceTask(json: json) else {
            XCTFail("WorkspaceTask init should succeed")
            return
        }

        XCTAssertNil(task.prArtifactId)
        XCTAssertNil(task.prUrl)
        XCTAssertNil(task.prStatus)
        XCTAssertNil(task.prNumber)
    }

    func testInit_WithMergedPRStatus_ParsesCorrectly() {
        let json = JSON([
            "id": "task-4",
            "title": "Merged PR task",
            "status": "DONE",
            "priority": "MEDIUM",
            "chatMessageCount": 0,
            "prArtifact": [
                "id": "artifact-456",
                "content": [
                    "url": "https://github.com/org/repo/pull/10",
                    "status": "MERGED",
                    "number": 10
                ]
            ]
        ])

        guard let task = WorkspaceTask(json: json) else {
            XCTFail("WorkspaceTask init should succeed")
            return
        }

        XCTAssertEqual(task.prStatus, "MERGED")
        XCTAssertEqual(task.prNumber, 10)
    }

    func testInit_MissingRequiredFields_ReturnsNil() {
        let json = JSON(["status": "TODO"])
        XCTAssertNil(WorkspaceTask(json: json), "WorkspaceTask init should return nil when id/title are missing")
    }

    func testPRFields_AreMutable() {
        let json = JSON([
            "id": "task-5",
            "title": "Mutable PR task",
            "status": "TODO",
            "priority": "LOW",
            "chatMessageCount": 0,
            "prArtifact": [
                "id": "artifact-789",
                "content": [
                    "url": "https://github.com/org/repo/pull/7",
                    "status": "OPEN",
                    "number": 7
                ]
            ]
        ])

        guard var task = WorkspaceTask(json: json) else {
            XCTFail("WorkspaceTask init should succeed")
            return
        }

        task.prStatus = "MERGED"
        task.prUrl = "https://github.com/org/repo/pull/7/updated"

        XCTAssertEqual(task.prStatus, "MERGED")
        XCTAssertEqual(task.prUrl, "https://github.com/org/repo/pull/7/updated")
    }
}
