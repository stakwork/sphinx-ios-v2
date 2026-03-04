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
        XCTAssertEqual(capturedAnswers[0], "Q1: iOS")
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

        XCTAssertEqual(capturedAnswers[0], "Q1: B")
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

        XCTAssertEqual(capturedAnswers[0], "Q1: X, Z")
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
        XCTAssertEqual(capturedAnswers[0], "Q1: Y")
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
        XCTAssertEqual(capturedAnswers[0], "Q1: B")
        XCTAssertEqual(capturedAnswers[1], "Q2: X, Z")
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

    /// Recursively find all views of a given type.
    private func allSubviews<T: UIView>(ofType type: T.Type, in view: UIView) -> [T] {
        var result: [T] = []
        for sub in view.subviews {
            if let match = sub as? T { result.append(match) }
            result.append(contentsOf: allSubviews(ofType: type, in: sub))
        }
        return result
    }

    /// Simulate a tap on the option button at the given index (test-only).
    func simulateTapOption(at index: Int) {
        // Option buttons are UIButtons with matching tag; they are NOT the action button
        // (action button has no tag set explicitly, defaulting to 0 — we identify it by title)
        let actionTitles: Set<String> = ["Next →", "Submit"]
        let allButtons = allSubviews(ofType: UIButton.self, in: self)
        let optionButtons = allButtons.filter { btn in
            guard let title = btn.title(for: .normal) else { return false }
            return !actionTitles.contains(title)
        }
        // Sort by tag order to match the original option index
        let sorted = optionButtons.sorted { $0.tag < $1.tag }
        guard index < sorted.count else { return }
        sorted[index].sendActions(for: .touchUpInside)
    }

    /// Simulate a tap on the action button (Next → / Submit) (test-only).
    func simulateTapActionButton() {
        let actionTitles: Set<String> = ["Next →", "Submit"]
        let allButtons = allSubviews(ofType: UIButton.self, in: self)
        guard let btn = allButtons.first(where: { btn in
            guard let title = btn.title(for: .normal) else { return false }
            return actionTitles.contains(title)
        }) else { return }
        btn.sendActions(for: .touchUpInside)
    }
}
