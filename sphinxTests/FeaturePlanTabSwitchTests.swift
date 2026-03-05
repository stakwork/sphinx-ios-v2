//
//  FeaturePlanTabSwitchTests.swift
//  sphinxTests
//
//  Tests for the auto-tab-switch helpers and the architectureWasEmpty →
//  architectureIsNowFilled transition logic added to FeaturePlanViewController.
//
//  Because the helpers are private UIKit methods, we test the underlying
//  decision logic via thin helpers that mirror the exact expressions used
//  in the production code.
//

import XCTest
import SwiftyJSON
@testable import sphinx

// MARK: - Helpers mirroring production logic

private func architectureIsEmpty(_ feature: HiveFeature) -> Bool {
    return (feature.architecture ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func architectureIsFilled(_ feature: HiveFeature) -> Bool {
    return !architectureIsEmpty(feature)
}

/// Mirror of the guard inside switchToPlanArchitectureTabIfNeeded():
/// returns true when the helper would actually perform a switch.
private func wouldSwitchToPlanArchitecture(currentTopIndex: Int) -> Bool {
    return currentTopIndex == 0
}

/// Mirror of the guard inside switchToTasksTabIfNeeded():
/// returns true when the helper would actually perform a switch.
private func wouldSwitchToTasks(currentTopIndex: Int) -> Bool {
    return currentTopIndex != 2
}

/// Mirror of the combined condition that triggers switchToPlanArchitectureTabIfNeeded()
/// from fetchFeatureDetail.
private func shouldTriggerArchitectureSwitch(wasEmpty: Bool, isNowFilled: Bool) -> Bool {
    return wasEmpty && isNowFilled
}

// MARK: - Factory

private func makeFeature(architecture: String?) -> HiveFeature {
    var dict: [String: Any] = ["id": "test-feature", "title": "Test Feature"]
    if let arch = architecture { dict["architecture"] = arch }
    return HiveFeature(json: JSON(dict))!
}

// MARK: - Tests

class FeaturePlanTabSwitchTests: XCTestCase {

    // MARK: switchToPlanArchitectureTabIfNeeded guard

    func test_switchToPlanArchitecture_firesWhenOnChatTab() {
        XCTAssertTrue(wouldSwitchToPlanArchitecture(currentTopIndex: 0),
                      "Must switch when user is on CHAT (index 0)")
    }

    func test_switchToPlanArchitecture_noOpWhenOnPlanTab() {
        XCTAssertFalse(wouldSwitchToPlanArchitecture(currentTopIndex: 1),
                       "Must NOT switch when user is already on PLAN (index 1)")
    }

    func test_switchToPlanArchitecture_noOpWhenOnTasksTab() {
        XCTAssertFalse(wouldSwitchToPlanArchitecture(currentTopIndex: 2),
                       "Must NOT switch when user is already on TASKS (index 2)")
    }

    // MARK: switchToTasksTabIfNeeded guard

    func test_switchToTasks_firesWhenOnChatTab() {
        XCTAssertTrue(wouldSwitchToTasks(currentTopIndex: 0),
                      "Must switch when user is on CHAT (index 0)")
    }

    func test_switchToTasks_firesWhenOnPlanTab() {
        XCTAssertTrue(wouldSwitchToTasks(currentTopIndex: 1),
                      "Must switch when user is on PLAN (index 1)")
    }

    func test_switchToTasks_noOpWhenAlreadyOnTasksTab() {
        XCTAssertFalse(wouldSwitchToTasks(currentTopIndex: 2),
                       "Must NOT switch when user is already on TASKS (index 2)")
    }

    // MARK: architectureWasEmpty → architectureIsNowFilled transition logic

    func test_transition_nilToFilled_triggersSwitch() {
        let before = makeFeature(architecture: nil)
        let after  = makeFeature(architecture: "## Overview\nReal content")
        XCTAssertTrue(shouldTriggerArchitectureSwitch(
            wasEmpty: architectureIsEmpty(before),
            isNowFilled: architectureIsFilled(after)
        ), "nil → filled must trigger the switch")
    }

    func test_transition_emptyToFilled_triggersSwitch() {
        let before = makeFeature(architecture: "")
        let after  = makeFeature(architecture: "## Overview\nReal content")
        XCTAssertTrue(shouldTriggerArchitectureSwitch(
            wasEmpty: architectureIsEmpty(before),
            isNowFilled: architectureIsFilled(after)
        ), "empty string → filled must trigger the switch")
    }

    func test_transition_whitespaceToFilled_triggersSwitch() {
        let before = makeFeature(architecture: "   \t\n")
        let after  = makeFeature(architecture: "## Overview\nReal content")
        XCTAssertTrue(shouldTriggerArchitectureSwitch(
            wasEmpty: architectureIsEmpty(before),
            isNowFilled: architectureIsFilled(after)
        ), "whitespace-only → filled must trigger the switch")
    }

    func test_transition_filledToFilled_doesNotTriggerSwitch() {
        let before = makeFeature(architecture: "Old content")
        let after  = makeFeature(architecture: "Updated content")
        XCTAssertFalse(shouldTriggerArchitectureSwitch(
            wasEmpty: architectureIsEmpty(before),
            isNowFilled: architectureIsFilled(after)
        ), "filled → filled must NOT trigger the switch (subsequent update)")
    }

    func test_transition_emptyToEmpty_doesNotTriggerSwitch() {
        let before = makeFeature(architecture: nil)
        let after  = makeFeature(architecture: "")
        XCTAssertFalse(shouldTriggerArchitectureSwitch(
            wasEmpty: architectureIsEmpty(before),
            isNowFilled: architectureIsFilled(after)
        ), "empty → still empty must NOT trigger the switch")
    }

    func test_transition_filledToEmpty_doesNotTriggerSwitch() {
        let before = makeFeature(architecture: "Some content")
        let after  = makeFeature(architecture: nil)
        XCTAssertFalse(shouldTriggerArchitectureSwitch(
            wasEmpty: architectureIsEmpty(before),
            isNowFilled: architectureIsFilled(after)
        ), "filled → empty must NOT trigger the switch")
    }
}
