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
        XCTAssertEqual(cell.prBadgeButton.title(for: .normal), "  OPEN PR  ")
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

    // MARK: - HALTED Workflow Badge & Retry Button Tests

    func testHaltedWorkflowBadge_HiddenWhenWorkflowStatusIsNotHalted() {
        let task = createMockTask(workflowStatus: "IN_PROGRESS")
        cell.configure(with: task, isLastRow: false)
        XCTAssertTrue(cell.haltedWorkflowBadge.isHidden, "haltedWorkflowBadge should be hidden when workflowStatus is not HALTED")
    }

    func testHaltedWorkflowBadge_HiddenWhenWorkflowStatusIsNil() {
        let task = createMockTask(workflowStatus: nil)
        cell.configure(with: task, isLastRow: false)
        XCTAssertTrue(cell.haltedWorkflowBadge.isHidden, "haltedWorkflowBadge should be hidden when workflowStatus is nil")
    }

    func testHaltedWorkflowBadge_VisibleWhenWorkflowStatusIsHalted() {
        let task = createMockTask(workflowStatus: "HALTED")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.haltedWorkflowBadge.isHidden, "haltedWorkflowBadge should be visible when workflowStatus is HALTED")

        // Verify the badge is in the bottom row (not overlapping priorityBadge in the top area)
        cell.layoutIfNeeded()
        let haltedFrame = cell.haltedWorkflowBadge.frame
        let priorityFrame = cell.priorityBadge.frame
        XCTAssertGreaterThan(haltedFrame.minY, priorityFrame.maxY, "haltedWorkflowBadge should be below priorityBadge, not overlapping it")
    }

    func testRightPillStack_NoPillVisible_DateAtTrailingEdge() {
        let task = createMockTask(prUrl: nil, workflowStatus: nil)
        cell.configure(with: task, isLastRow: false)
        XCTAssertTrue(cell.prBadgeButton.isHidden)
        XCTAssertTrue(cell.haltedWorkflowBadge.isHidden)
        XCTAssertNotNil(cell.rightPillStack)
        XCTAssertTrue(cell.rightPillStack.arrangedSubviews.contains(cell.updatedAtLabel))
    }

    func testRightPillStack_PRVisible_DateRightOfPR() {
        let task = createMockTask(prUrl: "https://github.com/org/repo/pull/1", prStatus: "OPEN")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.prBadgeButton.isHidden)
        XCTAssertTrue(cell.haltedWorkflowBadge.isHidden)
        let subviews = cell.rightPillStack.arrangedSubviews
        let prIndex = subviews.firstIndex(of: cell.prBadgeButton)!
        let dateIndex = subviews.firstIndex(of: cell.updatedAtLabel)!
        XCTAssertEqual(prIndex, 0, "PR badge should be the leftmost item")
        XCTAssertGreaterThan(dateIndex, prIndex, "Date label should be to the right of the PR badge")
    }

    func testRightPillStack_HaltedVisible_DateLeftOfHalted() {
        let task = createMockTask(workflowStatus: "HALTED")
        cell.configure(with: task, isLastRow: false)
        XCTAssertTrue(cell.prBadgeButton.isHidden)
        XCTAssertFalse(cell.haltedWorkflowBadge.isHidden)
        XCTAssertFalse(cell.retryWorkflowButton.isHidden)
    }

    func testRightPillStack_NoLayoutBleed_OnCellReuse() {
        cell.configure(with: createMockTask(prUrl: "https://github.com/org/repo/pull/1", prStatus: "OPEN"), isLastRow: false)
        XCTAssertFalse(cell.prBadgeButton.isHidden)

        cell.configure(with: createMockTask(workflowStatus: "HALTED"), isLastRow: false)
        XCTAssertTrue(cell.prBadgeButton.isHidden)
        XCTAssertFalse(cell.haltedWorkflowBadge.isHidden)

        cell.configure(with: createMockTask(), isLastRow: false)
        XCTAssertTrue(cell.prBadgeButton.isHidden)
        XCTAssertTrue(cell.haltedWorkflowBadge.isHidden)
        XCTAssertTrue(cell.retryWorkflowButton.isHidden)
    }

    func testRetryWorkflowButton_HiddenWhenWorkflowStatusIsNotHalted() {
        let task = createMockTask(workflowStatus: "COMPLETED")
        cell.configure(with: task, isLastRow: false)
        XCTAssertTrue(cell.retryWorkflowButton.isHidden, "retryWorkflowButton should be hidden when workflowStatus is not HALTED")
    }

    func testRetryWorkflowButton_HiddenWhenWorkflowStatusIsNil() {
        let task = createMockTask(workflowStatus: nil)
        cell.configure(with: task, isLastRow: false)
        XCTAssertTrue(cell.retryWorkflowButton.isHidden, "retryWorkflowButton should be hidden when workflowStatus is nil")
    }

    func testRetryWorkflowButton_VisibleWhenWorkflowStatusIsHalted() {
        let task = createMockTask(workflowStatus: "HALTED")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.retryWorkflowButton.isHidden, "retryWorkflowButton should be visible when workflowStatus is HALTED")
    }

    func testRetryWorkflowButton_CallsClosureOnTap() {
        let task = createMockTask(workflowStatus: "HALTED")
        cell.configure(with: task, isLastRow: false)

        var tapped = false
        cell.onRetryWorkflowTapped = { tapped = true }
        cell.retryWorkflowButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(tapped, "onRetryWorkflowTapped closure should be called when retry button is tapped")
    }

    func testHaltedBadgeAndRetryButton_HideAfterReconfigureWithNonHaltedStatus() {
        let haltedTask = createMockTask(workflowStatus: "HALTED")
        cell.configure(with: haltedTask, isLastRow: false)
        XCTAssertFalse(cell.haltedWorkflowBadge.isHidden)
        XCTAssertFalse(cell.retryWorkflowButton.isHidden)

        let normalTask = createMockTask(workflowStatus: "IN_PROGRESS")
        cell.configure(with: normalTask, isLastRow: false)
        XCTAssertTrue(cell.haltedWorkflowBadge.isHidden, "haltedWorkflowBadge should hide after reconfiguring with non-HALTED status")
        XCTAssertTrue(cell.retryWorkflowButton.isHidden, "retryWorkflowButton should hide after reconfiguring with non-HALTED status")
    }

    // MARK: - Deployment Pill Tests

    func testDeploymentPill_HiddenWhenNilStatus() {
        let task = createMockTask(deploymentStatus: nil)
        cell.configure(with: task, isLastRow: false)
        XCTAssertTrue(cell.deploymentPill.isHidden, "deploymentPill should be hidden when deploymentStatus is nil")
    }

    func testDeploymentPill_ProductionShowsGreenBorderedPill() {
        let task = createMockTask(deploymentStatus: "production")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.deploymentPill.isHidden, "deploymentPill should be visible for production status")
        XCTAssertEqual(cell.deploymentPill.text, "  PRODUCTION  ")
        XCTAssertEqual(cell.deploymentPill.textColor, .Sphinx.PrimaryGreen)
        XCTAssertEqual(cell.deploymentPill.backgroundColor, .white)
        XCTAssertEqual(cell.deploymentPill.layer.borderColor, UIColor.Sphinx.PrimaryGreen.cgColor)
    }

    func testDeploymentPill_StagingShowsOrangeBorderedPill() {
        let task = createMockTask(deploymentStatus: "staging")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.deploymentPill.isHidden, "deploymentPill should be visible for staging status")
        XCTAssertEqual(cell.deploymentPill.text, "  STAGING  ")
        XCTAssertEqual(cell.deploymentPill.textColor, .Sphinx.SphinxOrange)
        XCTAssertEqual(cell.deploymentPill.backgroundColor, .white)
        XCTAssertEqual(cell.deploymentPill.layer.borderColor, UIColor.Sphinx.SphinxOrange.cgColor)
    }

    func testDeploymentPill_FailedShowsRedBorderedPill() {
        let task = createMockTask(deploymentStatus: "failed")
        cell.configure(with: task, isLastRow: false)
        XCTAssertFalse(cell.deploymentPill.isHidden, "deploymentPill should be visible for failed status")
        XCTAssertEqual(cell.deploymentPill.text, "  FAILED  ")
        XCTAssertEqual(cell.deploymentPill.textColor, .Sphinx.PrimaryRed)
        XCTAssertEqual(cell.deploymentPill.backgroundColor, .white)
        XCTAssertEqual(cell.deploymentPill.layer.borderColor, UIColor.Sphinx.PrimaryRed.cgColor)
    }

    func testDeploymentPill_HiddenAfterReuse() {
        // First configure with production status — pill should be visible
        let productionTask = createMockTask(deploymentStatus: "production")
        cell.configure(with: productionTask, isLastRow: false)
        XCTAssertFalse(cell.deploymentPill.isHidden)

        // Reconfigure with nil — pill should be hidden (no bleed)
        let nilTask = createMockTask(deploymentStatus: nil)
        cell.configure(with: nilTask, isLastRow: false)
        XCTAssertTrue(cell.deploymentPill.isHidden, "deploymentPill should be hidden after reconfiguring with nil status")
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
        prNumber: Int? = nil,
        workflowStatus: String? = nil,
        deploymentStatus: String? = nil
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
            "updatedAt": updatedAt as Any,
            "workflowStatus": workflowStatus as Any,
            "deploymentStatus": deploymentStatus as Any
        ]
        if !prArtifactDict.isEmpty {
            fullJsonDict["prArtifact"] = prArtifactDict
        }
        
        return WorkspaceTask(json: JSON(fullJsonDict))!
    }
}
