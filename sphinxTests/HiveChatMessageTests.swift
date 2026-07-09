import XCTest
import SwiftyJSON
@testable import sphinx

class HiveChatMessageTests: XCTestCase {
    
    // MARK: - JSON Parsing Tests
    
    func testHiveChatMessage_InitWithCompleteJSON() {
        let jsonDict: [String: Any] = [
            "id": "msg-123",
            "message": "Let's build a chat feature with WebSocket support",
            "role": "user",
            "createdAt": "2024-01-20T15:30:00Z"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNotNil(chatMessage, "HiveChatMessage should initialize with complete JSON")
        XCTAssertEqual(chatMessage?.id, "msg-123")
        XCTAssertEqual(chatMessage?.message, "Let's build a chat feature with WebSocket support")
        XCTAssertEqual(chatMessage?.role, "user")
        XCTAssertEqual(chatMessage?.createdAt, "2024-01-20T15:30:00Z")
    }
    
    func testHiveChatMessage_InitWithMinimalJSON() {
        let jsonDict: [String: Any] = [
            "id": "msg-456",
            "message": "Great idea! Here's the architecture...",
            "role": "assistant"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNotNil(chatMessage, "HiveChatMessage should initialize with minimal JSON")
        XCTAssertEqual(chatMessage?.id, "msg-456")
        XCTAssertEqual(chatMessage?.message, "Great idea! Here's the architecture...")
        XCTAssertEqual(chatMessage?.role, "assistant")
        XCTAssertNil(chatMessage?.createdAt)
    }
    
    func testHiveChatMessage_InitWithMissingId_ReturnsNil() {
        let jsonDict: [String: Any] = [
            "message": "Missing ID message",
            "role": "user"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNil(chatMessage, "HiveChatMessage should return nil when id is missing")
    }
    
    func testHiveChatMessage_InitWithMissingMessage_ReturnsNil() {
        let jsonDict: [String: Any] = [
            "id": "msg-789",
            "role": "user"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNil(chatMessage, "HiveChatMessage should return nil when message is missing")
    }
    
    func testHiveChatMessage_InitWithMissingRole_ReturnsNil() {
        let jsonDict: [String: Any] = [
            "id": "msg-999",
            "message": "Missing role message"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNil(chatMessage, "HiveChatMessage should return nil when role is missing")
    }
    
    func testHiveChatMessage_InitWithEmptyJSON_ReturnsNil() {
        let json = JSON([:])
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNil(chatMessage, "HiveChatMessage should return nil with empty JSON")
    }
    
    // MARK: - Role Tests
    
    func testHiveChatMessage_Role_User() {
        let jsonDict: [String: Any] = [
            "id": "msg-user",
            "message": "User message",
            "role": "user"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertEqual(chatMessage?.role, "user")
    }
    
    func testHiveChatMessage_Role_Assistant() {
        let jsonDict: [String: Any] = [
            "id": "msg-assistant",
            "message": "AI response",
            "role": "assistant"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertEqual(chatMessage?.role, "assistant")
    }
    
    // MARK: - Message Content Tests
    
    func testHiveChatMessage_LongMessage() {
        let longMessage = String(repeating: "This is a long message. ", count: 50)
        let jsonDict: [String: Any] = [
            "id": "msg-long",
            "message": longMessage,
            "role": "assistant"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.message, longMessage)
    }
    
    func testHiveChatMessage_MessageWithSpecialCharacters() {
        let specialMessage = "Code example:\n```swift\nfunc hello() {\n    print(\"Hello, World!\")\n}\n```"
        let jsonDict: [String: Any] = [
            "id": "msg-special",
            "message": specialMessage,
            "role": "assistant"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNotNil(chatMessage)
        XCTAssertEqual(chatMessage?.message, specialMessage)
    }
    
    func testHiveChatMessage_EmptyMessage_ReturnsNil() {
        let jsonDict: [String: Any] = [
            "id": "msg-empty",
            "message": "",
            "role": "user"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        // Empty message should still be valid if that's what the API returns
        // But based on the init logic, empty strings would pass the `string` check
        XCTAssertNotNil(chatMessage, "HiveChatMessage can have empty message if API returns it")
    }
    
    // MARK: - Mock Data Tests
    
    func testHiveChatMessage_MockConversation_ReturnsMultipleMessages() {
        let mockMessages = HiveChatMessage.mockConversation()
        
        XCTAssertGreaterThanOrEqual(mockMessages.count, 4, "Mock conversation should contain at least 4 messages")
    }
    
    func testHiveChatMessage_MockConversation_ContainsBothRoles() {
        let mockMessages = HiveChatMessage.mockConversation()
        
        let rolesLowercased = mockMessages.map { $0.role.lowercased() }
        
        XCTAssertTrue(rolesLowercased.contains("user"), "Mock conversation should contain user messages")
        XCTAssertTrue(rolesLowercased.contains("assistant"), "Mock conversation should contain assistant messages")
        
        let roles = mockMessages.map { $0.role.uppercased() }
        
        XCTAssertTrue(roles.contains("USER"), "Mock conversation should contain user messages")
        XCTAssertTrue(roles.contains("ASSISTANT"), "Mock conversation should contain assistant messages")
    }
    
    func testHiveChatMessage_MockConversation_AllMessagesHaveRequiredFields() {
        let mockMessages = HiveChatMessage.mockConversation()
        
        for message in mockMessages {
            XCTAssertFalse(message.id.isEmpty, "Mock message should have non-empty id")
            XCTAssertFalse(message.role.isEmpty, "Mock message should have non-empty role")

            let roleLower = message.role.lowercased()
            XCTAssertTrue(roleLower == "user" || roleLower == "assistant",
                          "Mock message role should be either 'user' or 'assistant' (case-insensitive), got: \(message.role)")
            // Messages may have empty text if they carry artifacts (e.g. clarifying questions)
            if message.artifacts.isEmpty {
                XCTAssertFalse(message.message.isEmpty, "Mock message with no artifacts should have non-empty message text")
            }
            // resolvedDisplayText must be non-empty for every mock message
            XCTAssertFalse(
                message.resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Mock message \(message.id) should have non-empty resolvedDisplayText"
            )
        }
    }
    
    func testHiveChatMessage_MockConversation_ContainsPlanContent() {
        let mockMessages = HiveChatMessage.mockConversation()
        
        let allMessagesText = mockMessages.map { $0.resolvedDisplayText }.joined(separator: " ").lowercased()
        
        // Verify mock conversation discusses technical planning topics
        XCTAssertTrue(
            allMessagesText.contains("architecture") ||
            allMessagesText.contains("requirements") ||
            allMessagesText.contains("feature") ||
            allMessagesText.contains("implementation"),
            "Mock conversation should contain plan-related content"
        )
    }

    // MARK: - LONGFORM Artifact Tests

    func testArtifact_LongformType_PopulatesLongformContent() {
        let jsonDict: [String: Any] = [
            "id": "artifact-001",
            "type": "LONGFORM",
            "content": [
                "title": "Agent",
                "text": "There was an error creating pull request."
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isLongform, "Artifact with type LONGFORM should have isLongform == true")
        XCTAssertNotNil(artifact.longformContent, "LONGFORM artifact should have longformContent populated")
        XCTAssertEqual(artifact.longformContent?.title, "Agent")
        XCTAssertEqual(artifact.longformContent?.text, "There was an error creating pull request.")
        XCTAssertNil(artifact.prContent, "LONGFORM artifact should not populate prContent")
        XCTAssertNil(artifact.content, "LONGFORM artifact should not populate plain content string")
    }

    func testArtifact_LongformType_MissingTitle_PopulatesTextOnly() {
        let jsonDict: [String: Any] = [
            "id": "artifact-002",
            "type": "LONGFORM",
            "content": ["text": "Some text without a title"] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isLongform)
        XCTAssertNil(artifact.longformContent?.title)
        XCTAssertEqual(artifact.longformContent?.text, "Some text without a title")
    }

    func testResolvedDisplayText_WithEmptyMessageAndLongformArtifact_ReturnsTitleAndText() {
        let jsonDict: [String: Any] = [
            "id": "msg-lf-001",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-001",
                    "type": "LONGFORM",
                    "content": [
                        "title": "Agent",
                        "text": "Cannot create PR."
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.resolvedDisplayText, "**Agent**\n\nCannot create PR.")
    }

    func testResolvedDisplayText_WithNonEmptyMessage_IgnoresLongformArtifact() {
        let jsonDict: [String: Any] = [
            "id": "msg-lf-002",
            "message": "Regular message text",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-001",
                    "type": "LONGFORM",
                    "content": [
                        "title": "Agent",
                        "text": "Should be ignored."
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.resolvedDisplayText, "Regular message text")
    }

    func testResolvedDisplayText_LongformArtifactWithNoTitle_ReturnsTextOnly() {
        let jsonDict: [String: Any] = [
            "id": "msg-lf-003",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-001",
                    "type": "LONGFORM",
                    "content": ["text": "Only text, no title."] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.resolvedDisplayText, "Only text, no title.")
    }

    func testIsLongformMessage_TrueWhenEmptyMessageAndLongformArtifact() {
        let jsonDict: [String: Any] = [
            "id": "msg-lf-004",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-001",
                    "type": "LONGFORM",
                    "content": ["title": "T", "text": "Text."] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.isLongformMessage == true)
    }

    func testIsLongformMessage_FalseWhenMessageIsNonEmpty() {
        let jsonDict: [String: Any] = [
            "id": "msg-lf-005",
            "message": "Has content",
            "role": "USER",
            "artifacts": [] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))

        XCTAssertNotNil(message)
        XCTAssertFalse(message?.isLongformMessage == true)
    }

    func testIsLongformMessage_FalseWhenNoLongformArtifact() {
        let jsonDict: [String: Any] = [
            "id": "msg-lf-006",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))

        XCTAssertNotNil(message)
        XCTAssertFalse(message?.isLongformMessage == true)
    }

    func testMockConversation_ContainsLongformMessage() {
        let mockMessages = HiveChatMessage.mockConversation()
        let longformMessage = mockMessages.first(where: { $0.isLongformMessage })

        XCTAssertNotNil(longformMessage, "mockConversation() should include a LONGFORM message")
        XCTAssertFalse(
            longformMessage?.resolvedDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
            "LONGFORM mock message resolvedDisplayText should be non-empty"
        )
    }

    // MARK: - isDisplayable Tests

    func testIsDisplayable_EmptyMessageNoAttachmentsNoArtifacts_ReturnsFalse() {
        let jsonDict: [String: Any] = [
            "id": "disp-001",
            "message": "",
            "role": "ASSISTANT"
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertFalse(message?.isDisplayable == true)
    }

    func testIsDisplayable_EmptyMessageStreamOnlyArtifact_ReturnsFalse() {
        let jsonDict: [String: Any] = [
            "id": "disp-002",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "art-001",
                    "type": "STREAM",
                    "content": ["text": "streaming..."] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertFalse(message?.isDisplayable == true)
    }

    func testIsDisplayable_NonEmptyMessage_ReturnsTrue() {
        let jsonDict: [String: Any] = [
            "id": "disp-003",
            "message": "Hello world",
            "role": "USER"
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.isDisplayable == true)
    }

    func testIsDisplayable_EmptyMessageWithAttachment_ReturnsTrue() {
        let jsonDict: [String: Any] = [
            "id": "disp-004",
            "message": "",
            "role": "USER",
            "attachments": [
                ["url": "https://example.com/image.png", "type": "image/png"] as [String: Any]
            ] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.isDisplayable == true)
    }

    func testIsDisplayable_StreamOnlyMessageWithPopulatedStreamInfo_ReturnsFalse() {
        // Mirrors the exact production JSON shape that caused the floating date label bug
        let jsonDict: [String: Any] = [
            "id": "cmn6azsay00wzla04etinu52o",
            "featureId": "cmn6azn2w0004lb04dzrjpacs",
            "message": "",
            "role": "ASSISTANT",
            "status": "SENT",
            "createdAt": "2026-03-25T17:14:26.698Z",
            "artifacts": [
                [
                    "id": "cmn6azsay00x0la048u667cak",
                    "type": "STREAM",
                    "content": [
                        "requestId": "9224f8c3-b7dd-49a0-a049-1f87577a664a",
                        "eventsToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test",
                        "baseUrl": "https://swarmW6qeCC.sphinx.chat:3355"
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        // isDisplayable must be false so fetchChatHistory excludes it from self.messages
        XCTAssertFalse(message!.isDisplayable)
        // Confirm streamInfo IS decoded — SSE connection should still work
        XCTAssertNotNil(message!.artifacts.first?.streamInfo)
    }

    // MARK: - taskId Decoding Tests

    func testHiveChatMessage_TaskId_DecodedWhenPresent() {
        let jsonDict: [String: Any] = [
            "id": "msg-task-001",
            "message": "Task message",
            "role": "USER",
            "taskId": "task-abc-123"
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.taskId, "task-abc-123")
    }

    func testHiveChatMessage_TaskId_NilWhenAbsent() {
        let jsonDict: [String: Any] = [
            "id": "msg-task-002",
            "message": "Task message without taskId",
            "role": "USER"
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertNil(message?.taskId)
    }

    func testIsDisplayable_EmptyMessageWithNonStreamArtifact_ReturnsTrue() {
        let jsonDict: [String: Any] = [
            "id": "disp-005",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "art-002",
                    "type": "LONGFORM",
                    "content": ["title": "Plan", "text": "Here is the plan."] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.isDisplayable == true)
    }

    // MARK: - PUBLISH_SCRIPT Artifact Tests

    func testArtifact_PublishScriptType_AllFieldsPresent() {
        let jsonDict: [String: Any] = [
            "id": "artifact-ps-001",
            "type": "PUBLISH_SCRIPT",
            "content": [
                "scriptId": 42,
                "scriptVersionId": 926,
                "scriptName": "harvey-lab-guard-completeness",
                "published": false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishScript, "Artifact with type PUBLISH_SCRIPT should have isPublishScript == true")
        XCTAssertNotNil(artifact.publishScriptContent, "PUBLISH_SCRIPT artifact should have publishScriptContent populated")
        XCTAssertEqual(artifact.publishScriptContent?.scriptId, 42)
        XCTAssertEqual(artifact.publishScriptContent?.scriptVersionId, 926)
        XCTAssertEqual(artifact.publishScriptContent?.scriptName, "harvey-lab-guard-completeness")
        XCTAssertFalse(artifact.publishScriptContent?.published ?? true)

        // Other type-specific fields must be nil
        XCTAssertNil(artifact.prContent, "PUBLISH_SCRIPT artifact should not populate prContent")
        XCTAssertNil(artifact.longformContent, "PUBLISH_SCRIPT artifact should not populate longformContent")
        XCTAssertNil(artifact.workflowContent, "PUBLISH_SCRIPT artifact should not populate workflowContent")
        XCTAssertNil(artifact.content, "PUBLISH_SCRIPT artifact should not populate plain content string")
    }

    func testArtifact_PublishScriptType_Published_True() {
        let jsonDict: [String: Any] = [
            "id": "artifact-ps-002",
            "type": "PUBLISH_SCRIPT",
            "content": [
                "scriptId": 10,
                "scriptVersionId": 100,
                "scriptName": "my-script",
                "published": true
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishScript)
        XCTAssertTrue(artifact.publishScriptContent?.published ?? false,
                      "published field should be true when JSON has published: true")
    }

    func testArtifact_PublishScriptType_MissingScriptName_GracefullyNil() {
        let jsonDict: [String: Any] = [
            "id": "artifact-ps-003",
            "type": "PUBLISH_SCRIPT",
            "content": [
                "scriptId": 42,
                "scriptVersionId": 926
                // scriptName omitted
                // published omitted → defaults to false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishScript)
        XCTAssertNotNil(artifact.publishScriptContent)
        XCTAssertNil(artifact.publishScriptContent?.scriptName, "Missing scriptName should produce nil, not crash")
        XCTAssertFalse(artifact.publishScriptContent?.published ?? true,
                       "Missing published field should default to false")
    }

    func testArtifact_PublishScriptType_MissingIds_GracefullyNil() {
        let jsonDict: [String: Any] = [
            "id": "artifact-ps-004",
            "type": "PUBLISH_SCRIPT",
            "content": [
                "scriptName": "some-script",
                "published": false
                // scriptId and scriptVersionId omitted
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishScript)
        XCTAssertNotNil(artifact.publishScriptContent)
        XCTAssertNil(artifact.publishScriptContent?.scriptId, "Missing scriptId should produce nil, not crash")
        XCTAssertNil(artifact.publishScriptContent?.scriptVersionId, "Missing scriptVersionId should produce nil, not crash")
    }

    func testArtifact_PublishScriptType_EmptyContent_DoesNotCrash() {
        let jsonDict: [String: Any] = [
            "id": "artifact-ps-005",
            "type": "PUBLISH_SCRIPT",
            "content": [:] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishScript, "Type should still be recognized")
        XCTAssertNotNil(artifact.publishScriptContent, "publishScriptContent should be non-nil (with all optional fields nil)")
        XCTAssertNil(artifact.publishScriptContent?.scriptId)
        XCTAssertNil(artifact.publishScriptContent?.scriptVersionId)
        XCTAssertNil(artifact.publishScriptContent?.scriptName)
        XCTAssertFalse(artifact.publishScriptContent?.published ?? true)
    }

    func testArtifact_NonPublishScriptType_HasNilPublishScriptContent() {
        let jsonDict: [String: Any] = [
            "id": "artifact-pr-001",
            "type": "PULL_REQUEST",
            "content": ["url": "https://github.com/org/repo/pull/1", "status": "OPEN"] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertFalse(artifact.isPublishScript)
        XCTAssertNil(artifact.publishScriptContent, "Non-PUBLISH_SCRIPT artifact must have nil publishScriptContent")
    }

    func testIsPublishScript_FalseForOtherTypes() {
        let types = ["PULL_REQUEST", "LONGFORM", "PLAN", "STREAM", "WORKFLOW", "CODE", "DIFF"]
        for typeStr in types {
            let jsonDict: [String: Any] = [
                "id": "artifact-type-\(typeStr)",
                "type": typeStr,
                "content": ""
            ]
            let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))
            XCTAssertFalse(artifact.isPublishScript, "isPublishScript should be false for type \(typeStr)")
        }
    }

    func testIsDisplayable_PublishScriptArtifact_ReturnsTrue() {
        // PUBLISH_SCRIPT is not STREAM or WORKFLOW, so isDisplayable must be true
        let jsonDict: [String: Any] = [
            "id": "msg-ps-001",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-ps-display",
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
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.isDisplayable == true,
                      "A message with a PUBLISH_SCRIPT artifact should be displayable")
    }

    func testArtifact_PublishScriptType_WrongTypeForFields_GracefullyHandled() {
        // Pass wrong types for fields — should not crash, fields degrade to nil/false
        let jsonDict: [String: Any] = [
            "id": "artifact-ps-006",
            "type": "PUBLISH_SCRIPT",
            "content": [
                "scriptId": "not-an-int",      // wrong type
                "scriptVersionId": "also-wrong",
                "scriptName": 12345,           // wrong type
                "published": "yes"             // wrong type
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishScript, "Type should still be recognized despite bad field types")
        XCTAssertNotNil(artifact.publishScriptContent)
        // Fields with wrong types should gracefully return nil / default
        XCTAssertNil(artifact.publishScriptContent?.scriptId, "scriptId with wrong type should be nil")
        XCTAssertNil(artifact.publishScriptContent?.scriptVersionId, "scriptVersionId with wrong type should be nil")
        XCTAssertFalse(artifact.publishScriptContent?.published ?? true,
                       "published with wrong type should default to false")
    }

    func testPublishScriptContent_MutablePublished_CanBeFlipped() {
        // Verify published is a var and can be mutated (for local state flip after success)
        let jsonDict: [String: Any] = [
            "id": "artifact-ps-007",
            "type": "PUBLISH_SCRIPT",
            "content": [
                "scriptId": 42,
                "scriptVersionId": 926,
                "scriptName": "my-script",
                "published": false
            ] as [String: Any]
        ]
        var artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertFalse(artifact.publishScriptContent?.published ?? true)
        artifact.publishScriptContent?.published = true
        XCTAssertTrue(artifact.publishScriptContent?.published ?? false,
                      "publishScriptContent.published should be mutable and reflect the flip")
    }

    // MARK: - PUBLISH_WORKFLOW Artifact Tests

    func testArtifact_PublishWorkflowType_AllFieldsPresent() {
        let jsonDict: [String: Any] = [
            "id": "artifact-pw-001",
            "type": "PUBLISH_WORKFLOW",
            "content": [
                "workflowId": 99,
                "workflowName": "my-workflow",
                "workflowRefId": "wf-ref-abc",
                "published": false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishWorkflow, "Artifact with type PUBLISH_WORKFLOW should have isPublishWorkflow == true")
        XCTAssertNotNil(artifact.publishWorkflowContent, "PUBLISH_WORKFLOW artifact should have publishWorkflowContent populated")
        XCTAssertEqual(artifact.publishWorkflowContent?.workflowId, 99)
        XCTAssertEqual(artifact.publishWorkflowContent?.workflowName, "my-workflow")
        XCTAssertEqual(artifact.publishWorkflowContent?.workflowRefId, "wf-ref-abc")
        XCTAssertFalse(artifact.publishWorkflowContent?.published ?? true)

        // Sibling content properties must be nil
        XCTAssertNil(artifact.prContent, "PUBLISH_WORKFLOW artifact should not populate prContent")
        XCTAssertNil(artifact.longformContent, "PUBLISH_WORKFLOW artifact should not populate longformContent")
        XCTAssertNil(artifact.workflowContent, "PUBLISH_WORKFLOW artifact should not populate workflowContent")
        XCTAssertNil(artifact.publishScriptContent, "PUBLISH_WORKFLOW artifact should not populate publishScriptContent")
        XCTAssertNil(artifact.content, "PUBLISH_WORKFLOW artifact should not populate plain content string")
    }

    func testArtifact_PublishWorkflowType_Published_True() {
        let jsonDict: [String: Any] = [
            "id": "artifact-pw-002",
            "type": "PUBLISH_WORKFLOW",
            "content": [
                "workflowId": 99,
                "workflowName": "my-workflow",
                "workflowRefId": "wf-ref-abc",
                "published": true
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishWorkflow)
        XCTAssertTrue(artifact.publishWorkflowContent?.published ?? false,
                      "published: true should parse as true")
    }

    func testArtifact_PublishWorkflowType_MissingIds_GracefullyNil() {
        let jsonDict: [String: Any] = [
            "id": "artifact-pw-003",
            "type": "PUBLISH_WORKFLOW",
            "content": [
                "published": false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishWorkflow)
        XCTAssertNotNil(artifact.publishWorkflowContent)
        XCTAssertNil(artifact.publishWorkflowContent?.workflowId, "Missing workflowId should produce nil, not crash")
        XCTAssertNil(artifact.publishWorkflowContent?.workflowName, "Missing workflowName should produce nil, not crash")
        XCTAssertNil(artifact.publishWorkflowContent?.workflowRefId, "Missing workflowRefId should produce nil, not crash")
        XCTAssertFalse(artifact.publishWorkflowContent?.published ?? true)
    }

    func testArtifact_PublishWorkflowType_StringEncodedWorkflowId_Coerced() {
        // workflowId arrives as a string-encoded integer — defensive parse must coerce it to Int
        let jsonDict: [String: Any] = [
            "id": "artifact-pw-004",
            "type": "PUBLISH_WORKFLOW",
            "content": [
                "workflowId": "123",
                "workflowName": "string-id-workflow",
                "workflowRefId": "wf-ref-xyz",
                "published": false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishWorkflow)
        XCTAssertNotNil(artifact.publishWorkflowContent)
        XCTAssertEqual(artifact.publishWorkflowContent?.workflowId, 123,
                       "String-encoded workflowId should be coerced to Int(123) via defensive fallback")
    }

    func testIsDisplayable_PublishWorkflowArtifact_ReturnsTrue() {
        // PUBLISH_WORKFLOW is not STREAM or WORKFLOW, so isDisplayable must be true
        let jsonDict: [String: Any] = [
            "id": "msg-pw-001",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-pw-display",
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
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.isDisplayable == true,
                      "A message with a PUBLISH_WORKFLOW artifact should be displayable")
    }

    func testPublishWorkflowContent_MutablePublished_CanBeFlipped() {
        // Verify published is a var and can be mutated (for local state flip after success)
        let jsonDict: [String: Any] = [
            "id": "artifact-pw-005",
            "type": "PUBLISH_WORKFLOW",
            "content": [
                "workflowId": 99,
                "workflowName": "my-workflow",
                "workflowRefId": "wf-ref-abc",
                "published": false
            ] as [String: Any]
        ]
        var artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertFalse(artifact.publishWorkflowContent?.published ?? true)
        artifact.publishWorkflowContent?.published = true
        XCTAssertTrue(artifact.publishWorkflowContent?.published ?? false,
                      "publishWorkflowContent.published should be mutable and reflect the flip")
    }

    // MARK: - PUBLISH_PROMPT Artifact Tests

    func testArtifact_PublishPromptType_AllFieldsPresent_PublishedFalse() {
        let jsonDict: [String: Any] = [
            "id": "artifact-pp-001",
            "type": "PUBLISH_PROMPT",
            "content": [
                "promptId": "clprompt000000000000001",
                "promptVersionId": "clversion000000000000007",
                "promptName": "my-cool-prompt",
                "published": false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishPrompt, "Artifact with type PUBLISH_PROMPT should have isPublishPrompt == true")
        XCTAssertNotNil(artifact.publishPromptContent, "PUBLISH_PROMPT artifact should have publishPromptContent populated")
        XCTAssertEqual(artifact.publishPromptContent?.promptId, "clprompt000000000000001")
        XCTAssertEqual(artifact.publishPromptContent?.promptVersionId, "clversion000000000000007")
        XCTAssertEqual(artifact.publishPromptContent?.promptName, "my-cool-prompt")
        XCTAssertFalse(artifact.publishPromptContent?.published ?? true,
                       "published: false should parse as false")

        // Sibling content properties must be nil
        XCTAssertNil(artifact.prContent, "PUBLISH_PROMPT artifact should not populate prContent")
        XCTAssertNil(artifact.longformContent, "PUBLISH_PROMPT artifact should not populate longformContent")
        XCTAssertNil(artifact.workflowContent, "PUBLISH_PROMPT artifact should not populate workflowContent")
        XCTAssertNil(artifact.publishScriptContent, "PUBLISH_PROMPT artifact should not populate publishScriptContent")
        XCTAssertNil(artifact.publishWorkflowContent, "PUBLISH_PROMPT artifact should not populate publishWorkflowContent")
        XCTAssertNil(artifact.content, "PUBLISH_PROMPT artifact should not populate plain content string")
    }

    func testArtifact_PublishPromptType_Published_True() {
        let jsonDict: [String: Any] = [
            "id": "artifact-pp-002",
            "type": "PUBLISH_PROMPT",
            "content": [
                "promptId": "clprompt000000000000001",
                "promptVersionId": "clversion000000000000007",
                "promptName": "my-cool-prompt",
                "published": true
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishPrompt)
        XCTAssertTrue(artifact.publishPromptContent?.published ?? false,
                      "published: true should parse as true")
    }

    func testArtifact_PublishPromptType_MissingPromptName_GracefullyNil() {
        // Fallback text ("Prompt v{id}") is a UI concern; model must surface nil for missing name
        let jsonDict: [String: Any] = [
            "id": "artifact-pp-003",
            "type": "PUBLISH_PROMPT",
            "content": [
                "promptId": "clprompt000000000000001",
                "promptVersionId": "clversion000000000000007"
                // promptName omitted
                // published omitted → defaults to false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishPrompt)
        XCTAssertNotNil(artifact.publishPromptContent)
        XCTAssertNil(artifact.publishPromptContent?.promptName,
                     "Missing promptName should produce nil, not crash")
        XCTAssertFalse(artifact.publishPromptContent?.published ?? true,
                       "Missing published field should default to false")
    }

    func testArtifact_PublishPromptType_EmptyStringIds_ArePreservedNotNil() {
        // Empty-string IDs must remain as present-but-empty strings so the publish-handler
        // guard (which checks .isEmpty) can detect and reject them correctly.
        let jsonDict: [String: Any] = [
            "id": "artifact-pp-004",
            "type": "PUBLISH_PROMPT",
            "content": [
                "promptId": "",
                "promptVersionId": "",
                "promptName": "some-prompt",
                "published": false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishPrompt)
        XCTAssertNotNil(artifact.publishPromptContent)
        // Must be non-nil empty strings, NOT nil — guards elsewhere key off isEmpty
        XCTAssertNotNil(artifact.publishPromptContent?.promptId,
                        "Empty-string promptId should be present (non-nil) for guard to detect it as empty")
        XCTAssertEqual(artifact.publishPromptContent?.promptId, "",
                       "Empty-string promptId should be preserved as empty string, not converted to nil")
        XCTAssertNotNil(artifact.publishPromptContent?.promptVersionId,
                        "Empty-string promptVersionId should be present (non-nil) for guard to detect it as empty")
        XCTAssertEqual(artifact.publishPromptContent?.promptVersionId, "",
                       "Empty-string promptVersionId should be preserved as empty string, not converted to nil")
    }

    func testArtifact_PublishPromptType_IdsAreStrings_NotInts() {
        // Prompt IDs are cuid strings, not integers — verify the model reads them as .string
        let jsonDict: [String: Any] = [
            "id": "artifact-pp-005",
            "type": "PUBLISH_PROMPT",
            "content": [
                "promptId": "clxyz1234567890abcdefghi",
                "promptVersionId": "clver987654321zyxwvutsrq",
                "promptName": "string-id-prompt",
                "published": false
            ] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertTrue(artifact.isPublishPrompt)
        XCTAssertEqual(artifact.publishPromptContent?.promptId, "clxyz1234567890abcdefghi",
                       "promptId should be stored as the full cuid string")
        XCTAssertEqual(artifact.publishPromptContent?.promptVersionId, "clver987654321zyxwvutsrq",
                       "promptVersionId should be stored as the full cuid string")
    }

    func testPublishPromptContent_MutablePublished_CanBeFlipped() {
        // Verify published is a var and can be mutated (for local state flip after success)
        let jsonDict: [String: Any] = [
            "id": "artifact-pp-006",
            "type": "PUBLISH_PROMPT",
            "content": [
                "promptId": "clprompt000000000000001",
                "promptVersionId": "clversion000000000000007",
                "promptName": "my-cool-prompt",
                "published": false
            ] as [String: Any]
        ]
        var artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertFalse(artifact.publishPromptContent?.published ?? true)
        artifact.publishPromptContent?.published = true
        XCTAssertTrue(artifact.publishPromptContent?.published ?? false,
                      "publishPromptContent.published should be mutable and reflect the flip")
    }

    func testArtifact_NonPublishPromptType_HasNilPublishPromptContent() {
        let jsonDict: [String: Any] = [
            "id": "artifact-pr-002",
            "type": "PULL_REQUEST",
            "content": ["url": "https://github.com/org/repo/pull/1", "status": "OPEN"] as [String: Any]
        ]
        let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))

        XCTAssertFalse(artifact.isPublishPrompt)
        XCTAssertNil(artifact.publishPromptContent, "Non-PUBLISH_PROMPT artifact must have nil publishPromptContent")
    }

    func testIsPublishPrompt_FalseForOtherTypes() {
        let types = ["PULL_REQUEST", "LONGFORM", "PLAN", "STREAM", "WORKFLOW",
                     "CODE", "DIFF", "PUBLISH_SCRIPT", "PUBLISH_WORKFLOW"]
        for typeStr in types {
            let jsonDict: [String: Any] = [
                "id": "artifact-type-pp-\(typeStr)",
                "type": typeStr,
                "content": ""
            ]
            let artifact = HiveChatMessageArtifact(json: JSON(jsonDict))
            XCTAssertFalse(artifact.isPublishPrompt,
                           "isPublishPrompt should be false for type \(typeStr)")
        }
    }

    func testIsDisplayable_PublishPromptArtifact_ReturnsTrue() {
        // PUBLISH_PROMPT is not STREAM or WORKFLOW, so isDisplayable must be true
        let jsonDict: [String: Any] = [
            "id": "msg-pp-001",
            "message": "",
            "role": "ASSISTANT",
            "artifacts": [
                [
                    "id": "artifact-pp-display",
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
        let message = HiveChatMessage(json: JSON(jsonDict))
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.isDisplayable == true,
                      "A message with a PUBLISH_PROMPT artifact should be displayable")
    }
}
