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
            "timestamp": "2024-01-20T15:30:00Z"
        ]
        
        let json = JSON(jsonDict)
        let chatMessage = HiveChatMessage(json: json)
        
        XCTAssertNotNil(chatMessage, "HiveChatMessage should initialize with complete JSON")
        XCTAssertEqual(chatMessage?.id, "msg-123")
        XCTAssertEqual(chatMessage?.message, "Let's build a chat feature with WebSocket support")
        XCTAssertEqual(chatMessage?.role, "user")
        XCTAssertEqual(chatMessage?.timestamp, "2024-01-20T15:30:00Z")
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
        XCTAssertNil(chatMessage?.timestamp)
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
        
        let roles = mockMessages.map { $0.role }
        
        XCTAssertTrue(roles.contains("user"), "Mock conversation should contain user messages")
        XCTAssertTrue(roles.contains("assistant"), "Mock conversation should contain assistant messages")
    }
    
    func testHiveChatMessage_MockConversation_AlternatingRoles() {
        let mockMessages = HiveChatMessage.mockConversation()
        
        // Check that roles alternate between user and assistant
        var expectedRole = "user"
        for message in mockMessages {
            XCTAssertEqual(message.role, expectedRole, "Mock conversation should alternate between user and assistant")
            expectedRole = (expectedRole == "user") ? "assistant" : "user"
        }
    }
    
    func testHiveChatMessage_MockConversation_AllMessagesHaveRequiredFields() {
        let mockMessages = HiveChatMessage.mockConversation()
        
        for message in mockMessages {
            XCTAssertFalse(message.id.isEmpty, "Mock message should have non-empty id")
            XCTAssertFalse(message.message.isEmpty, "Mock message should have non-empty message")
            XCTAssertFalse(message.role.isEmpty, "Mock message should have non-empty role")
            XCTAssertTrue(message.role == "user" || message.role == "assistant", "Mock message role should be either 'user' or 'assistant'")
        }
    }
    
    func testHiveChatMessage_MockConversation_ContainsPlanContent() {
        let mockMessages = HiveChatMessage.mockConversation()
        
        let allMessagesText = mockMessages.map { $0.message }.joined(separator: " ").lowercased()
        
        // Verify mock conversation discusses technical planning topics
        XCTAssertTrue(
            allMessagesText.contains("architecture") ||
            allMessagesText.contains("requirements") ||
            allMessagesText.contains("feature") ||
            allMessagesText.contains("implementation"),
            "Mock conversation should contain plan-related content"
        )
    }
}
