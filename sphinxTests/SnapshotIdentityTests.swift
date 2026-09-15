//
//  SnapshotIdentityTests.swift
//  sphinxTests
//
//  Snapshot-identity coverage for chat cell reloads.
//
//  Production crash: NSInternalInconsistencyException —
//  "Attempted to reload item identifier that does not exist in the snapshot".
//  Cell reloads captured a MessageTableCellState, hopped to the main actor, then
//  called snapshot.reloadItems after FRC rebuilt the list.
//
//  `itemIdentifiers.contains` can return true because MessageTableCellState.== is
//  content-based (does not include uniqueID). UIKit still requires the live
//  instance currently in the snapshot being mutated. These tests lock in
//  re-resolving by message id from itemIdentifiers, never Hashable/`==`.
//

import XCTest
import CoreData
@testable import sphinx

private func makeInMemoryContainer() throws -> NSPersistentContainer {
    guard let modelURL = Bundle(for: SnapshotIdentityTests.self).url(forResource: "sphinx", withExtension: "momd"),
          let mom = NSManagedObjectModel(contentsOf: modelURL) else {
        let bundles = Bundle.allBundles + Bundle.allFrameworks
        let model = bundles.compactMap {
            $0.url(forResource: "sphinx", withExtension: "momd")
                .flatMap { NSManagedObjectModel(contentsOf: $0) }
        }.first
        guard let model = model else {
            throw XCTSkip("CoreData model 'sphinx' not found in test bundle")
        }
        return try loadInMemoryContainer(model: model)
    }
    return try loadInMemoryContainer(model: mom)
}

private func loadInMemoryContainer(model: NSManagedObjectModel) throws -> NSPersistentContainer {
    let container = NSPersistentContainer(name: "sphinx", managedObjectModel: model)
    let desc = NSPersistentStoreDescription()
    desc.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [desc]
    var loadError: Error?
    container.loadPersistentStores { _, error in loadError = error }
    if let err = loadError { throw err }
    return container
}

@MainActor
private final class SnapshotIdentityFixtures {
    let container: NSPersistentContainer
    let chat: Chat
    let owner: UserContact

    init() throws {
        container = try makeInMemoryContainer()
        let ctx = container.viewContext

        let chat = NSEntityDescription.insertNewObject(forEntityName: "Chat", into: ctx) as! Chat
        chat.id = 1
        chat.createdAt = Date()
        self.chat = chat

        let owner = NSEntityDescription.insertNewObject(forEntityName: "UserContact", into: ctx) as! UserContact
        owner.id = 1
        owner.createdAt = Date()
        owner.isOwner = true
        self.owner = owner
    }

    func makeMessage(id: Int, type: Int = 32) -> TransactionMessage {
        let message = NSEntityDescription.insertNewObject(
            forEntityName: "TransactionMessage",
            into: container.viewContext
        ) as! TransactionMessage
        message.id = id
        message.createdAt = Date()
        message.updatedAt = Date()
        message.type = type
        message.status = 0
        message.chat = chat
        return message
    }

    func makeCellState(
        message: TransactionMessage,
        threadOriginalMessage: TransactionMessage? = nil,
        isThreadHeaderMessage: Bool = false
    ) -> MessageTableCellState {
        MessageTableCellState(
            message: message,
            threadOriginalMessage: threadOriginalMessage,
            chat: chat,
            owner: owner,
            contact: nil,
            tribeAdmin: nil,
            isThreadHeaderMessage: isThreadHeaderMessage
        )
    }

    func makeThreadCellState(
        originalMessage: TransactionMessage,
        threadMessages: [TransactionMessage]
    ) -> ThreadTableCellState {
        ThreadTableCellState(
            originalMessage: originalMessage,
            threadMessages: threadMessages,
            owner: owner
        )
    }
}

@MainActor
final class SnapshotIdentityTests: XCTestCase {

