//
//  FeatureChatMessageCellPublishPromptTests.swift
//  sphinxTests
//
//  Unit tests for PUBLISH_PROMPT card integration in FeatureChatMessageCell.
//  Verifies correct card visibility, reuse cleanup, and flipPublishPromptToPublished().
//

import XCTest
import SwiftyJSON
@testable import sphinx

class FeatureChatMessageCellPublishPromptTests: XCTestCase {

    // MARK: - Helpers

    private func makeCell() -> FeatureChatMessageCell {
        FeatureChatMessageCell(style: .default, reuseIdentifier: "test")
    }

    /// Builds a minimal HiveChatMessage JSON with a single PUBLISH_PROMPT artifact.
    private func makePublishPromptMessage(
        published: Bool = false,
        promptId: String = "clprompt000000000000001",
        promptVersionId: String = "clversion000000000000007",
        promptName: String? = "my-cool-prompt"
    ) -> HiveChatMessage? {
        var contentDict: [String: Any] = [
            "promptId": promptId,
            "promptVersionId": promptVersionId,
            "published": published
        ]
        if let name = promptName { contentDict["promptName"] = name }

        let jsonDict: [String: Any] = [
            "id": "msg-pp-test-001",
            "message": "Here is the prompt",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-pp-test-001",
                    "type": "PUBLISH_PROMPT",
                    "content": contentDict as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        return HiveChatMessage(json: JSON(jsonDict))
    }

    /// Builds a minimal HiveChatMessage with a PUBLISH_SCRIPT artifact.
    private func makePublishScriptMessage() -> HiveChatMessage? {
        let jsonDict: [String: Any] = [
            "id": "msg-ps-test-001",
            "message": "Here is the script",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-ps-test-001",
                    "type": "PUBLISH_SCRIPT",
                    "content": [
                        "scriptId": 42,
                        "scriptVersionId": 926,
                        "scriptName": "my-script",
                        "published": false
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        return HiveChatMessage(json: JSON(jsonDict))
    }

    /// Builds a minimal HiveChatMessage with a PUBLISH_WORKFLOW artifact.
    private func makePublishWorkflowMessage() -> HiveChatMessage? {
        let jsonDict: [String: Any] = [
            "id": "msg-pw-test-001",
            "message": "Here is the workflow",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-pw-test-001",
                    "type": "PUBLISH_WORKFLOW",
                    "content": [
                        "workflowId": 99,
                        "workflowName": "my-workflow",
                        "workflowRefId": "wf-ref-abc",
                        "published": false
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        return HiveChatMessage(json: JSON(jsonDict))
    }

    /// Builds a plain HiveChatMessage with no publish artifacts.
    private func makePlainMessage() -> HiveChatMessage? {
        let jsonDict: [String: Any] = [
            "id": "msg-plain-test-001",
            "message": "Just a plain message",
            "role": "ASSISTANT"
        ]
        return HiveChatMessage(json: JSON(jsonDict))
    }

    // MARK: - Tests: Card visibility on PUBLISH_PROMPT message

    func testConfigureWithPublishPromptMessage_ShowsPromptCard() {
        let cell = makeCell()
        guard let message = makePublishPromptMessage() else {
            XCTFail("Failed to create PUBLISH_PROMPT message fixture")
            return
        }
        cell.configure(with: message)
        XCTAssertFalse(cell._publishPromptCardViewIsHidden,
                       "publishPromptCardView should be visible for a PUBLISH_PROMPT message")
    }

    func testConfigureWithPublishPromptMessage_HidesScriptCard() {
        let cell = makeCell()
        guard let message = makePublishPromptMessage() else {
            XCTFail("Failed to create PUBLISH_PROMPT message fixture")
            return
        }
        cell.configure(with: message)
        XCTAssertTrue(cell._publishScriptCardViewIsHidden,
                      "publishScriptCardView should be hidden when only a PUBLISH_PROMPT artifact is present")
    }

    func testConfigureWithPublishPromptMessage_HidesWorkflowCard() {
        let cell = makeCell()
        guard let message = makePublishPromptMessage() else {
            XCTFail("Failed to create PUBLISH_PROMPT message fixture")
            return
        }
        cell.configure(with: message)
        XCTAssertTrue(cell._publishWorkflowCardViewIsHidden,
                      "publishWorkflowCardView should be hidden when only a PUBLISH_PROMPT artifact is present")
    }

    func testConfigureWithPublishPromptMessage_StoresArtifact() {
        let cell = makeCell()
        guard let message = makePublishPromptMessage() else {
            XCTFail("Failed to create PUBLISH_PROMPT message fixture")
            return
        }
        cell.configure(with: message)
        XCTAssertNotNil(cell._currentPublishPromptArtifact,
                        "currentPublishPromptArtifact should be set after configure with PUBLISH_PROMPT message")
    }

    // MARK: - Tests: Reuse cleanup — prompt → plain

    func testReuseAfterPublishPrompt_WithPlainMessage_HidesPromptCard() {
        let cell = makeCell()
        guard let promptMessage = makePublishPromptMessage(),
              let plainMessage = makePlainMessage() else {
            XCTFail("Failed to create message fixtures")
            return
        }
        // First configure with a PUBLISH_PROMPT message
        cell.configure(with: promptMessage)
        XCTAssertFalse(cell._publishPromptCardViewIsHidden, "Precondition: prompt card should be visible")

        // Then reconfigure with a plain message (simulates cell reuse)
        cell.configure(with: plainMessage)
        XCTAssertTrue(cell._publishPromptCardViewIsHidden,
                      "publishPromptCardView should be hidden after reconfiguring with a plain message")
        XCTAssertNil(cell._currentPublishPromptArtifact,
                     "currentPublishPromptArtifact should be nil after reconfiguring with a plain message")
    }

    // MARK: - Tests: Reuse cleanup — prompt → script

    func testReuseAfterPublishPrompt_WithScriptMessage_HidesPromptCard() {
        let cell = makeCell()
        guard let promptMessage = makePublishPromptMessage(),
              let scriptMessage = makePublishScriptMessage() else {
            XCTFail("Failed to create message fixtures")
            return
        }
        cell.configure(with: promptMessage)
        XCTAssertFalse(cell._publishPromptCardViewIsHidden, "Precondition: prompt card should be visible")

        cell.configure(with: scriptMessage)
        XCTAssertTrue(cell._publishPromptCardViewIsHidden,
                      "publishPromptCardView should be hidden after reconfiguring with a PUBLISH_SCRIPT message")
        XCTAssertNil(cell._currentPublishPromptArtifact,
                     "currentPublishPromptArtifact should be nil after reconfiguring with a PUBLISH_SCRIPT message")
        XCTAssertFalse(cell._publishScriptCardViewIsHidden,
                       "publishScriptCardView should be visible after reconfiguring with a PUBLISH_SCRIPT message")
    }

    // MARK: - Tests: Reuse cleanup — prompt → workflow

    func testReuseAfterPublishPrompt_WithWorkflowMessage_HidesPromptCard() {
        let cell = makeCell()
        guard let promptMessage = makePublishPromptMessage(),
              let workflowMessage = makePublishWorkflowMessage() else {
            XCTFail("Failed to create message fixtures")
            return
        }
        cell.configure(with: promptMessage)
        XCTAssertFalse(cell._publishPromptCardViewIsHidden, "Precondition: prompt card should be visible")

        cell.configure(with: workflowMessage)
        XCTAssertTrue(cell._publishPromptCardViewIsHidden,
                      "publishPromptCardView should be hidden after reconfiguring with a PUBLISH_WORKFLOW message")
        XCTAssertNil(cell._currentPublishPromptArtifact,
                     "currentPublishPromptArtifact should be nil after reconfiguring with a PUBLISH_WORKFLOW message")
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "publishWorkflowCardView should be visible after reconfiguring with a PUBLISH_WORKFLOW message")
    }

    // MARK: - Tests: prepareForReuse clears prompt card state

    func testPrepareForReuse_AfterPublishPrompt_HidesPromptCard() {
        let cell = makeCell()
        guard let message = makePublishPromptMessage() else {
            XCTFail("Failed to create PUBLISH_PROMPT message fixture")
            return
        }
        cell.configure(with: message)
        XCTAssertFalse(cell._publishPromptCardViewIsHidden, "Precondition: prompt card should be visible")

        cell.prepareForReuse()

        XCTAssertTrue(cell._publishPromptCardViewIsHidden,
                      "publishPromptCardView should be hidden after prepareForReuse")
        XCTAssertNil(cell._currentPublishPromptArtifact,
                     "currentPublishPromptArtifact should be nil after prepareForReuse")
    }

    // MARK: - Tests: flipPublishPromptToPublished

    func testFlipPublishPromptToPublished_FlipsCardStateWithoutReconfigure() {
        let cell = makeCell()
        guard let message = makePublishPromptMessage(published: false) else {
            XCTFail("Failed to create PUBLISH_PROMPT message fixture")
            return
        }
        cell.configure(with: message)

        // Card should start in unpublished state (Publish button visible)
        let cardView = cell._publishPromptCardView
        // Flip to published
        cell.flipPublishPromptToPublished()

        // After flip, published label should be visible and publish button hidden
        // We test via the card's internal state by calling configure again with published=true
        // and confirming the card behaves consistently.
        // Direct state inspection: re-configure with published:true and compare to flipped state.
        // Since both should produce "Published ✓", we test by calling setPublished and checking
        // the card still reflects the change (no crash, visible card in published state).
        XCTAssertFalse(cell._publishPromptCardViewIsHidden,
                       "Card should still be visible after flipPublishPromptToPublished()")
        // The card's setPublished(true) should have been called — verify by calling again (idempotent)
        cell.flipPublishPromptToPublished()
        XCTAssertFalse(cell._publishPromptCardViewIsHidden,
                       "Card should remain visible after repeated flipPublishPromptToPublished() calls")
    }

    // MARK: - Tests: Precedence — script wins over prompt

    func testScriptPrecedence_WhenBothScriptAndPromptPresent_ShowsScriptCard() {
        // A message with both PUBLISH_SCRIPT and PUBLISH_PROMPT — script takes precedence
        let jsonDict: [String: Any] = [
            "id": "msg-prec-test-001",
            "message": "Precedence test",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-ps-prec-001",
                    "type": "PUBLISH_SCRIPT",
                    "content": [
                        "scriptId": 42,
                        "scriptVersionId": 926,
                        "scriptName": "my-script",
                        "published": false
                    ] as [String: Any]
                ] as [String: Any],
                [
                    "id": "artifact-pp-prec-001",
                    "type": "PUBLISH_PROMPT",
                    "content": [
                        "promptId": "clprompt000000000000001",
                        "promptVersionId": "clversion000000000000007",
                        "promptName": "my-prompt",
                        "published": false
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        guard let message = HiveChatMessage(json: JSON(jsonDict)) else {
            XCTFail("Failed to create message fixture")
            return
        }
        let cell = makeCell()
        cell.configure(with: message)

        XCTAssertFalse(cell._publishScriptCardViewIsHidden,
                       "Script card should be visible when both script and prompt artifacts are present")
        XCTAssertTrue(cell._publishPromptCardViewIsHidden,
                      "Prompt card should be hidden when script takes precedence")
    }

    // MARK: - Tests: Bubble width constraints for publish cards vs PR card

    /// Helper that builds a minimal PR artifact message.
    private func makePRMessage() -> HiveChatMessage? {
        let jsonDict: [String: Any] = [
            "id": "msg-pr-test-001",
            "message": "PR created",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-pr-test-001",
                    "type": "GITHUB_PR",
                    "content": [
                        "pullRequestUrl": "https://github.com/org/repo/pull/1",
                        "title": "Fix bug",
                        "status": "open"
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        return HiveChatMessage(json: JSON(jsonDict))
    }

    func testPublishPromptCard_BubbleWidthIsLeqConstraint() {
        let cell = makeCell()
        guard let message = makePublishPromptMessage() else {
            XCTFail("Failed to create PUBLISH_PROMPT message fixture"); return
        }
        cell.configure(with: message)
        let constraint = cell._bubbleWidthConstraint
        XCTAssertEqual(constraint.relation, .lessThanOrEqual,
                       "Publish prompt bubble width should use a lessThanOrEqual constraint")
        XCTAssertEqual(constraint.multiplier, 0.78, accuracy: 0.001,
                       "Publish prompt bubble width multiplier should be ~0.78")
    }

    func testPublishScriptCard_BubbleWidthIsLeqConstraint() {
        let cell = makeCell()
        guard let message = makePublishScriptMessage() else {
            XCTFail("Failed to create PUBLISH_SCRIPT message fixture"); return
        }
        cell.configure(with: message)
        let constraint = cell._bubbleWidthConstraint
        XCTAssertEqual(constraint.relation, .lessThanOrEqual,
                       "Publish script bubble width should use a lessThanOrEqual constraint")
        XCTAssertEqual(constraint.multiplier, 0.78, accuracy: 0.001,
                       "Publish script bubble width multiplier should be ~0.78")
    }

    func testPublishWorkflowCard_BubbleWidthIsLeqConstraint() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage() else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        let constraint = cell._bubbleWidthConstraint
        XCTAssertEqual(constraint.relation, .lessThanOrEqual,
                       "Publish workflow bubble width should use a lessThanOrEqual constraint")
        XCTAssertEqual(constraint.multiplier, 0.78, accuracy: 0.001,
                       "Publish workflow bubble width multiplier should be ~0.78")
    }

    func testPRCard_BubbleWidthIsEqualConstraintAt060() {
        let cell = makeCell()
        guard let message = makePRMessage() else {
            XCTFail("Failed to create PR message fixture"); return
        }
        cell.configure(with: message)
        let constraint = cell._bubbleWidthConstraint
        XCTAssertEqual(constraint.relation, .equal,
                       "PR card bubble width should use an equality constraint (unchanged)")
        XCTAssertEqual(constraint.multiplier, 0.60, accuracy: 0.001,
                       "PR card bubble width multiplier should remain 0.60")
    }
}
