//
//  ClarifyingQuestionsTests.swift
//  sphinxTests
//
//  Unit tests for ClarifyingQuestionsView, ClarifyingQuestion model,
//  and related answer-formatting behaviour.
//

import XCTest
import SwiftyJSON
@testable import sphinx

// MARK: - ClarifyingQuestion Model Tests

class ClarifyingQuestionParsingTests: XCTestCase {

    func testClarifyingQuestion_ParsedFromJSON_ReturnsCorrectFields() {
        let json = JSON([
            "id": "artifact-001",
            "type": "PLAN",
            "content": [
                "tool_use": "ask_clarifying_questions",
                "content": [
                    [
                        "question": "Which platform?",
                        "options": ["iOS", "Android", "Both"],
                        "type": "single_choice"
                    ]
                ] as [[String: Any]]
            ] as [String: Any]
        ])

        let artifact = HiveChatMessageArtifact(json: json)
        XCTAssertTrue(artifact.isClarifyingQuestions, "isClarifyingQuestions should be true")
        XCTAssertNotNil(artifact.clarifyingQuestions, "clarifyingQuestions should not be nil")

        let questions = artifact.clarifyingQuestions!
        XCTAssertEqual(questions.count, 1)

        let q = questions[0]
        XCTAssertEqual(q.question, "Which platform?")
        XCTAssertEqual(q.options, ["iOS", "Android", "Both"])
        XCTAssertEqual(q.type, "single_choice")
    }

    func testClarifyingQuestion_ParsedFromJSON_MultipleQuestions() {
        let json = JSON([
            "id": "artifact-002",
            "type": "PLAN",
            "content": [
                "tool_use": "ask_clarifying_questions",
                "content": [
                    ["question": "Q1", "options": ["A", "B"], "type": "single_choice"],
                    ["question": "Q2", "options": ["X", "Y", "Z"], "type": "multiple_choice"]
                ] as [[String: Any]]
            ] as [String: Any]
        ])

        let artifact = HiveChatMessageArtifact(json: json)
        XCTAssertTrue(artifact.isClarifyingQuestions)
        XCTAssertEqual(artifact.clarifyingQuestions?.count, 2)
        XCTAssertEqual(artifact.clarifyingQuestions?[1].type, "multiple_choice")
    }

    func testClarifyingQuestion_NonClarifyingPlan_ReturnsFalse() {
        let json = JSON([
            "id": "artifact-003",
            "type": "PLAN",
            "content": [
                "tool_use": "generate_plan",
                "content": "Some plan text"
            ] as [String: Any]
        ])

        let artifact = HiveChatMessageArtifact(json: json)
        XCTAssertFalse(artifact.isClarifyingQuestions, "Non-clarifying PLAN should return false")
        XCTAssertNil(artifact.clarifyingQuestions)
    }

    func testClarifyingQuestion_PullRequestArtifact_ReturnsFalse() {
        let json = JSON([
            "id": "artifact-pr",
            "type": "PULL_REQUEST",
            "content": [
                "repo": "org/repo",
                "url": "https://github.com/org/repo/pull/1",
                "status": "open",
                "number": 1,
                "title": "My PR"
            ] as [String: Any]
        ])

        let artifact = HiveChatMessageArtifact(json: json)
        XCTAssertFalse(artifact.isClarifyingQuestions)
        XCTAssertNil(artifact.clarifyingQuestions)
    }

    func testClarifyingQuestion_MissingOptions_ParsesPartially() {
        let json = JSON([
            "id": "artifact-004",
            "type": "PLAN",
            "content": [
                "tool_use": "ask_clarifying_questions",
                "content": [
                    ["question": "Valid Q", "options": ["A", "B"], "type": "single_choice"],
                    // Missing "question" key — should be skipped by compactMap
                    ["options": ["X"], "type": "single_choice"]
                ] as [[String: Any]]
            ] as [String: Any]
        ])

        let artifact = HiveChatMessageArtifact(json: json)
        XCTAssertTrue(artifact.isClarifyingQuestions)
        // Only the valid question survives compactMap
        XCTAssertEqual(artifact.clarifyingQuestions?.count, 1)
    }
}

// MARK: - ClarifyingQuestionsView Behaviour Tests

