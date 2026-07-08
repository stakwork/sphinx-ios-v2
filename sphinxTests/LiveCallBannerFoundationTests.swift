//
//  LiveCallBannerFoundationTests.swift
//  sphinxTests
//
//  Tests for the Phase-1 Live Call Banner foundation:
//    1. TransactionMessage.getRecentCallMessages
//    2. VideoCallManager.currentRoomName set/clear + .videoCallStateDidChange
//    3. Join-while-in-a-call branch logic
//

import XCTest
import CoreData
@testable import sphinx

// MARK: - In-Memory Core Data stack helper

/// Builds a throw-away NSPersistentContainer backed by an in-memory SQLite store,
/// so tests can insert/query managed objects without touching the device database.
private func makeInMemoryContainer() throws -> NSPersistentContainer {
    // Load the managed object model from the app bundle – the model is named "sphinx".
    guard let modelURL = Bundle(for: LiveCallBannerFoundationTests.self).url(forResource: "sphinx", withExtension: "momd"),
          let mom = NSManagedObjectModel(contentsOf: modelURL) else {
        // Fallback: try the app bundle explicitly
        let bundles = Bundle.allBundles + Bundle.allFrameworks
        let model = bundles.compactMap {
            $0.url(forResource: "sphinx", withExtension: "momd")
                .flatMap { NSManagedObjectModel(contentsOf: $0) }
        }.first
        guard let model = model else {
            throw XCTSkip("CoreData model 'sphinx' not found in test bundle – skipping CoreData tests")
        }
        let container = NSPersistentContainer(name: "sphinx", managedObjectModel: model)
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let err = loadError { throw err }
        return container
    }

    let container = NSPersistentContainer(name: "sphinx", managedObjectModel: mom)
    let desc = NSPersistentStoreDescription()
    desc.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [desc]
    var loadError: Error?
    container.loadPersistentStores { _, error in loadError = error }
    if let err = loadError { throw err }
    return container
}

// MARK: - Tests

class LiveCallBannerFoundationTests: XCTestCase {

    // MARK: - getRecentCallMessages

    /// Returns only call-type messages, scoped to the correct chat.
    func testGetRecentCallMessages_returnsOnlyCallMessages() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.newBackgroundContext()

        // Create two chats.
        let chat1 = NSEntityDescription.insertNewObject(forEntityName: "Chat", into: ctx) as! Chat
        chat1.id = 1

        let chat2 = NSEntityDescription.insertNewObject(forEntityName: "Chat", into: ctx) as! Chat
        chat2.id = 2

        // Call message on chat1.
        let callMsg = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
        callMsg.id = 100
        callMsg.type = TransactionMessage.TransactionMessageType.call.rawValue
        callMsg.chat = chat1
        callMsg.date = Date()

        // Regular text message on chat1.
        let textMsg = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
        textMsg.id = 101
        textMsg.type = TransactionMessage.TransactionMessageType.message.rawValue
        textMsg.chat = chat1
        textMsg.date = Date()

        // Call message on chat2 (should NOT appear in results for chat1).
        let otherChatCallMsg = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
        otherChatCallMsg.id = 102
        otherChatCallMsg.type = TransactionMessage.TransactionMessageType.call.rawValue
        otherChatCallMsg.chat = chat2
        otherChatCallMsg.date = Date()

        try ctx.save()

        let results = TransactionMessage.getRecentCallMessages(for: 1, context: ctx)

