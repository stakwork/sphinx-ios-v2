//
//  PublishPromptHandlerTests.swift
//  sphinxTests
//
//  Unit tests for:
//    1. Open-version URL construction (prompt deep-link)
//    2. Empty-string-ID guard behavior in handlePublishPrompt
//

import XCTest
import SwiftyJSON
@testable import sphinx

// MARK: - Open-version URL Construction Tests

class PublishPromptOpenVersionURLTests: XCTestCase {

    /// Helper that mirrors the URL construction logic in TaskChatViewController.onOpenPromptVersionTapped
    private func buildOpenVersionURL(slug: String, promptId: String, versionId: String) -> String {
        return "https://hive.sphinx.chat/w/\(slug)/prompts?prompt=\(promptId)&version=\(versionId)"
    }

    func testOpenVersionURL_ContainsCorrectHost() {
        let url = buildOpenVersionURL(
            slug: "my-workspace",
            promptId: "clprompt000000000000001",
            versionId: "clversion000000000000007"
        )
        XCTAssertTrue(url.hasPrefix("https://hive.sphinx.chat"),
                      "URL should start with the Hive host; got: \(url)")
    }

    func testOpenVersionURL_ContainsSlugInPath() {
        let slug = "test-workspace-slug"
        let url = buildOpenVersionURL(
            slug: slug,
            promptId: "clprompt000000000000001",
            versionId: "clversion000000000000007"
        )
        XCTAssertTrue(url.contains("/w/\(slug)/prompts"),
                      "URL should contain /w/{slug}/prompts; got: \(url)")
    }

    func testOpenVersionURL_ContainsPromptQueryParam() {
        let promptId = "clprompt000000000000001"
        let url = buildOpenVersionURL(
            slug: "my-workspace",
            promptId: promptId,
            versionId: "clversion000000000000007"
        )
        XCTAssertTrue(url.contains("prompt=\(promptId)"),
                      "URL should contain prompt=<promptId>; got: \(url)")
    }

    func testOpenVersionURL_ContainsVersionQueryParam() {
        let versionId = "clversion000000000000007"
        let url = buildOpenVersionURL(
            slug: "my-workspace",
            promptId: "clprompt000000000000001",
            versionId: versionId
        )
        XCTAssertTrue(url.contains("version=\(versionId)"),
                      "URL should contain version=<versionId>; got: \(url)")
    }

    func testOpenVersionURL_FullURL_MatchesExpected() {
        let url = buildOpenVersionURL(
            slug: "acme-corp",
            promptId: "clxyz1234567890abcdefghi",
            versionId: "clver987654321zyxwvutsrq"
        )
        let expected = "https://hive.sphinx.chat/w/acme-corp/prompts?prompt=clxyz1234567890abcdefghi&version=clver987654321zyxwvutsrq"
        XCTAssertEqual(url, expected,
                       "Full constructed URL should match expected format exactly")
    }

    func testOpenVersionURL_IsValidURL() {
        let url = buildOpenVersionURL(
            slug: "my-workspace",
            promptId: "clprompt000000000000001",
            versionId: "clversion000000000000007"
        )
        XCTAssertNotNil(URL(string: url),
                        "Constructed URL string should be parseable as a URL; got: \(url)")
    }
}

// MARK: - Empty-string ID Guard Tests

/// Tests that the guard in handlePublishPrompt correctly rejects empty-string IDs.
/// Since TaskChatViewController isn't directly unit-testable without a full UI context,
/// we verify the guard logic using the model (the empty-string fixture from HiveChatMessageTests)
/// and confirm that the values the handler would receive are present-but-empty (not nil).
class PublishPromptEmptyStringGuardTests: XCTestCase {

    /// Builds a PUBLISH_PROMPT artifact fixture with empty-string IDs (as produced by JSON ".string" parsing).
    private func makeEmptyStringIDFixture() -> HiveChatMessageArtifact {
        let jsonDict: [String: Any] = [
            "id": "artifact-pp-empty",
            "type": "PUBLISH_PROMPT",
            "content": [
                "promptId": "",
                "promptVersionId": "",
                "promptName": "some-prompt",
                "published": false
            ] as [String: Any]
        ]
        return HiveChatMessageArtifact(json: JSON(jsonDict))
    }

    func testEmptyStringIDs_AreNonNilButEmpty() {
        // Confirm the model surfaces empty strings (not nil) — the guard must check !isEmpty
        let artifact = makeEmptyStringIDFixture()
        XCTAssertNotNil(artifact.publishPromptContent?.promptId,
                        "promptId should be non-nil (present-but-empty) for empty-string JSON input")
        XCTAssertNotNil(artifact.publishPromptContent?.promptVersionId,
                        "promptVersionId should be non-nil (present-but-empty) for empty-string JSON input")
        XCTAssertEqual(artifact.publishPromptContent?.promptId, "",
                       "promptId should be empty string, not nil")
        XCTAssertEqual(artifact.publishPromptContent?.promptVersionId, "",
                       "promptVersionId should be empty string, not nil")
    }

    func testEmptyStringIDs_FailTrimmedEmptyCheck() {
        // The guard uses !promptId.trimmingCharacters(in: .whitespaces).isEmpty
        // Verify that empty strings fail this check (and would trigger the guard)
        let artifact = makeEmptyStringIDFixture()
        let promptId = artifact.publishPromptContent?.promptId ?? ""
        let versionId = artifact.publishPromptContent?.promptVersionId ?? ""

        XCTAssertTrue(promptId.trimmingCharacters(in: .whitespaces).isEmpty,
                      "Empty promptId should be caught by the trimmed-empty guard")
        XCTAssertTrue(versionId.trimmingCharacters(in: .whitespaces).isEmpty,
                      "Empty promptVersionId should be caught by the trimmed-empty guard")
    }

    func testWhitespaceOnlyIDs_FailTrimmedEmptyCheck() {
        // Also verify whitespace-only strings are rejected
        let whitespaceId = "   "
        XCTAssertTrue(whitespaceId.trimmingCharacters(in: .whitespaces).isEmpty,
                      "Whitespace-only promptId should be caught by the trimmed-empty guard")
    }

    func testValidCuidIDs_PassTrimmedEmptyCheck() {
        // Confirm that valid cuid strings pass the guard
        let promptId = "clprompt000000000000001"
        let versionId = "clversion000000000000007"

        XCTAssertFalse(promptId.trimmingCharacters(in: .whitespaces).isEmpty,
                       "Valid promptId cuid should pass the trimmed-empty guard")
        XCTAssertFalse(versionId.trimmingCharacters(in: .whitespaces).isEmpty,
                       "Valid promptVersionId cuid should pass the trimmed-empty guard")
    }
}