class ClarifyingQuestionsViewTests: XCTestCase {

    private func makeView(questions: [ClarifyingQuestion]) -> ClarifyingQuestionsView {
        let view = ClarifyingQuestionsView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        view.configure(with: questions)
        return view
    }

    private func singleChoiceQuestion(options: [String] = ["A", "B", "C"]) -> ClarifyingQuestion {
        ClarifyingQuestion(question: "Pick one", options: options, type: "single_choice")
    }

    private func multiChoiceQuestion(options: [String] = ["X", "Y", "Z"]) -> ClarifyingQuestion {
        ClarifyingQuestion(question: "Pick many", options: options, type: "multiple_choice")
    }

    // MARK: - configure / reset

    func testConfigure_SetsUpInitialState() {
        let view = makeView(questions: [singleChoiceQuestion()])
        // View should be interactive and fully visible after configure
        XCTAssertTrue(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 1.0)
    }

    func testReset_ClearsState() {
        let view = makeView(questions: [singleChoiceQuestion(), multiChoiceQuestion()])
        view.reset()
        // After reset, interaction remains enabled and alpha is 1
        XCTAssertTrue(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 1.0)
    }

    // MARK: - lock()

    func testLock_DisablesInteractionAndDimsView() {
        let view = makeView(questions: [singleChoiceQuestion()])
        view.lock()
        XCTAssertFalse(view.isUserInteractionEnabled, "lock() should disable interaction")
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.001, "lock() should set alpha to 0.5")
    }

    func testLockThenReset_RestoresInteraction() {
        let view = makeView(questions: [singleChoiceQuestion()])
        view.lock()
        view.reset()
        XCTAssertTrue(view.isUserInteractionEnabled, "reset() should re-enable interaction")
        XCTAssertEqual(view.alpha, 1.0, accuracy: 0.001)
    }

    // MARK: - Answer formatting helpers

    func testAnswerFormat_SingleChoice() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = ClarifyingQuestion(question: "Platform?", options: ["iOS", "Android"], type: "single_choice")
        view.configure(with: [q])

        // Simulate tapping option at index 0 ("iOS") then Submit
        view.simulateTapOption(at: 0)
        view.simulateTapActionButton()

        XCTAssertEqual(capturedAnswers.count, 1)
        XCTAssertEqual(capturedAnswers[0], "Q: Platform?\nA: iOS")
    }

    func testAnswerFormat_SingleChoice_ReselectOverridesFirst() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = singleChoiceQuestion(options: ["A", "B", "C"])
        view.configure(with: [q])

        // Select A, then B — B should replace A
        view.simulateTapOption(at: 0)
        view.simulateTapOption(at: 1)
        view.simulateTapActionButton()

        XCTAssertEqual(capturedAnswers[0], "Q: Pick one\nA: B")
    }

    // MARK: - single_choice deselection (toggle)

    func testSingleChoice_TappingSameOptionDeselects() {
        let view = ClarifyingQuestionsView()
        let q = singleChoiceQuestion(options: ["A", "B", "C"])
        view.configure(with: [q])

        // Select option 0, then tap it again — should deselect
        view.simulateTapOption(at: 0)
        view.simulateTapOption(at: 0)

        // Action button should be disabled (no selection) — verify by checking selectedIndices is empty
        // We do this indirectly: simulateTapActionButton with no selection should not fire onSubmit
        var submitFired = false
        view.onSubmit = { _ in submitFired = true }
        view.simulateTapActionButton()
        XCTAssertFalse(submitFired, "Action button should be disabled when no option is selected after deselect")
    }

    func testSingleChoice_SelectingOptionSetsSelection() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = singleChoiceQuestion(options: ["A", "B", "C"])
        view.configure(with: [q])

        // Tap option 1 once — should be selected
        view.simulateTapOption(at: 1)
        view.simulateTapActionButton()

        XCTAssertEqual(capturedAnswers.count, 1)
        XCTAssertEqual(capturedAnswers[0], "Q: Pick one\nA: B")
    }

    func testSingleChoice_TappingDifferentOptionReplacesSelection() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = singleChoiceQuestion(options: ["A", "B", "C"])
        view.configure(with: [q])

        // Tap A, then C — C should be the final selection
        view.simulateTapOption(at: 0)
        view.simulateTapOption(at: 2)
        view.simulateTapActionButton()

        XCTAssertEqual(capturedAnswers[0], "Q: Pick one\nA: C")
    }

    func testSingleChoice_DeselectThenReselectWorks() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = singleChoiceQuestion(options: ["A", "B", "C"])
        view.configure(with: [q])

        // Select A, deselect A, select B — B should be submitted
        view.simulateTapOption(at: 0) // select A
        view.simulateTapOption(at: 0) // deselect A
        view.simulateTapOption(at: 1) // select B
        view.simulateTapActionButton()

        XCTAssertEqual(capturedAnswers[0], "Q: Pick one\nA: B")
    }

    func testAnswerFormat_MultipleChoice_CanSelectSeveral() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = multiChoiceQuestion(options: ["X", "Y", "Z"])
        view.configure(with: [q])

        view.simulateTapOption(at: 0) // X
        view.simulateTapOption(at: 2) // Z
        view.simulateTapActionButton()

        XCTAssertEqual(capturedAnswers[0], "Q: Pick many\nA: X, Z")
    }

    func testAnswerFormat_MultipleChoice_DeselectionWorks() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = multiChoiceQuestion(options: ["X", "Y", "Z"])
        view.configure(with: [q])

        view.simulateTapOption(at: 0) // X selected
        view.simulateTapOption(at: 1) // Y selected
        view.simulateTapOption(at: 0) // X deselected
        view.simulateTapActionButton()

        // Only Y should remain
        XCTAssertEqual(capturedAnswers[0], "Q: Pick many\nA: Y")
    }

    func testAnswerFormat_MultiQuestion_AllAnswersCollected() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q1 = ClarifyingQuestion(question: "Q1", options: ["A", "B"], type: "single_choice")
        let q2 = ClarifyingQuestion(question: "Q2", options: ["X", "Y", "Z"], type: "multiple_choice")
        view.configure(with: [q1, q2])

        // Answer Q1 and advance
        view.simulateTapOption(at: 1) // B
        view.simulateTapActionButton() // Next

        // Answer Q2 and submit
        view.simulateTapOption(at: 0) // X
        view.simulateTapOption(at: 2) // Z
        view.simulateTapActionButton() // Submit

        XCTAssertEqual(capturedAnswers.count, 2)
        XCTAssertEqual(capturedAnswers[0], "Q: Q1\nA: B")
        XCTAssertEqual(capturedAnswers[1], "Q: Q2\nA: X, Z")
    }

    // MARK: - Additional context capture

    func testAdditionalContext_NonFinalQuestion_IncludedInAnswerString() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q1 = ClarifyingQuestion(question: "Q1", options: ["A", "B"], type: "single_choice")
        let q2 = ClarifyingQuestion(question: "Q2", options: ["X", "Y"], type: "single_choice")
        view.configure(with: [q1, q2])

        // Select an option on Q1, type context, then advance
        view.simulateTapOption(at: 0) // A
        view.simulateTypeAdditionalContext("some extra info")
        view.simulateTapActionButton() // Next

        // Answer Q2 and submit (no extra context)
        view.simulateTapOption(at: 1) // Y
        view.simulateTapActionButton() // Submit

        XCTAssertEqual(capturedAnswers.count, 2)
        XCTAssertEqual(capturedAnswers[0], "Q: Q1\nA: A, some extra info",
                       "Context on a non-final question must be in that question's answer string")
        XCTAssertEqual(capturedAnswers[1], "Q: Q2\nA: Y")
    }

    func testAdditionalContext_FinalQuestion_IncludedInAnswerString() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = ClarifyingQuestion(question: "Platform?", options: ["iOS", "Android"], type: "single_choice")
        view.configure(with: [q])

        view.simulateTapOption(at: 0) // iOS
        view.simulateTypeAdditionalContext("prefer SwiftUI")
        view.simulateTapActionButton() // Submit

        XCTAssertEqual(capturedAnswers.count, 1)
        XCTAssertEqual(capturedAnswers[0], "Q: Platform?\nA: iOS, prefer SwiftUI",
                       "Context on the final question must be embedded in the answer string")
    }

    // MARK: - New answer format

    func testAnswerFormat_NewFormat_SingleChoice() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q = ClarifyingQuestion(question: "Platform?", options: ["iOS", "Android"], type: "single_choice")
        view.configure(with: [q])

        view.simulateTapOption(at: 0) // iOS
        view.simulateTapActionButton()

        XCTAssertEqual(capturedAnswers.count, 1)
        XCTAssertEqual(capturedAnswers[0], "Q: Platform?\nA: iOS")
    }

    func testAnswerFormat_NewFormat_MultiQuestion() {
        var capturedAnswers: [String] = []
        let view = ClarifyingQuestionsView()
        view.onSubmit = { capturedAnswers = $0 }

        let q1 = ClarifyingQuestion(question: "Platform?", options: ["iOS", "Android"], type: "single_choice")
        let q2 = ClarifyingQuestion(question: "Approach?", options: ["SwiftUI", "UIKit"], type: "single_choice")
        view.configure(with: [q1, q2])

        view.simulateTapOption(at: 0)
        view.simulateTapActionButton() // Next
        view.simulateTapOption(at: 1)
        view.simulateTapActionButton() // Submit

        XCTAssertEqual(capturedAnswers[0], "Q: Platform?\nA: iOS")
        XCTAssertEqual(capturedAnswers[1], "Q: Approach?\nA: UIKit")
    }

    // MARK: - configureAnswered tests

    func testConfigureAnswered_HighlightsCorrectOptions() {
        let view = ClarifyingQuestionsView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let q = ClarifyingQuestion(question: "Platform?", options: ["iOS", "Android", "Both"], type: "single_choice")
        let answerText = "Q: Platform?\nA: iOS"
        view.configureAnswered(questions: [q], answerText: answerText)

        // View should be non-interactive (answered state)
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 1.0, accuracy: 0.001)
    }

    func testConfigureAnswered_ShowsAdditionalTextLabel() {
        let view = ClarifyingQuestionsView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let q = ClarifyingQuestion(question: "Platform?", options: ["iOS", "Android"], type: "single_choice")
        let answerText = "Q: Platform?\nA: iOS, some extra context"
        view.configureAnswered(questions: [q], answerText: answerText)

        let label = view.additionalContextLabelForTesting
        XCTAssertNotNil(label)
        XCTAssertFalse(label!.isHidden, "additionalContextLabel should be visible when additional text is present")
        XCTAssertEqual(label!.text, "some extra context")
    }

    func testConfigureAnswered_HidesAdditionalTextLabelWhenEmpty() {
        let view = ClarifyingQuestionsView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let q = ClarifyingQuestion(question: "Platform?", options: ["iOS", "Android"], type: "single_choice")
        let answerText = "Q: Platform?\nA: iOS"
        view.configureAnswered(questions: [q], answerText: answerText)

        let label = view.additionalContextLabelForTesting
        XCTAssertNotNil(label)
        XCTAssertTrue(label!.isHidden, "additionalContextLabel should be hidden when no additional text")
    }

    func testConfigureAnswered_PrevDisabledOnFirstQuestion() {
        let view = ClarifyingQuestionsView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let q1 = ClarifyingQuestion(question: "Q1", options: ["A", "B"], type: "single_choice")
        let q2 = ClarifyingQuestion(question: "Q2", options: ["X", "Y"], type: "single_choice")
        let answerText = "Q: Q1\nA: A\n\nQ: Q2\nA: X"
        view.configureAnswered(questions: [q1, q2], answerText: answerText)

        XCTAssertFalse(view.prevButtonForTesting?.isEnabled ?? true,
                       "Prev button should be disabled on first question")
    }

    func testConfigureAnswered_NextDisabledOnLastQuestion() {
        let view = ClarifyingQuestionsView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let q = ClarifyingQuestion(question: "Q1", options: ["A", "B"], type: "single_choice")
        let answerText = "Q: Q1\nA: A"
        view.configureAnswered(questions: [q], answerText: answerText)

        XCTAssertFalse(view.nextButtonForTesting?.isEnabled ?? true,
                       "Next button should be disabled on last question (only one question)")
    }

    func testConfigureAnswered_NavigationAdvancesQuestion() {
        let view = ClarifyingQuestionsView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let q1 = ClarifyingQuestion(question: "Q1", options: ["A", "B"], type: "single_choice")
        let q2 = ClarifyingQuestion(question: "Q2", options: ["X", "Y"], type: "single_choice")
        let answerText = "Q: Q1\nA: A\n\nQ: Q2\nA: X"
        view.configureAnswered(questions: [q1, q2], answerText: answerText)

        view.simulateTapNext()

        XCTAssertEqual(view.counterLabelForTesting?.text, "2 of 2",
                       "Counter label should update to '2 of 2' after tapping Next")
    }

    func testConfigureAnswered_DashStripping() {
        let view = ClarifyingQuestionsView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let option = "Reuse FEATURE_UPDATED \u{2014} fires multiple times"
        let q = ClarifyingQuestion(question: "Event type?", options: [option, "Other"], type: "single_choice")
        // Answer token has em-dash stripped
        let answerText = "Q: Event type?\nA: Reuse FEATURE_UPDATED  fires multiple times"
        view.configureAnswered(questions: [q], answerText: answerText)

        // The view should be in answered state (non-interactive) without crashing
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 1.0, accuracy: 0.001)
    }

    // MARK: - onSubmit callback

    func testOnSubmit_NotFiredOnNext() {
        var submitCount = 0
        let view = ClarifyingQuestionsView()
        view.onSubmit = { _ in submitCount += 1 }

        let q1 = ClarifyingQuestion(question: "Q1", options: ["A"], type: "single_choice")
        let q2 = ClarifyingQuestion(question: "Q2", options: ["B"], type: "single_choice")
        view.configure(with: [q1, q2])

        view.simulateTapOption(at: 0)
        view.simulateTapActionButton() // Next — should not fire onSubmit

        XCTAssertEqual(submitCount, 0, "onSubmit should not fire when moving to next question")
    }

    func testOnSubmit_FiredOnFinalSubmit() {
        var submitCount = 0
        let view = ClarifyingQuestionsView()
        view.onSubmit = { _ in submitCount += 1 }

        let q = singleChoiceQuestion()
        view.configure(with: [q])

        view.simulateTapOption(at: 0)
        view.simulateTapActionButton() // Submit

        XCTAssertEqual(submitCount, 1, "onSubmit should fire exactly once on Submit")
    }

    // MARK: - Mock data integration

    func testMockConversation_ContainsClarifyingQuestionsMessage() {
        let messages = HiveChatMessage.mockConversation()
        let cqMessage = messages.first { msg in
            msg.artifacts.contains { $0.isClarifyingQuestions }
        }
        XCTAssertNotNil(cqMessage, "Mock conversation should contain a clarifying questions message")
        let artifact = cqMessage!.artifacts.first { $0.isClarifyingQuestions }!
        XCTAssertEqual(artifact.clarifyingQuestions?.count, 3)
    }
}

// MARK: - Test Helpers (internal testing hooks on ClarifyingQuestionsView)

extension ClarifyingQuestionsView {

    /// Simulate a tap on the option view at the given index (test-only).
    /// Options are UIViews in optionsStackView with UITapGestureRecognizer attached.
    func simulateTapOption(at index: Int) {
        selectOptionForTesting(at: index)
    }

    /// Simulate a tap on the action button (Next → / Submit) (test-only).
    func simulateTapActionButton() {
        actionButtonForTesting?.sendActions(for: .touchUpInside)
    }

    /// Simulate a tap on the Prev button (test-only).
    func simulateTapPrev() {
        prevButtonForTesting?.sendActions(for: .touchUpInside)
    }

    /// Simulate a tap on the Next button (test-only).
    func simulateTapNext() {
        nextButtonForTesting?.sendActions(for: .touchUpInside)
    }

    /// Simulate typing text into the additional context text view (test-only).
    func simulateTypeAdditionalContext(_ text: String) {
        guard let tv = additionalContextTextViewForTesting else { return }
        tv.text = text
        // Manually invoke the delegate so internal state (placeholder, button enable) updates
        tv.delegate?.textViewDidChange?(tv)
    }
}
