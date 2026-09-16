//
//  ChatListSnapshotIdentityTests.swift
//  sphinxTests
//
//  Chat-list DiffableDataSource identity must be objectId-only. Hashable
//  contract violations here caused NSInternalInconsistencyException inside
//  CollectionViewCore and a production SIGABRT.
//

import XCTest
@testable import sphinx

final class ChatListSnapshotIdentityTests: XCTestCase {

    typealias DataSourceItem = ChatsCollectionViewController.DataSourceItem

    func testDataSourceItemEqualityAndHashAreObjectIdOnly() {
        let first = DataSourceItem(objectId: "chat-1")
        let second = DataSourceItem(objectId: "chat-1")
        let other = DataSourceItem(objectId: "chat-2")

        XCTAssertEqual(first, second)
        XCTAssertEqual(hashValue(of: first), hashValue(of: second))
        XCTAssertNotEqual(first, other)
        XCTAssertEqual(Set([first, second, other]).count, 2)
    }

    func testUniqueByObjectIdDropsDuplicatesFirstWinsAndPreservesOrder() {
        let items = [
            DataSourceItem(objectId: "a"),
            DataSourceItem(objectId: "b"),
            DataSourceItem(objectId: "a"),
            DataSourceItem(objectId: "c"),
            DataSourceItem(objectId: "b"),
            DataSourceItem(objectId: "d")
        ]

        let unique = DataSourceItem.uniqueByObjectId(items)

        XCTAssertEqual(unique.map(\.objectId), ["a", "b", "c", "d"])
    }

    func testUniqueByObjectIdEmptyAndAlreadyUnique() {
        XCTAssertTrue(DataSourceItem.uniqueByObjectId([]).isEmpty)

        let uniqueItems = [
            DataSourceItem(objectId: "x"),
            DataSourceItem(objectId: "y")
        ]
        XCTAssertEqual(
            DataSourceItem.uniqueByObjectId(uniqueItems).map(\.objectId),
            ["x", "y"]
        )
    }

    func testApplyGateCoalescesOverlappingRefreshes() {
        var gate = ChatListSnapshotApplyGate()

        XCTAssertTrue(gate.beginApplyIfIdle())
        XCTAssertTrue(gate.isApplying)
        XCTAssertFalse(gate.needsApply)

        XCTAssertFalse(gate.beginApplyIfIdle())
        XCTAssertFalse(gate.beginApplyIfIdle())
        XCTAssertTrue(gate.isApplying)
        XCTAssertTrue(gate.needsApply)

        XCTAssertTrue(gate.finishApply())
        XCTAssertFalse(gate.isApplying)
        XCTAssertFalse(gate.needsApply)

        XCTAssertTrue(gate.beginApplyIfIdle())
        XCTAssertFalse(gate.finishApply())
        XCTAssertFalse(gate.isApplying)
        XCTAssertFalse(gate.needsApply)
    }

    func testApplyGateResetDropsInFlightAndPendingState() {
        var gate = ChatListSnapshotApplyGate()
        XCTAssertTrue(gate.beginApplyIfIdle())
        XCTAssertFalse(gate.beginApplyIfIdle())

        gate.reset()

        XCTAssertFalse(gate.isApplying)
        XCTAssertFalse(gate.needsApply)
        XCTAssertTrue(gate.beginApplyIfIdle())
    }

    private func hashValue(of item: DataSourceItem) -> Int {
        var hasher = Hasher()
        item.hash(into: &hasher)
        return hasher.finalize()
    }
}
