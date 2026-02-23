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
        XCTAssertEqual(cell.descriptionLabel.text, "Test Description")
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
    
    // MARK: - Helper Methods
    
    private func createMockTask(
        status: String = "TODO",
        priority: String = "LOW",
        title: String = "Mock Task",
        description: String? = "Mock Description",
        repositoryName: String? = "mock-repo",
        updatedAt: String? = "1 day ago"
    ) -> WorkspaceTask {
        let jsonDict: [String: Any] = [
            "id": "mock-id",
            "title": title,
            "description": description as Any,
            "status": status,
            "priority": priority,
            "repositoryName": repositoryName as Any,
            "updatedAt": updatedAt as Any,
            "chatMessageCount": 0
        ]
        
        // Create a mock WorkspaceTask by constructing JSON
        let json = JSON(jsonDict)
        
        // Since WorkspaceTask expects nested objects, we need to create a proper structure
        let fullJsonDict: [String: Any] = [
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
        
        return WorkspaceTask(json: JSON(fullJsonDict))!
    }
}