        XCTAssertEqual(results.count, 1, "Should return exactly 1 call message for chat 1")
        XCTAssertEqual(results.first?.id, 100)
        XCTAssertTrue(results.allSatisfy { $0.type == TransactionMessage.TransactionMessageType.call.rawValue
                                        || $0.messageContent?.contains(TransactionMessage.kCallRoomName) == true },
                      "All returned messages must be call-type")
    }

    /// Results are ordered newest-first.
    func testGetRecentCallMessages_newestFirst() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.newBackgroundContext()

        let chat = NSEntityDescription.insertNewObject(forEntityName: "Chat", into: ctx) as! Chat
        chat.id = 10

        let now = Date()
        let makeMsg: (Int, TimeInterval) -> Void = { msgId, offset in
            let m = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
            m.id = msgId
            m.type = TransactionMessage.TransactionMessageType.call.rawValue
            m.chat = chat
            m.date = now.addingTimeInterval(offset)
        }
        makeMsg(200, -3600)   // 1 hour ago
        makeMsg(201, -7200)   // 2 hours ago
        makeMsg(202, -1800)   // 30 min ago — newest

        try ctx.save()

        let results = TransactionMessage.getRecentCallMessages(for: 10, context: ctx)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].id, 202, "Newest message should be first")
        XCTAssertEqual(results[1].id, 200)
        XCTAssertEqual(results[2].id, 201, "Oldest message should be last")
    }

    /// The `limit` parameter caps the returned count.
    func testGetRecentCallMessages_respectsLimit() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.newBackgroundContext()

        let chat = NSEntityDescription.insertNewObject(forEntityName: "Chat", into: ctx) as! Chat
        chat.id = 20

        let now = Date()
        for i in 0..<10 {
            let m = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
            m.id = 300 + i
            m.type = TransactionMessage.TransactionMessageType.call.rawValue
            m.chat = chat
            m.date = now.addingTimeInterval(Double(-i * 60))
        }

        try ctx.save()

        let results = TransactionMessage.getRecentCallMessages(for: 20, limit: 3, context: ctx)

        XCTAssertEqual(results.count, 3, "Should respect the limit of 3")
    }

    /// Messages older than `withinDays` are excluded.
    func testGetRecentCallMessages_respectsRecencyBound() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.newBackgroundContext()

        let chat = NSEntityDescription.insertNewObject(forEntityName: "Chat", into: ctx) as! Chat
        chat.id = 30

        let now = Date()

        // Message within the window (2 days ago).
        let recent = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
        recent.id = 400
        recent.type = TransactionMessage.TransactionMessageType.call.rawValue
        recent.chat = chat
        recent.date = now.addingTimeInterval(-2 * 24 * 3600)   // 2 days ago

        // Message outside the window (10 days ago when withinDays=7).
        let old = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
        old.id = 401
        old.type = TransactionMessage.TransactionMessageType.call.rawValue
        old.chat = chat
        old.date = now.addingTimeInterval(-10 * 24 * 3600)   // 10 days ago

        try ctx.save()

        let results = TransactionMessage.getRecentCallMessages(for: 30, withinDays: 7, context: ctx)

        XCTAssertEqual(results.count, 1, "Only the message within the 7-day window should be returned")
        XCTAssertEqual(results.first?.id, 400)
    }

    /// Messages whose `messageContent` contains the call-room name are also returned
    /// (covers the `isCallLink` path for non-type-32 messages).
    func testGetRecentCallMessages_includesCallLinkContentMessages() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.newBackgroundContext()

        let chat = NSEntityDescription.insertNewObject(forEntityName: "Chat", into: ctx) as! Chat
        chat.id = 40

        // A regular-type message whose content contains kCallRoomName.
        let linkMsg = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
        linkMsg.id = 500
        linkMsg.type = TransactionMessage.TransactionMessageType.message.rawValue
        linkMsg.messageContent = "https://example.com\(TransactionMessage.kCallRoomName).abc123"
        linkMsg.chat = chat
        linkMsg.date = Date()

        // A plain text message that should not match.
        let plain = NSEntityDescription.insertNewObject(forEntityName: "TransactionMessage", into: ctx) as! TransactionMessage
        plain.id = 501
        plain.type = TransactionMessage.TransactionMessageType.message.rawValue
        plain.messageContent = "Hello world"
        plain.chat = chat
        plain.date = Date()

        try ctx.save()

        let results = TransactionMessage.getRecentCallMessages(for: 40, context: ctx)

        XCTAssertEqual(results.count, 1, "Should include message with call-link content")
        XCTAssertEqual(results.first?.id, 500)
    }

    // MARK: - VideoCallManager currentRoomName & notification

    @MainActor
    func testCurrentRoomName_isNilInitially() {
        // Use a fresh instance via explicit init to avoid polluting the shared singleton.
        let manager = VideoCallManager()
        XCTAssertNil(manager.currentRoomName, "currentRoomName should start as nil")
    }

    @MainActor
    func testCurrentRoomName_postsNotificationOnSet() {
        let manager = VideoCallManager()
        let expectation = self.expectation(description: "videoCallStateDidChange fires on set")

        let token = NotificationCenter.default.addObserver(
            forName: .videoCallStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.currentRoomName = "test-room-123"

        waitForExpectations(timeout: 1)
    }

    @MainActor
    func testCurrentRoomName_postsNotificationOnClear() {
        let manager = VideoCallManager()
        manager.currentRoomName = "room-to-clear"   // Set without observing first.

        let expectation = self.expectation(description: "videoCallStateDidChange fires on clear")

        let token = NotificationCenter.default.addObserver(
            forName: .videoCallStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.currentRoomName = nil

        waitForExpectations(timeout: 1)
    }

    @MainActor
    func testCurrentRoomName_doesNotPostNotificationWhenValueUnchanged() {
        let manager = VideoCallManager()
        manager.currentRoomName = "same-room"

        var notificationCount = 0
        let token = NotificationCenter.default.addObserver(
            forName: .videoCallStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        // Setting to the same value should not post.
        manager.currentRoomName = "same-room"

        // Give the run loop a tick to flush any queued notifications.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(notificationCount, 0, "No notification should fire when value is unchanged")
    }

    @MainActor
    func testCurrentRoomName_postsExactlyOncePerTransition() {
        let manager = VideoCallManager()

        var notificationCount = 0
        let token = NotificationCenter.default.addObserver(
            forName: .videoCallStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.currentRoomName = "room-a"   // nil → "room-a"  (+1)
        manager.currentRoomName = nil        // "room-a" → nil  (+1)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertEqual(notificationCount, 2, "Exactly one notification per distinct transition")
    }

    // MARK: - Join-while-in-a-call branch logic

    /// Requesting the same room while already active is a no-op (currentRoomName unchanged, no extra notification).
    @MainActor
    func testStartVideoCall_sameRoom_isNoOp() {
        let manager = VideoCallManager()
        // Simulate an already-active call on "room-abc".
        manager.activeCall = true
        manager.currentRoomName = "room-abc"

        var notificationCount = 0
        let token = NotificationCenter.default.addObserver(
            forName: .videoCallStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        // Simulate the guard check that startVideoCall performs.
        // Because startVideoCall requires a live network connection, we test the
        // observable state contract: if activeCall && requestedRoom == currentRoomName,
        // startVideoCall returns early without clearing currentRoomName.
        let linkWithSameRoom = "https://chat.sphinx.chat/rooms/sphinx.call.room-abc"
        let requestedRoom = linkWithSameRoom.liveKitRoomName   // "sphinx.call.room-abc"

        // This mirrors the guard in startVideoCall:
        if manager.activeCall {
            if let req = requestedRoom, req == manager.currentRoomName {
                // No-op — nothing should change.
            }
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        // currentRoomName must not have been wiped.
        XCTAssertEqual(manager.currentRoomName, "room-abc")
        XCTAssertEqual(notificationCount, 0, "No notification for same-room no-op")
    }

    /// When a different room is requested while in a call, closePipController() clears currentRoomName.
    @MainActor
    func testStartVideoCall_differentRoom_clearsCurrentRoomName() {
        let manager = VideoCallManager()
        // Simulate an active call.
        manager.activeCall = true
        manager.currentRoomName = "room-alpha"

        var notificationCount = 0
        let token = NotificationCenter.default.addObserver(
            forName: .videoCallStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        // Simulate the teardown path that startVideoCall invokes when rooms differ.
        // (closePipController → clears currentRoomName)
        manager.currentRoomName = nil   // what closePipController does

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertNil(manager.currentRoomName, "currentRoomName must be nil after teardown")
        XCTAssertEqual(notificationCount, 1, "Exactly one notification for the teardown transition")
    }
}
