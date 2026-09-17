//
//  ChatListSnapshotIdentityTests.swift
//  sphinxTests
//
//  Chat-list DiffableDataSource identity must be objectId-only. Hashable
//  contract violations here caused NSInternalInconsistencyException inside
//  CollectionViewCore and a production SIGABRT.
//

import XCTest
import UIKit
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

    func testApplyGateFinishApplyIsIdempotentAndDoesNotSwallowQueuedUpdates() {
        var gate = ChatListSnapshotApplyGate()

        XCTAssertFalse(gate.finishApply())
        XCTAssertFalse(gate.isApplying)
        XCTAssertFalse(gate.needsApply)

        XCTAssertTrue(gate.beginApplyIfIdle())
        XCTAssertFalse(gate.beginApplyIfIdle())
        XCTAssertTrue(gate.needsApply)

        XCTAssertTrue(gate.finishApply())
        XCTAssertFalse(gate.isApplying)
        XCTAssertFalse(gate.needsApply)

        // Spurious second release must not report a pending apply.
        XCTAssertFalse(gate.finishApply())
        XCTAssertFalse(gate.isApplying)
        XCTAssertFalse(gate.needsApply)
    }

    func testApplySnapshotFailClosedRecoversFromDuplicateIdentifiersAndReleasesGate() {
        typealias Section = ChatsCollectionViewController.CollectionViewSection
        typealias Item = ChatsCollectionViewController.DataSourceItem
        typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

        let duplicateItems = [
            Item(objectId: "dup"),
            Item(objectId: "dup")
        ]
        XCTAssertEqual(Item.uniqueByObjectId(duplicateItems).map(\.objectId), ["dup"])

        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480),
            collectionViewLayout: layout
        )
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")

        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { collectionView, indexPath, _ in
            collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        }

        let viewController = ChatsCollectionViewController(collectionViewLayout: layout)
        viewController.dataSource = dataSource
        viewController.snapshotGeneration = 1
        XCTAssertTrue(viewController.applyGate.beginApplyIfIdle())

        var capturedEvents: [(reason: String?, fallbackSucceeded: Bool)] = []
        viewController.onCollectionViewExceptionCaptured = { reason, fallbackSucceeded in
            capturedEvents.append((reason, fallbackSucceeded))
        }

        // Snapshot APIs refuse duplicate identifiers; simulate the UIKit
        // NSInternalInconsistencyException that apply would throw if duplicates
        // slipped past uniqueByObjectId.
        viewController.testForcePrimaryApplyExceptionReason =
            "Fatal: supplied item identifiers are not unique. Duplicate identifiers: {dup}"

        var snapshot = Snapshot()
        snapshot.appendSections([.all])
        snapshot.appendItems([Item(objectId: "dup")], toSection: .all)

        let completionExpectation = expectation(description: "fail-closed completion")
        var completionCount = 0

        viewController.applySnapshotFailClosed(
            snapshot,
            on: dataSource,
            generation: 1
        ) {
            completionCount += 1
            _ = viewController.applyGate.finishApply()
            completionExpectation.fulfill()
        }

        wait(for: [completionExpectation], timeout: 2.0)

        XCTAssertEqual(completionCount, 1, "fail-closed completion must run once (no deadlock / no double-fire)")
        XCTAssertFalse(viewController.applyGate.isApplying, "apply gate must be released")
        XCTAssertFalse(capturedEvents.isEmpty, "captureCollectionViewException must be invoked")
        XCTAssertEqual(
            capturedEvents.first?.reason,
            "Fatal: supplied item identifiers are not unique. Duplicate identifiers: {dup}"
        )
    }

    private func hashValue(of item: DataSourceItem) -> Int {
        var hasher = Hasher()
        item.hash(into: &hasher)
        return hasher.finalize()
    }
}
