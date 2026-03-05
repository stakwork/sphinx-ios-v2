//
//  WorkspaceTaskTableViewCellTests.swift
//  sphinxTests
//
//  Created on 2025-02-23.
//  Copyright © 2025 sphinx. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import sphinx

class WorkspaceTaskTableViewCellTests: XCTestCase {
    
    var cell: WorkspaceTaskTableViewCell!
    
    override func setUp() {
        super.setUp()
        let nib = WorkspaceTaskTableViewCell.nib
        let objects = nib.instantiate(withOwner: nil, options: nil)
        cell = objects.first as? WorkspaceTaskTableViewCell
        cell.awakeFromNib()
    }
    
    override func tearDown() {
        cell = nil
        super.tearDown()
    }
    
    // MARK: - Status Badge Color Tests
    
    func testStatusBadgeColor_DONE() {
        let task = createMockTask(status: "DONE")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.statusBadge.backgroundColor, .systemGreen, "DONE status should display green badge")
    }
    
    func testStatusBadgeColor_IN_PROGRESS() {
        let task = createMockTask(status: "IN_PROGRESS")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.statusBadge.backgroundColor, .Sphinx.PrimaryBlue, "IN_PROGRESS status should display primary blue badge")
    }
    
    func testStatusBadgeColor_BLOCKED() {
        let task = createMockTask(status: "BLOCKED")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.statusBadge.backgroundColor, .Sphinx.PrimaryRed, "BLOCKED status should display primary red badge")
    }
    
    func testStatusBadgeColor_TODO() {
        let task = createMockTask(status: "TODO")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.statusBadge.backgroundColor, .systemGray, "TODO status should display gray badge")
    }
    
    func testStatusBadgeColor_CANCELLED() {
        let task = createMockTask(status: "CANCELLED")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.statusBadge.backgroundColor, .systemGray, "CANCELLED status should display gray badge")
    }
    
    // MARK: - Priority Badge Color Tests
    
    func testPriorityBadgeColor_CRITICAL() {
        let task = createMockTask(priority: "CRITICAL")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.priorityBadge.backgroundColor, .Sphinx.PrimaryRed, "CRITICAL priority should display primary red badge")
    }
    
    func testPriorityBadgeColor_HIGH() {
        let task = createMockTask(priority: "HIGH")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.priorityBadge.backgroundColor, .Sphinx.SphinxOrange, "HIGH priority should display orange badge")
    }
    
    func testPriorityBadgeColor_MEDIUM() {
        let task = createMockTask(priority: "MEDIUM")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.priorityBadge.backgroundColor, .Sphinx.PrimaryBlue, "MEDIUM priority should display primary blue badge")
    }
    
    func testPriorityBadgeColor_LOW() {
        let task = createMockTask(priority: "LOW")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.priorityBadge.backgroundColor, .systemGray, "LOW priority should display gray badge")
    }
    
    // MARK: - Separator Visibility Tests
    
    func testSeparatorView_IsHidden_WhenIsLastRow() {
        let task = createMockTask()
        cell.configure(with: task, isLastRow: true)
        XCTAssertTrue(cell.separatorView.isHidden, "Separator should be hidden when isLastRow is true")
    }
    
    func testSeparatorView_IsVisible_WhenNotLastRow() {
        let task = createMockTask()
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.separatorView.isHidden, "Separator should be visible when isLastRow is false")
    }
    
    // MARK: - Cell Configuration Tests
    
    func testCellConfiguration_SetsAllLabels() {
        let task = createMockTask(
            title: "Test Task",
            description: "Test Description",
            repositoryName: "test-repo",
            updatedAt: "2 days ago"
        )
        cell.configure(with: task, isLastRow: false)
        
        XCTAssertEqual(cell.titleLabel.text, "Test Task")
        // descriptionLabel was removed from the cell UI
        XCTAssertEqual(cell.repositoryLabel.text, "test-repo")
        XCTAssertEqual(cell.updatedAtLabel.text, "2 days ago")
    }
    
    func testCellStyling_MatchesRequirements() {
        XCTAssertEqual(cell.backgroundColor, .Sphinx.DashboardHeader, "Cell background should be DashboardHeader")
        XCTAssertEqual(cell.contentView.backgroundColor, .Sphinx.DashboardHeader, "ContentView background should be DashboardHeader")
        XCTAssertEqual(cell.selectionStyle, .none, "Selection style should be none")
        XCTAssertEqual(cell.separatorView.backgroundColor, .Sphinx.Divider, "Separator should use Divider color")
    }
    
    func testBadgeStyling_MatchesRequirements() {
        XCTAssertEqual(cell.statusBadge.layer.cornerRadius, 8, "Status badge should have corner radius 8")
        XCTAssertTrue(cell.statusBadge.clipsToBounds, "Status badge should clip to bounds")
        XCTAssertEqual(cell.statusBadge.textColor, .white, "Status badge text should be white")
        XCTAssertEqual(cell.statusBadge.textAlignment, .center, "Status badge text should be centered")
        
        XCTAssertEqual(cell.priorityBadge.layer.cornerRadius, 8, "Priority badge should have corner radius 8")
        XCTAssertTrue(cell.priorityBadge.clipsToBounds, "Priority badge should clip to bounds")
        XCTAssertEqual(cell.priorityBadge.textColor, .white, "Priority badge text should be white")
        XCTAssertEqual(cell.priorityBadge.textAlignment, .center, "Priority badge text should be centered")
    }
    
    // MARK: - PR Badge Tests

    func testPRBadge_HiddenWhenNoPRUrl() {
        let task = createMockTask()
        cell.configure(with: task, isLastRow: false)
        XCTAssertTrue(cell.prBadgeButton.isHidden, "PR badge should be hidden when task has no prUrl")
    }

    func testPRBadge_ShowsOpenWhenStatusIsNotMerged() {
        let task = createMockTask(prUrl: "https://github.com/org/repo/pull/1", prStatus: "IN_REVIEW")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.prBadgeButton.isHidden, "PR badge should be visible when prUrl is set")
        XCTAssertEqual(cell.prBadgeButton.title(for: .normal), "  OPEN  ")
        XCTAssertEqual(cell.prBadgeButton.backgroundColor, UIColor.Sphinx.PrimaryBlue)
    }

    func testPRBadge_ShowsMergedWhenStatusIsMerged() {
        let task = createMockTask(prUrl: "https://github.com/org/repo/pull/2", prStatus: "MERGED")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.prBadgeButton.isHidden, "PR badge should be visible for MERGED status")
        XCTAssertEqual(cell.prBadgeButton.title(for: .normal), "  MERGED  ")
        XCTAssertEqual(cell.prBadgeButton.backgroundColor, UIColor(hex: "#8B5CF6"))
    }

    func testPRBadge_ShowsMergedWhenStatusIsDone() {
        let task = createMockTask(prUrl: "https://github.com/org/repo/pull/3", prStatus: "DONE")
        cell.configure(with: task, isLastRow: false)
        XCTAssertEqual(cell.prBadgeButton.title(for: .normal), "  MERGED  ")
        XCTAssertEqual(cell.prBadgeButton.backgroundColor, UIColor(hex: "#8B5CF6"))
    }

    func testPRBadge_CallsClosureOnTap() {
        let expectedURL = URL(string: "https://github.com/org/repo/pull/99")!
        let task = createMockTask(prUrl: expectedURL.absoluteString, prStatus: "OPEN")
        cell.configure(with: task, isLastRow: false)

        var tappedURL: URL?
        cell.onPRBadgeTapped = { url in tappedURL = url }

        // Simulate tap by invoking the action directly
        cell.prBadgeButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(tappedURL, expectedURL, "onPRBadgeTapped closure should be called with the correct URL")
    }

    func testPRBadge_HiddenAfterReconfigureWithNoURL() {
        var task = createMockTask(prUrl: "https://github.com/org/repo/pull/5", prStatus: "OPEN")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.prBadgeButton.isHidden)

        // Reconfigure with no PR
        let taskNoPR = createMockTask()
        cell.configure(with: taskNoPR, isLastRow: false)
        XCTAssertTrue(cell.prBadgeButton.isHidden, "PR badge should hide after reconfiguring with no prUrl")
    }

    // MARK: - Helper Methods
    
    private func createMockTask(
        status: String = "TODO",
        priority: String = "LOW",
        title: String = "Mock Task",
        description: String? = "Mock Description",
        repositoryName: String? = "mock-repo",
        updatedAt: String? = "1 day ago",
        prUrl: String? = nil,
        prStatus: String? = nil,
        prNumber: Int? = nil
    ) -> WorkspaceTask {
        var prArtifactDict: [String: Any] = [:]
        if prUrl != nil || prStatus != nil || prNumber != nil {
            var contentDict: [String: Any] = [:]
            if let prUrl = prUrl { contentDict["url"] = prUrl }
            if let prStatus = prStatus { contentDict["status"] = prStatus }
            if let prNumber = prNumber { contentDict["number"] = prNumber }
            prArtifactDict = ["id": "pr-artifact-id", "content": contentDict]
        }

        var fullJsonDict: [String: Any] = [
            "id": "mock-id",
            "title": title,
            "description": description as Any,
            "status": status,
            "priority": priority,
            "chatMessageCount": 0,
            "repository": [
                "name": repositoryName as Any
            ],
            "updatedAt": updatedAt as Any
        ]
        if !prArtifactDict.isEmpty {
            fullJsonDict["prArtifact"] = prArtifactDict
        }
        
        return WorkspaceTask(json: JSON(fullJsonDict))!
    }
}
