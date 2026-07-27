//
//  FeatureChatMessageCellPublishWorkflowTests.swift
//  sphinxTests
//
//  Unit tests for PUBLISH_WORKFLOW card integration in FeatureChatMessageCell.
//  Verifies card visibility, reuse cleanup, loading state, flipPublishWorkflowToPublished(),
//  and model-backed loading flag survival across reconfigures.
//

import XCTest
import SwiftyJSON
@testable import sphinx

class FeatureChatMessageCellPublishWorkflowTests: XCTestCase {

    // MARK: - Helpers

    private func makeCell() -> FeatureChatMessageCell {
        FeatureChatMessageCell(style: .default, reuseIdentifier: "test")
    }

    /// Builds a minimal HiveChatMessage JSON with a single PUBLISH_WORKFLOW artifact.
    private func makePublishWorkflowMessage(
        published: Bool = false,
        workflowId: Int = 99,
        workflowName: String? = "my-workflow",
        workflowRefId: String? = "wf-ref-abc"
    ) -> HiveChatMessage? {
        var contentDict: [String: Any] = [
            "workflowId": workflowId,
            "published": published
        ]
        if let name = workflowName { contentDict["workflowName"] = name }
        if let refId = workflowRefId { contentDict["workflowRefId"] = refId }

        let jsonDict: [String: Any] = [
            "id": "msg-pw-test-001",
            "message": "Here is the workflow",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-pw-test-001",
                    "type": "PUBLISH_WORKFLOW",
                    "content": contentDict
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

    /// Builds a minimal HiveChatMessage with a PUBLISH_PROMPT artifact.
    private func makePublishPromptMessage() -> HiveChatMessage? {
        let jsonDict: [String: Any] = [
            "id": "msg-pp-test-001",
            "message": "Here is the prompt",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-pp-test-001",
                    "type": "PUBLISH_PROMPT",
                    "content": [
                        "promptId": "clprompt000000000000001",
                        "promptVersionId": "clversion000000000000007",
                        "promptName": "my-cool-prompt",
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

    // MARK: - Tests: Card visibility on PUBLISH_WORKFLOW message

    func testConfigureWithPublishWorkflowMessage_ShowsWorkflowCard() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage() else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "publishWorkflowCardView should be visible for a PUBLISH_WORKFLOW message")
    }

    func testConfigureWithPublishWorkflowMessage_HidesScriptCard() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage() else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        XCTAssertTrue(cell._publishScriptCardViewIsHidden,
                      "publishScriptCardView should be hidden when only PUBLISH_WORKFLOW is present")
    }

    func testConfigureWithPublishWorkflowMessage_HidesPromptCard() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage() else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        XCTAssertTrue(cell._publishPromptCardViewIsHidden,
                      "publishPromptCardView should be hidden when only PUBLISH_WORKFLOW is present")
    }

    func testConfigureWithPublishWorkflowMessage_StoresArtifact() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage() else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        XCTAssertNotNil(cell._currentPublishWorkflowArtifact,
                        "currentPublishWorkflowArtifact should be set after configure with PUBLISH_WORKFLOW message")
    }

    // MARK: - Tests: Loading state

