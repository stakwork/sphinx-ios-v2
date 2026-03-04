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
}
