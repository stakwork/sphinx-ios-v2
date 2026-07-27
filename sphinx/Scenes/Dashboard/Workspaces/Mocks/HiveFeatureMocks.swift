//
//  HiveFeatureMocks.swift
//  sphinx
//
//  Created on 2025-02-26.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

extension HiveFeature {
    static func mockList() -> [HiveFeature] {
        let json1 = JSON([
            "id": "feature-001",
            "title": "User Authentication System",
            "brief": "Implement OAuth2 and JWT-based authentication",
            "userStories": "- As a user, I want to sign in with email\n- As a user, I want to reset my password",
            "requirements": "Must support OAuth2, JWT tokens, refresh token rotation",
            "architecture": "Use passport.js with JWT strategy, Redis for session store",
            "status": "COMPLETED",
            "workflowStatus": "COMPLETED",
            "createdAt": "2025-02-20T10:00:00Z",
            "updatedAt": "2025-02-25T14:30:00Z"
        ])
        
        let json2 = JSON([
            "id": "feature-002",
            "title": "Real-time Chat Features",
            "brief": "Add WebSocket-based chat with typing indicators",
            "userStories": "- As a user, I want to see when someone is typing\n- As a user, I want real-time message delivery",
            "requirements": "WebSocket connection, message queue, offline support",
            "architecture": "Socket.io for WebSocket, MongoDB for message persistence",
            "status": "IN_PROGRESS",
            "workflowStatus": "IN_PROGRESS",
            "createdAt": "2025-02-22T09:15:00Z",
            "updatedAt": "2025-02-26T11:20:00Z"
        ])
        
        let json3 = JSON([
            "id": "feature-003",
            "title": "Dashboard Analytics",
            "brief": "Create comprehensive analytics dashboard",
            "userStories": "- As an admin, I want to view user engagement metrics\n- As an admin, I want to export reports",
            "requirements": "Real-time metrics, exportable charts, role-based access",
            "architecture": "Chart.js for visualization, PostgreSQL for aggregations",
            "status": "TODO",
            "workflowStatus": "TODO",
            "createdAt": "2025-02-23T08:00:00Z",
            "updatedAt": "2025-02-23T08:00:00Z"
        ])
        
        let json4 = JSON([
            "id": "feature-004",
            "title": "Payment Integration",
            "createdAt": "2025-02-26T07:45:00Z",
            "updatedAt": "2025-02-26T07:45:00Z"
        ])
        
        return [json1, json2, json3, json4].compactMap { HiveFeature(json: $0) }
    }
}