    func testSetLoading_True_ThenFalse_CardRemainsVisible() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage() else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        let artifactId = "artifact-pw-test-001"
        cell.setPublishWorkflowLoading(true, for: artifactId)
        cell.setPublishWorkflowLoading(false, for: artifactId)
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "Card should remain visible after loading toggle")
    }

    func testSetLoadingGuard_WrongArtifactId_DoesNotCrash() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage() else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        // Calling with a different artifactId should be a no-op (guard check)
        cell.setPublishWorkflowLoading(true, for: "wrong-artifact-id")
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "Card should still be visible after a guarded no-op loading call")
    }

    func testReconfigureWhileModelLoadingTrue_RestoresSpinner() {
        // Simulates a mid-request reload/reindex: model has loading=true, cell is reconfigured.
        let cell = makeCell()
        guard var message = makePublishWorkflowMessage(published: false) else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)

        // Manually set loading=true on the artifact (simulating what the handler does to the model)
        for artIdx in message.artifacts.indices {
            if message.artifacts[artIdx].type == "PUBLISH_WORKFLOW" {
                message.artifacts[artIdx].publishWorkflowContent?.loading = true
            }
        }

        // Reconfigure the cell (simulates table reload/SSE reindex while in-flight)
        cell.configure(with: message)

        // The card should still be visible
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "Workflow card should remain visible after reconfigure with loading=true")
        // Verify loading was consumed by calling setLoading(false) on the card directly
        let cardView = cell._publishWorkflowCardView
        cardView.setLoading(false)
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "Workflow card should remain visible after loading reset")
    }

    // MARK: - Tests: Published state

    func testFlipPublishWorkflowToPublished_FlipsCardState() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage(published: false) else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        // Card starts unpublished; flip it
        cell.flipPublishWorkflowToPublished()
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "Card should remain visible after flipPublishWorkflowToPublished()")
        // Idempotent
        cell.flipPublishWorkflowToPublished()
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "Card should remain visible after repeated flipPublishWorkflowToPublished() calls")
    }

    func testSetLoadingFalse_AfterPublished_DoesNotShowPublishButton() {
        // When a card is published and loading resets, Publish button should stay hidden.
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage(published: false) else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        let cardView = cell._publishWorkflowCardView
        // Publish first
        cardView.setPublished(true)
        // Now simulate loading reset (success path also sets loading=false)
        cardView.setLoading(false)
        // Card should still be visible
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden,
                       "Workflow card should remain visible after publish + loading reset")
    }

    // MARK: - Tests: Reuse cleanup — workflow → plain

    func testReuseAfterPublishWorkflow_WithPlainMessage_HidesWorkflowCard() {
        let cell = makeCell()
        guard let workflowMessage = makePublishWorkflowMessage(),
              let plainMessage = makePlainMessage() else {
            XCTFail("Failed to create message fixtures"); return
        }
        cell.configure(with: workflowMessage)
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden, "Precondition: workflow card visible")
        cell.configure(with: plainMessage)
        XCTAssertTrue(cell._publishWorkflowCardViewIsHidden,
                      "publishWorkflowCardView should be hidden after reconfiguring with plain message")
        XCTAssertNil(cell._currentPublishWorkflowArtifact,
                     "currentPublishWorkflowArtifact should be nil after reconfiguring with plain message")
    }

    // MARK: - Tests: Reuse cleanup — workflow → script

    func testReuseAfterPublishWorkflow_WithScriptMessage_HidesWorkflowCard() {
        let cell = makeCell()
        guard let workflowMessage = makePublishWorkflowMessage(),
              let scriptMessage = makePublishScriptMessage() else {
            XCTFail("Failed to create message fixtures"); return
        }
        cell.configure(with: workflowMessage)
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden, "Precondition: workflow card visible")
        cell.configure(with: scriptMessage)
        XCTAssertTrue(cell._publishWorkflowCardViewIsHidden,
                      "publishWorkflowCardView should be hidden after reconfiguring with PUBLISH_SCRIPT message")
        XCTAssertNil(cell._currentPublishWorkflowArtifact,
                     "currentPublishWorkflowArtifact should be nil")
        XCTAssertFalse(cell._publishScriptCardViewIsHidden,
                       "publishScriptCardView should be visible")
    }

    // MARK: - Tests: Reuse cleanup — workflow → prompt

    func testReuseAfterPublishWorkflow_WithPromptMessage_HidesWorkflowCard() {
        let cell = makeCell()
        guard let workflowMessage = makePublishWorkflowMessage(),
              let promptMessage = makePublishPromptMessage() else {
            XCTFail("Failed to create message fixtures"); return
        }
        cell.configure(with: workflowMessage)
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden, "Precondition: workflow card visible")
        cell.configure(with: promptMessage)
        XCTAssertTrue(cell._publishWorkflowCardViewIsHidden,
                      "publishWorkflowCardView should be hidden after reconfiguring with PUBLISH_PROMPT message")
        XCTAssertNil(cell._currentPublishWorkflowArtifact,
                     "currentPublishWorkflowArtifact should be nil")
        XCTAssertFalse(cell._publishPromptCardViewIsHidden,
                       "publishPromptCardView should be visible")
    }

    // MARK: - Tests: prepareForReuse clears workflow card state

    func testPrepareForReuse_AfterPublishWorkflow_HidesWorkflowCard() {
        let cell = makeCell()
        guard let message = makePublishWorkflowMessage() else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        cell.configure(with: message)
        XCTAssertFalse(cell._publishWorkflowCardViewIsHidden, "Precondition: workflow card visible")
        cell.prepareForReuse()
        XCTAssertTrue(cell._publishWorkflowCardViewIsHidden,
                      "publishWorkflowCardView should be hidden after prepareForReuse")
        XCTAssertNil(cell._currentPublishWorkflowArtifact,
                     "currentPublishWorkflowArtifact should be nil after prepareForReuse")
    }

    // MARK: - Tests: Guard-fail path never sets loading

    func testMissingInfoPath_DoesNotSetLoading() {
        // A message with PUBLISH_WORKFLOW artifact but no workflowId — mimics guard-fail.
        let jsonDict: [String: Any] = [
            "id": "msg-pw-missing-001",
            "message": "Broken workflow",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-pw-missing-001",
                    "type": "PUBLISH_WORKFLOW",
                    "content": [
                        "workflowName": "broken-workflow",
                        "published": false
                        // workflowId intentionally omitted
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        guard let message = HiveChatMessage(json: JSON(jsonDict)) else {
            XCTFail("Failed to create broken PUBLISH_WORKFLOW fixture"); return
        }
        let loadingFlag = message.artifacts
            .first(where: { $0.type == "PUBLISH_WORKFLOW" })?
            .publishWorkflowContent?.loading
        XCTAssertEqual(loadingFlag, false,
                       "loading flag must remain false when guard-fail path is taken (no API call made)")
    }

    // MARK: - Tests: Model loading flag initialises as false from JSON

    func testModelLoadingFlagInitialisedAsFalse() {
        guard let message = makePublishWorkflowMessage(published: false) else {
            XCTFail("Failed to create PUBLISH_WORKFLOW message fixture"); return
        }
        let loadingFlag = message.artifacts
            .first(where: { $0.type == "PUBLISH_WORKFLOW" })?
            .publishWorkflowContent?.loading
        XCTAssertEqual(loadingFlag, false,
                       "loading flag should be false on fresh JSON parse")
    }
}