    func testStaleEqualInstanceIsNotTheLiveSnapshotIdentifier() throws {
        let fixtures = try SnapshotIdentityFixtures()
        let message = fixtures.makeMessage(id: 32)
        let live = fixtures.makeCellState(message: message)
        let stale = fixtures.makeCellState(message: message)

        XCTAssertEqual(live, stale, "content-based == is the production trap")
        XCTAssertNotEqual(live.uniqueID, stale.uniqueID)

        var snapshot = NSDiffableDataSourceSnapshot<
            NewChatTableDataSource.CollectionViewSection,
            MessageTableCellState
        >()
        snapshot.appendSections([.messages])
        snapshot.appendItems([live], toSection: .messages)

        XCTAssertTrue(
            snapshot.itemIdentifiers.contains(stale),
            "contains uses ==, so a captured struct can look present"
        )
        XCTAssertEqual(snapshot.itemIdentifiers.first?.uniqueID, live.uniqueID)

        let resolved = NewChatTableDataSource.liveSnapshotItems(
            in: snapshot,
            messageIds: [32]
        )
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.uniqueID, live.uniqueID)
        XCTAssertNotEqual(resolved.first?.uniqueID, stale.uniqueID)
    }

    func testRebuildReplacesRowWithLiveInstanceNotCapturedEqualMatch() throws {
        let fixtures = try SnapshotIdentityFixtures()
        let message = fixtures.makeMessage(id: 32)
        let original = fixtures.makeCellState(message: message)
        let stale = fixtures.makeCellState(message: message)
        let replacement = fixtures.makeCellState(message: message)

        var snapshot = NSDiffableDataSourceSnapshot<
            NewChatTableDataSource.CollectionViewSection,
            MessageTableCellState
        >()
        snapshot.appendSections([.messages])
        snapshot.appendItems([original], toSection: .messages)

        snapshot = NSDiffableDataSourceSnapshot<
            NewChatTableDataSource.CollectionViewSection,
            MessageTableCellState
        >()
        snapshot.appendSections([.messages])
        snapshot.appendItems([replacement], toSection: .messages)

        XCTAssertTrue(snapshot.itemIdentifiers.contains(stale))
        XCTAssertNotEqual(snapshot.itemIdentifiers.first?.uniqueID, original.uniqueID)
        XCTAssertNotEqual(snapshot.itemIdentifiers.first?.uniqueID, stale.uniqueID)

        let resolved = NewChatTableDataSource.liveSnapshotItems(
            in: snapshot,
            messageIds: [32]
        )
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.uniqueID, replacement.uniqueID)
        XCTAssertNotEqual(resolved.first?.uniqueID, stale.uniqueID)
        XCTAssertNotEqual(resolved.first?.uniqueID, original.uniqueID)
    }

    func testGoneMessageIdSkipsReloadAndDoesNotReturnStaleInstance() throws {
        let fixtures = try SnapshotIdentityFixtures()
        let message = fixtures.makeMessage(id: 32)
        let live = fixtures.makeCellState(message: message)
        let stale = fixtures.makeCellState(message: message)

        var snapshot = NSDiffableDataSourceSnapshot<
            NewChatTableDataSource.CollectionViewSection,
            MessageTableCellState
        >()
        snapshot.appendSections([.messages])
        snapshot.appendItems([live], toSection: .messages)
        snapshot.deleteItems([live])

        XCTAssertFalse(snapshot.itemIdentifiers.contains(where: { $0.messageId == 32 }))

        let resolved = NewChatTableDataSource.liveSnapshotItems(
            in: snapshot,
            messageIds: [32]
        )
        XCTAssertTrue(resolved.isEmpty)
        XCTAssertFalse(resolved.contains(where: { $0.uniqueID == stale.uniqueID }))
        XCTAssertFalse(resolved.contains(where: { $0.uniqueID == live.uniqueID }))
    }

    func testThreadOriginalMessageIdResolvesLiveRow() throws {
        let fixtures = try SnapshotIdentityFixtures()
        let original = fixtures.makeMessage(id: 10)
        let reply = fixtures.makeMessage(id: 11, type: 0)
        let live = fixtures.makeCellState(
            message: reply,
            threadOriginalMessage: original
        )

        var snapshot = NSDiffableDataSourceSnapshot<
            NewChatTableDataSource.CollectionViewSection,
            MessageTableCellState
        >()
        snapshot.appendSections([.messages])
        snapshot.appendItems([live], toSection: .messages)

        let byReply = NewChatTableDataSource.liveSnapshotItems(
            in: snapshot,
            messageIds: [11]
        )
        let byOriginal = NewChatTableDataSource.liveSnapshotItems(
            in: snapshot,
            messageIds: [10]
        )

        XCTAssertEqual(byReply.first?.uniqueID, live.uniqueID)
        XCTAssertEqual(byOriginal.first?.uniqueID, live.uniqueID)
    }

    func testThreadsListResolvesLiveInstanceByOriginalMessageId() throws {
        let fixtures = try SnapshotIdentityFixtures()
        let original = fixtures.makeMessage(id: 20)
        let reply = fixtures.makeMessage(id: 21, type: 0)
        let live = fixtures.makeThreadCellState(
            originalMessage: original,
            threadMessages: [reply]
        )
        let stale = fixtures.makeThreadCellState(
            originalMessage: original,
            threadMessages: [reply]
        )
        let replacement = fixtures.makeThreadCellState(
            originalMessage: original,
            threadMessages: [reply]
        )

        XCTAssertEqual(live, stale)

        var snapshot = NSDiffableDataSourceSnapshot<
            ThreadsListDataSource.CollectionViewSection,
            ThreadTableCellState
        >()
        snapshot.appendSections([.threads])
        snapshot.appendItems([live], toSection: .threads)

        XCTAssertTrue(snapshot.itemIdentifiers.contains(stale))
        XCTAssertEqual(
            ThreadsListDataSource.liveSnapshotItem(in: snapshot, messageId: 20)?.originalMessage?.id,
            20
        )

        snapshot = NSDiffableDataSourceSnapshot<
            ThreadsListDataSource.CollectionViewSection,
            ThreadTableCellState
        >()
        snapshot.appendSections([.threads])
        snapshot.appendItems([replacement], toSection: .threads)

        let resolved = ThreadsListDataSource.liveSnapshotItem(in: snapshot, messageId: 20)
        XCTAssertEqual(resolved?.originalMessage?.id, 20)
        XCTAssertNil(ThreadsListDataSource.liveSnapshotItem(in: snapshot, messageId: 999))
    }

    func testCacheWriteIsIndependentOfSnapshotSkip() {
        var mediaCached: [Int: MessageTableCellState.MediaData] = [:]
        let messageId = 32
        let updated = MessageTableCellState.MediaData()

        mediaCached[messageId] = updated

        var snapshot = NSDiffableDataSourceSnapshot<
            NewChatTableDataSource.CollectionViewSection,
            MessageTableCellState
        >()
        snapshot.appendSections([.messages])

        let resolved = NewChatTableDataSource.liveSnapshotItems(
            in: snapshot,
            messageIds: [messageId]
        )
        XCTAssertTrue(resolved.isEmpty)
        XCTAssertNotNil(mediaCached[messageId])
    }
}