extension WorkspaceTask {
    static func mockList() -> [WorkspaceTask] {
        let json1 = JSON([
            "id": "task-001",
            "title": "Set up CI/CD pipeline",
            "status": "DONE",
            "priority": "HIGH",
            "chatMessageCount": 3,
            "repository": ["name": "sphinx-ios-v2"],
            "updatedAt": "2026-03-01T08:00:00Z",
            "prArtifact": [
                "id": "pr-artifact-done-001",
                "content": [
                    "url": "https://github.com/stakwork/sphinx-ios-v2/pull/10",
                    "status": "MERGED",
                    "number": 10
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any])

        let json2 = JSON([
            "id": "task-pr-001",
            "title": "Add WebSocket reconnection logic",
            "status": "IN_PROGRESS",
            "priority": "HIGH",
            "chatMessageCount": 0,
            "repository": ["name": "sphinx-ios-v2"],
            "updatedAt": "2026-03-01T10:00:00Z",
            "prArtifact": [
                "id": "pr-artifact-001",
                "content": [
                    "url": "https://github.com/stakwork/sphinx-ios-v2/pull/42",
                    "status": "open",
                    "number": 42
                ] as [String: Any]
            ] as [String: Any]
        ] as [String: Any])

        let json3 = JSON([
            "id": "task-003",
            "title": "Write unit tests for auth module",
            "status": "IN_PROGRESS",
            "priority": "MEDIUM",
            "chatMessageCount": 1,
            "repository": ["name": "sphinx-ios-v2"],
            "updatedAt": "2026-03-02T12:00:00Z"
        ] as [String: Any])

        let json4 = JSON([
            "id": "task-004",
            "title": "Investigate memory leak in chat view",
            "status": "BLOCKED",
            "priority": "CRITICAL",
            "chatMessageCount": 5,
            "repository": ["name": "sphinx-ios-v2"],
            "updatedAt": "2026-03-03T09:00:00Z"
        ] as [String: Any])

        return [json1, json2, json3, json4].compactMap { WorkspaceTask(json: $0) }
    }
}

extension HiveChatMessage {
    static func mockConversation() -> [HiveChatMessage] {
        let json1 = JSON([
            "id": "msg-001",
            "message": "I need to build a real-time chat feature for our app",
            "role": "user",
            "createdAt": "2025-02-22T09:15:00Z"
        ])
        
        let json2 = JSON([
            "id": "msg-002",
            "message": "I'll help you plan a real-time chat feature. Let's start with the brief. What are the main goals and scope of this chat feature?",
            "role": "assistant",
            "createdAt": "2025-02-22T09:15:15Z"
        ])
        
        let json3 = JSON([
            "id": "msg-003",
            "message": "It should support one-on-one and group chats, with typing indicators and read receipts",
            "role": "user",
            "createdAt": "2025-02-22T09:16:30Z"
        ])
        
        let json4 = JSON([
            "id": "msg-004",
            "message": "Great! I've updated the brief. Now let's define the user stories. Here's what I'm thinking:\n\n- As a user, I want to send messages in real-time\n- As a user, I want to see when someone is typing\n- As a user, I want to know if my message was read\n- As a user, I want to create group chats\n\nDoes this capture what you need?",
            "role": "assistant",
            "createdAt": "2025-02-22T09:16:45Z"
        ])
        
        let json5 = JSON([
            "id": "msg-005",
            "message": "Yes, that's perfect. What about the technical requirements?",
            "role": "user",
            "createdAt": "2025-02-22T09:17:20Z"
        ])
        
        let json6 = JSON([
            "id": "msg-006",
            "message": "Based on your needs, here are the key technical requirements:\n\n1. WebSocket connection for real-time bidirectional communication\n2. Message persistence with MongoDB\n3. Offline message queue and sync\n4. Typing indicator debouncing (3-second timeout)\n5. Read receipt tracking per user\n6. Group chat member management\n\nShall I proceed with the architecture plan?",
            "role": "assistant",
            "createdAt": "2025-02-22T09:17:35Z"
        ])
        
        let json7 = JSON([
            "id": "msg-007",
            "message": "Yes please, and make sure it scales to handle 10,000 concurrent connections",
            "role": "user",
            "createdAt": "2025-02-22T09:18:10Z"
        ])
        
        let json8 = JSON([
            "id": "msg-008",
            "message": "Excellent requirement. Here's the architecture I recommend:\n\n**Backend:**\n- Socket.io for WebSocket management with Redis adapter for horizontal scaling\n- Node.js cluster mode across multiple CPU cores\n- MongoDB with proper indexes on chatId, createdAt, and userId\n- Redis for typing indicators and presence tracking (ephemeral data)\n- Message queue (Bull/BullMQ) for offline delivery\n\n**Frontend:**\n- Socket.io client with auto-reconnect\n- Local IndexedDB cache for offline support\n- Optimistic UI updates\n\n**Infrastructure:**\n- Load balancer with sticky sessions\n- Redis Cluster for pub/sub across Socket.io instances\n- Auto-scaling based on connection count\n\nThis architecture can easily handle 10,000+ concurrent connections per server instance.",
            "role": "assistant",
            "createdAt": "2025-02-22T09:18:30Z"
        ])

        // Mock clarifying questions artifact
        let clarifyingContentJSON: [String: Any] = [
            "tool_use": "ask_clarifying_questions",
            "content": [
                [
                    "question": "Where does the clarifying question data come from?",
                    "options": ["Option A", "Option B", "Option C"],
                    "type": "single_choice"
                ],
                [
                    "question": "Which chat views should show this?",
                    "options": ["Feature chat", "Task chat", "Both"],
                    "type": "multiple_choice"
                ],
                [
                    "question": "How should answers be submitted?",
                    "options": ["Plain text message", "Dedicated endpoint"],
                    "type": "single_choice"
                ]
            ] as [[String: Any]]
        ]
        let json9 = JSON([
            "id": "msg-009",
            "message": "I have a few clarifying questions about your requirements:",
            "role": "ASSISTANT",
            "createdAt": "2025-02-22T09:19:00Z",
            "artifacts": [
                [
                    "id": "artifact-001",
                    "type": "PLAN",
                    "content": clarifyingContentJSON
                ]
            ] as [[String: Any]]
        ])
        
        let jsonLongform = JSON([
            "id": "msg-longform-001",
            "message": "",
            "role": "ASSISTANT",
            "createdAt": "2025-02-22T09:20:00Z",
            "artifacts": [
                [
                    "id": "artifact-001",
                    "type": "LONGFORM",
                    "content": [
                        "title": "Agent",
                        "text": "There was an error creating pull request.\r\n\r\nCannot create PR - currently on base branch (master). Commit changes to a feature branch first."
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ])

        // Single-table message
        let jsonTable1 = JSON([
            "id": "msg-table-001",
            "message": "Here's a summary of the episode attributes:\n\n| Episode | Attribute |\n|---|---|\n| Pilot | Introduction |\n| Episode 2 | Rising Action |\n| Episode 3 | Climax |",
            "role": "ASSISTANT",
            "createdAt": "2025-02-22T09:21:00Z"
        ])

        // Multi-table + text message
        let jsonTable2 = JSON([
            "id": "msg-table-002",
            "message": "Here are two comparison tables:\n\n| Framework | Language |\n|---|---|\n| UIKit | Swift |\n| SwiftUI | Swift |\n\nAnd a wider breakdown:\n\n| Name | Version | Platform | License | Stars |\n|---|---|---|---|---|\n| UIKit | iOS 2+ | iOS/tvOS | Proprietary | N/A |\n| SwiftUI | iOS 13+ | Apple | Proprietary | N/A |\n| React Native | 0.72 | Cross | MIT | 110k |\n| Flutter | 3.x | Cross | BSD | 150k |",
            "role": "ASSISTANT",
            "createdAt": "2025-02-22T09:22:00Z"
        ])

        return [json1, json2, json3, json4, json5, json6, json7, json8, json9, jsonLongform, jsonTable1, jsonTable2].compactMap { HiveChatMessage(json: $0) }
    }
}
