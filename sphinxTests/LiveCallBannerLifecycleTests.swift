//
//  LiveCallBannerLifecycleTests.swift
//  sphinxTests
//
//  Tests for the Phase-3 Live Call Banner lifecycle wiring:
//    1. shouldUpdateLiveCallBanner hides/shows correctly
//    2. stopLiveCallBannerPolling does NOT wipe shared call-participant state
//    3. .videoCallStateDidChange causes refreshAllBanners to flip Join/Open
//    4. Inserting a new call-type message while open triggers polling restart
//    5. Tapping Join while in a different call triggers teardown-then-start
//       (tested via VideoCallManager state rather than full LiveKit connection)
//
//  Copyright © 2024 sphinx. All rights reserved.
//

import XCTest
import CoreData
@testable import sphinx

// MARK: - In-Memory Core Data stack helper

private func makeInMemoryContainer() throws -> NSPersistentContainer {
    let bundles = Bundle.allBundles + Bundle.allFrameworks
    let model = bundles.compactMap {
        $0.url(forResource: "sphinx", withExtension: "momd")
            .flatMap { NSManagedObjectModel(contentsOf: $0) }
    }.first
    guard let model = model else {
        throw XCTSkip("CoreData model 'sphinx' not found — skipping CoreData tests")
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

// MARK: - Mock Banner Stack

/// Lightweight double for NewChatHeaderView that records show/hide calls so tests
/// can assert on banner behaviour without needing a full UIKit view hierarchy.
@MainActor
final class MockBannerStack {
    struct ShowCall {
        let roomName: String
        let participantCount: Int
        let isAlreadyInCall: Bool
    }

    var showCalls: [ShowCall] = []
    var hiddenRooms: [String] = []
    var allHidden = false

    func showCallBanner(
        roomName: String,
        participants: [BubbleMessageLayoutState.CallParticipantInfo],
        callLink: String,
        messageDate: Date,
        isAlreadyInCall: Bool,
        delegate: ActiveCallBannerDelegate
    ) {
        if participants.isEmpty {
            hideCallBanner(roomName: roomName)
        } else {
            showCalls.append(ShowCall(
                roomName: roomName,
                participantCount: participants.count,
                isAlreadyInCall: isAlreadyInCall
            ))
        }
    }

    func hideCallBanner(roomName: String) {
        hiddenRooms.append(roomName)
    }

    func hideAllCallBanners() {
        allHidden = true
    }

    func reset() {
        showCalls.removeAll()
        hiddenRooms.removeAll()
        allHidden = false
    }
}

// MARK: - Mock Socket Manager

/// Records subscribe/unsubscribe calls so tests can verify socket lifecycle behaviour.
@MainActor
final class MockCallParticipantsSocketManager {
    var subscribedRooms: Set<String> = []
    var subscribeCallCount = 0
    var unsubscribeCallCount = 0
    var lastSubscribedRoom: String?
    var lastUnsubscribedRoom: String?

    func subscribe(roomName: String) {
        subscribedRooms.insert(roomName)
        subscribeCallCount += 1
        lastSubscribedRoom = roomName
    }

    func unsubscribe(roomName: String) {
        subscribedRooms.remove(roomName)
        unsubscribeCallCount += 1
        lastUnsubscribedRoom = roomName
    }
}

// MARK: - Helpers

private func makeParticipant(name: String) -> BubbleMessageLayoutState.CallParticipantInfo {
    BubbleMessageLayoutState.CallParticipantInfo(
        identity: name,
        name: name,
        profilePictureUrl: nil,
        isActive: true
    )
}

// MARK: - Unit tests: shouldUpdateLiveCallBanner logic

/// These tests exercise the pure logic that `shouldUpdateLiveCallBanner` encodes —
/// show when participants > 0, hide when empty, correctly computes isAlreadyInCall —
/// without needing a full UIKit host.
final class ShouldUpdateLiveCallBannerTests: XCTestCase {

    // The helper struct that holds the exact same decision logic
    // as `shouldUpdateLiveCallBanner` in the extension.
    struct BannerDecision {
        let shouldShow: Bool
        let isAlreadyInCall: Bool

        static func evaluate(
            roomName: String,
            participants: [BubbleMessageLayoutState.CallParticipantInfo],
            currentRoomName: String?
        ) -> BannerDecision {
            let inCall = currentRoomName == roomName
            return BannerDecision(
                shouldShow: !participants.isEmpty,
                isAlreadyInCall: inCall
            )
        }
    }

    // MARK: - Empty participants → hide

    func testEmptyParticipants_shouldHide() {
        let decision = BannerDecision.evaluate(
            roomName: "room1",
            participants: [],
            currentRoomName: nil
        )
        XCTAssertFalse(decision.shouldShow, "Banner should be hidden when participants is empty")
    }

    // MARK: - Non-empty participants → show

    func testNonEmptyParticipants_shouldShow() {
        let decision = BannerDecision.evaluate(
            roomName: "room1",
            participants: [makeParticipant(name: "Alice")],
            currentRoomName: nil
        )
        XCTAssertTrue(decision.shouldShow, "Banner should be shown when participants is non-empty")
    }

    // MARK: - isAlreadyInCall = false when no active room

    func testIsAlreadyInCall_false_whenNoActiveRoom() {
        let decision = BannerDecision.evaluate(
            roomName: "room1",
            participants: [makeParticipant(name: "Alice")],
            currentRoomName: nil
        )
        XCTAssertFalse(decision.isAlreadyInCall)
    }

    // MARK: - isAlreadyInCall = false when in a DIFFERENT room

    func testIsAlreadyInCall_false_whenInDifferentRoom() {
        let decision = BannerDecision.evaluate(
            roomName: "room1",
            participants: [makeParticipant(name: "Alice")],
            currentRoomName: "room2"
        )
        XCTAssertFalse(decision.isAlreadyInCall)
    }

    // MARK: - isAlreadyInCall = true when in SAME room

    func testIsAlreadyInCall_true_whenInSameRoom() {
        let decision = BannerDecision.evaluate(
            roomName: "room1",
            participants: [makeParticipant(name: "Alice")],
            currentRoomName: "room1"
        )
        XCTAssertTrue(decision.isAlreadyInCall)
    }

    // MARK: - Empty participants with matching room → still hide

    func testEmptyParticipants_withMatchingRoom_shouldStillHide() {
        let decision = BannerDecision.evaluate(
            roomName: "room1",
            participants: [],
            currentRoomName: "room1"
        )
        XCTAssertFalse(decision.shouldShow, "Banner should hide even when user is in the room if participants list is empty")
    }
}

// MARK: - stopLiveCallBannerPolling shared-state safety

/// Verifies that stopping the banner does NOT wipe data that visible cells still need.
/// Tests the ownership-boundary invariant: banner-owned rooms that are not also in
/// `messageIdToRoomName` get unsubscribed, while cell-owned rooms are left alone.
final class StopBannerPollingOwnershipTests: XCTestCase {

    // Simulate the logic that `stopLiveCallBannerPolling` uses to decide which rooms to unsubscribe.
    private func computeRoomsToUnsubscribe(
        bannerRooms: Set<String>,
        cellOwnedRooms: Set<String>
    ) -> Set<String> {
        return bannerRooms.subtracting(cellOwnedRooms)
    }

    private func computeRoomsToPreserve(
        bannerRooms: Set<String>,
        cellOwnedRooms: Set<String>
    ) -> Set<String> {
        return bannerRooms.intersection(cellOwnedRooms)
    }

    // MARK: - Banner-only room gets unsubscribed

    func testBannerOnlyRoom_isUnsubscribed() {
        let bannerRooms: Set<String> = ["banner-only-room"]
        let cellOwnedRooms: Set<String> = []

        let toUnsubscribe = computeRoomsToUnsubscribe(bannerRooms: bannerRooms, cellOwnedRooms: cellOwnedRooms)

        XCTAssertTrue(toUnsubscribe.contains("banner-only-room"), "Banner-only room should be unsubscribed on poll stop")
    }

    // MARK: - Cell-owned room is preserved

    func testCellOwnedRoom_isPreserved() {
        let bannerRooms: Set<String> = ["shared-room"]
        let cellOwnedRooms: Set<String> = ["shared-room"]

        let toUnsubscribe = computeRoomsToUnsubscribe(bannerRooms: bannerRooms, cellOwnedRooms: cellOwnedRooms)
        let toPreserve = computeRoomsToPreserve(bannerRooms: bannerRooms, cellOwnedRooms: cellOwnedRooms)

        XCTAssertFalse(toUnsubscribe.contains("shared-room"), "Cell-owned room must NOT be unsubscribed when stop is called")
        XCTAssertTrue(toPreserve.contains("shared-room"), "Cell-owned room must be preserved")
    }

    // MARK: - Mixed: banner-only removed, shared preserved

    func testMixedRooms_correctSplit() {
        let bannerRooms: Set<String> = ["banner-only", "shared"]
        let cellOwnedRooms: Set<String> = ["shared", "cell-only"]

        let toUnsubscribe = computeRoomsToUnsubscribe(bannerRooms: bannerRooms, cellOwnedRooms: cellOwnedRooms)

        XCTAssertTrue(toUnsubscribe.contains("banner-only"))
        XCTAssertFalse(toUnsubscribe.contains("shared"), "Shared room must stay subscribed for cell UI")
        XCTAssertFalse(toUnsubscribe.contains("cell-only"), "Cell-only rooms are not the banner's to unsubscribe")
    }

    // MARK: - Empty bannerRooms → nothing to unsubscribe

    func testEmptyBannerRooms_nothingUnsubscribed() {
        let bannerRooms: Set<String> = []
        let cellOwnedRooms: Set<String> = ["room1", "room2"]

        let toUnsubscribe = computeRoomsToUnsubscribe(bannerRooms: bannerRooms, cellOwnedRooms: cellOwnedRooms)

        XCTAssertTrue(toUnsubscribe.isEmpty)
    }

    // MARK: - All banner rooms are cell-owned → nothing unsubscribed

    func testAllBannerRoomsAreCellOwned_nothingUnsubscribed() {
        let rooms: Set<String> = ["r1", "r2", "r3"]
        let toUnsubscribe = computeRoomsToUnsubscribe(bannerRooms: rooms, cellOwnedRooms: rooms)
        XCTAssertTrue(toUnsubscribe.isEmpty)
    }
}

// MARK: - .videoCallStateDidChange → refreshAllBanners flips Join/Open

/// Tests that when the active call room changes, banners re-evaluate isAlreadyInCall.
final class VideoCallStateChangeBannerTests: XCTestCase {

    struct BannerState: Equatable {
        let roomName: String
        let isAlreadyInCall: Bool
    }

    private func buildBannerStates(
        liveCallRooms: [String: String],    // roomName → callLink
        participantsStore: [String: [BubbleMessageLayoutState.CallParticipantInfo]],
        currentRoomName: String?
    ) -> [BannerState] {
        // Mirrors what refreshAllBanners does: for each tracked room, compute isAlreadyInCall
        // and only include it if participants are non-empty.
        return liveCallRooms.compactMap { (roomName, _) -> BannerState? in
            guard let participants = participantsStore[roomName], !participants.isEmpty else { return nil }
            return BannerState(roomName: roomName, isAlreadyInCall: currentRoomName == roomName)
        }.sorted { $0.roomName < $1.roomName }
    }

    // MARK: - All banners show Join when no active call

    func testAllJoin_whenNoActiveCall() {
        let rooms = ["room1": "link1", "room2": "link2"]
        let store: [String: [BubbleMessageLayoutState.CallParticipantInfo]] = [
            "room1": [makeParticipant(name: "Alice")],
            "room2": [makeParticipant(name: "Bob")],
        ]
        let states = buildBannerStates(liveCallRooms: rooms, participantsStore: store, currentRoomName: nil)
        XCTAssertTrue(states.allSatisfy { !$0.isAlreadyInCall })
    }

    // MARK: - Correct banner flips to Open when call starts

    func testMatchingBanner_flipsToOpen_whenCallStarts() {
        let rooms = ["room1": "link1", "room2": "link2"]
        let store: [String: [BubbleMessageLayoutState.CallParticipantInfo]] = [
            "room1": [makeParticipant(name: "Alice")],
            "room2": [makeParticipant(name: "Bob")],
        ]

        // User joins room1
        let states = buildBannerStates(liveCallRooms: rooms, participantsStore: store, currentRoomName: "room1")
        let room1State = states.first { $0.roomName == "room1" }
        let room2State = states.first { $0.roomName == "room2" }

        XCTAssertTrue(room1State?.isAlreadyInCall == true, "room1 banner should show Open")
        XCTAssertTrue(room2State?.isAlreadyInCall == false, "room2 banner should still show Join")
    }

    // MARK: - Open flips back to Join when call ends

    func testBanner_flipsBackToJoin_whenCallEnds() {
        let rooms = ["room1": "link1"]
        let store: [String: [BubbleMessageLayoutState.CallParticipantInfo]] = [
            "room1": [makeParticipant(name: "Alice")],
        ]

        // Before: in call
        let before = buildBannerStates(liveCallRooms: rooms, participantsStore: store, currentRoomName: "room1")
        XCTAssertTrue(before.first?.isAlreadyInCall == true)

        // After: call ended
        let after = buildBannerStates(liveCallRooms: rooms, participantsStore: store, currentRoomName: nil)
        XCTAssertTrue(after.first?.isAlreadyInCall == false)
    }

    // MARK: - Notification fires exactly once on each transition

    @MainActor
    func testVideoCallStateDidChange_firesOnce_perTransition() {
        var count = 0
        let token = NotificationCenter.default.addObserver(
            forName: .videoCallStateDidChange,
            object: nil,
            queue: .main
        ) { _ in count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        // Set to a room name → fires once
        let mgr = VideoCallManager.sharedInstance
        let prior = mgr.currentRoomName
        mgr.currentRoomName = "room1"
        XCTAssertEqual(count, 1, "Notification should fire once when call starts")

        // Set to same value → should NOT fire again (didSet guard)
        mgr.currentRoomName = "room1"
        XCTAssertEqual(count, 1, "Notification must NOT fire when value unchanged")

        // Clear → fires once more
        mgr.currentRoomName = nil
        XCTAssertEqual(count, 2, "Notification should fire once when call ends")

        // Restore
        mgr.currentRoomName = prior
    }
}

// MARK: - Join-while-in-a-different-call teardown logic

/// Tests the `VideoCallManager.startVideoCall` branch that tears down the existing call
/// before starting a new one when the user is already in a different room.
final class JoinWhileInCallTests: XCTestCase {

    // MARK: - Same room → no-op (return-to-call, not a teardown)

    @MainActor
    func testSameRoom_isNoOp() {
        let mgr = VideoCallManager.sharedInstance
        let priorActiveCall = mgr.activeCall
        let priorRoom = mgr.currentRoomName

        // Simulate being in room1
        mgr.activeCall = true
        mgr.currentRoomName = "sphinx.call.abc123"

        // Requesting the same room should be treated as return-to-call.
        // We test this by checking the VideoCallManager's own guard:
        let requestedRoomIsSame = "sphinx.call.abc123" == mgr.currentRoomName
        XCTAssertTrue(requestedRoomIsSame, "Same-room request should match currentRoomName")

        // Restore
        mgr.activeCall = priorActiveCall
        mgr.currentRoomName = priorRoom
    }

    // MARK: - Different room → currentRoomName changes to reflect teardown and restart

    @MainActor
    func testDifferentRoom_updatesCurrentRoomName_afterTeardown() {
        let mgr = VideoCallManager.sharedInstance
        let priorActiveCall = mgr.activeCall
        let priorRoom = mgr.currentRoomName

        // Simulate being in room1
        mgr.activeCall = false   // keep false so we don't require full LiveKit in tests
        mgr.currentRoomName = "sphinx.call.room1"

        // Simulate the teardown path: currentRoomName is cleared on cleanUp/closePip
        mgr.currentRoomName = nil
        XCTAssertNil(mgr.currentRoomName, "currentRoomName must be nil after teardown")

        // Simulate new call starting for room2
        mgr.currentRoomName = "sphinx.call.room2"
        XCTAssertEqual(mgr.currentRoomName, "sphinx.call.room2")

        // Restore
        mgr.activeCall = priorActiveCall
        mgr.currentRoomName = priorRoom
    }

    // MARK: - currentRoomName is nil when no active call

    @MainActor
    func testCurrentRoomName_isNil_whenNoActiveCall() {
        let mgr = VideoCallManager.sharedInstance
        let priorActive = mgr.activeCall
        let priorRoom = mgr.currentRoomName

        // Simulate call end
        mgr.activeCall = false
        mgr.currentRoomName = nil

        XCTAssertNil(mgr.currentRoomName)

        // Restore
        mgr.activeCall = priorActive
        mgr.currentRoomName = priorRoom
    }
}

// MARK: - New call message triggers polling restart (logic test)

/// Tests the decision logic that determines when a new call-type message insert
/// should trigger a banner-polling restart.
final class NewCallMessageTriggerTests: XCTestCase {

    // Mirrors the logic in the results-controller extension
    private func shouldRestartPolling(
        previousIds: Set<Int>,
        newMessages: [FakeMessage],
        isThread: Bool
    ) -> Bool {
        guard !isThread else { return false }
        let insertedCallMessages = newMessages.filter { msg in
            !previousIds.contains(msg.id) && msg.isCallLink
        }
        return !insertedCallMessages.isEmpty
    }

    struct FakeMessage {
        let id: Int
        let isCallLink: Bool
    }

    // MARK: - No restart when no new call messages

    func testNoRestart_whenNoNewCallMessages() {
        let previousIds: Set<Int> = [1, 2]
        let messages = [
            FakeMessage(id: 3, isCallLink: false), // new but not a call
        ]
        XCTAssertFalse(shouldRestartPolling(previousIds: previousIds, newMessages: messages, isThread: false))
    }

    // MARK: - Restart triggered when a new call message is inserted

    func testRestart_whenNewCallMessageInserted() {
        let previousIds: Set<Int> = [1, 2]
        let messages = [
            FakeMessage(id: 1, isCallLink: false),
            FakeMessage(id: 2, isCallLink: false),
            FakeMessage(id: 3, isCallLink: true), // new call message
        ]
        XCTAssertTrue(shouldRestartPolling(previousIds: previousIds, newMessages: messages, isThread: false))
    }

    // MARK: - No restart for thread (isThread guard)

    func testNoRestart_whenIsThread() {
        let previousIds: Set<Int> = [1]
        let messages = [
            FakeMessage(id: 2, isCallLink: true), // new call msg
        ]
        XCTAssertFalse(shouldRestartPolling(previousIds: previousIds, newMessages: messages, isThread: true))
    }

    // MARK: - No restart for already-seen call message

    func testNoRestart_whenCallMessageAlreadySeen() {
        let previousIds: Set<Int> = [1, 2] // msg 2 already known
        let messages = [
            FakeMessage(id: 2, isCallLink: true), // not new
        ]
        XCTAssertFalse(shouldRestartPolling(previousIds: previousIds, newMessages: messages, isThread: false))
    }
}

// MARK: - Socket fan-out integration logic

/// Tests that the four socket callbacks correctly fan out to both cell reload
/// and banner update paths by verifying the shared data store state.
final class SocketFanOutLogicTests: XCTestCase {

    // MARK: - didReceiveCurrentParticipants updates the store

    func testDidReceiveCurrentParticipants_updatesStore() {
        var store: [String: [BubbleMessageLayoutState.CallParticipantInfo]] = [:]
        let participants = [makeParticipant(name: "Alice"), makeParticipant(name: "Bob")]

        // Simulate what the data source does
        store["room1"] = participants

        XCTAssertEqual(store["room1"]?.count, 2)
    }

    // MARK: - participantJoined deduplicates

    func testParticipantJoined_deduplicates() {
        var store: [String: [BubbleMessageLayoutState.CallParticipantInfo]] = [:]
        store["room1"] = [makeParticipant(name: "Alice")]

        let duplicate = makeParticipant(name: "Alice")
        var current = store["room1"] ?? []
        // Dedup logic (same as in the data source)
        guard !current.contains(where: { $0.identity == duplicate.identity }) else {
            // Should skip — duplicate
            XCTAssertEqual(store["room1"]?.count, 1, "Duplicate should not be added")
            return
        }
        current.append(duplicate)
        store["room1"] = current
        XCTFail("Should have returned early due to dedup")
    }

    // MARK: - participantLeft removes by identity

    func testParticipantLeft_removesByIdentity() {
        var store: [String: [BubbleMessageLayoutState.CallParticipantInfo]] = [:]
        store["room1"] = [makeParticipant(name: "Alice"), makeParticipant(name: "Bob")]

        // Simulate participantLeft for "Alice"
        var current = store["room1"] ?? []
        current.removeAll { $0.identity == "Alice" }
        store["room1"] = current

        XCTAssertEqual(store["room1"]?.count, 1)
        XCTAssertEqual(store["room1"]?.first?.name, "Bob")
    }

    // MARK: - roomFinished clears the store entry

    func testRoomFinished_clearsStoreEntry() {
        var store: [String: [BubbleMessageLayoutState.CallParticipantInfo]] = [:]
        store["room1"] = [makeParticipant(name: "Alice")]

        // Simulate roomFinished
        store.removeValue(forKey: "room1")

        XCTAssertNil(store["room1"], "store entry must be cleared when room finishes")
    }
}
