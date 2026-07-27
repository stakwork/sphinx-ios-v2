//
//  ActiveCallBannerTests.swift
//  sphinxTests
//
//  Unit tests for:
//    1. NewChatHeaderView.sortAndTrim – pure sort/trim logic
//    2. ActiveCallBannerView.configureWith – button label & participant row
//
//  Copyright © 2024 sphinx. All rights reserved.
//

import XCTest
@testable import sphinx

// MARK: - Helpers

private func makeParticipant(name: String) -> BubbleMessageLayoutState.CallParticipantInfo {
    BubbleMessageLayoutState.CallParticipantInfo(
        identity: name,
        name: name,
        profilePictureUrl: nil,
        isActive: true
    )
}

private func makeDate(daysAgo: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
}

// MARK: - Sort & Trim Tests

final class ActiveCallBannerSortTrimTests: XCTestCase {

    private var headerView: NewChatHeaderView!

    override func setUp() {
        super.setUp()
        headerView = NewChatHeaderView(frame: .zero)
    }

    override func tearDown() {
        headerView = nil
        super.tearDown()
    }

    // MARK: Empty input

    func testSortTrim_EmptyInput_ReturnsEmpty() {
        let (visible, overflow) = headerView.sortAndTrim(entries: [], maxVisible: 3)
        XCTAssertTrue(visible.isEmpty)
        XCTAssertTrue(overflow.isEmpty)
    }

    // MARK: Fewer entries than maxVisible

    func testSortTrim_OneEntry_AllVisible() {
        let entries = [(roomName: "room1", messageDate: makeDate(daysAgo: 0))]
        let (visible, overflow) = headerView.sortAndTrim(entries: entries, maxVisible: 3)
        XCTAssertEqual(visible.count, 1)
        XCTAssertTrue(overflow.isEmpty)
        XCTAssertEqual(visible.first?.roomName, "room1")
    }

    func testSortTrim_ThreeEntries_AllVisible_NewestFirst() {
        let entries = [
            (roomName: "old",    messageDate: makeDate(daysAgo: 2)),
            (roomName: "newest", messageDate: makeDate(daysAgo: 0)),
            (roomName: "middle", messageDate: makeDate(daysAgo: 1)),
        ]
        let (visible, overflow) = headerView.sortAndTrim(entries: entries, maxVisible: 3)
        XCTAssertEqual(visible.count, 3)
        XCTAssertTrue(overflow.isEmpty)
        XCTAssertEqual(visible[0].roomName, "newest")
        XCTAssertEqual(visible[1].roomName, "middle")
        XCTAssertEqual(visible[2].roomName, "old")
    }

    // MARK: Exactly maxVisible entries

    func testSortTrim_ExactlyMaxVisible_NoOverflow() {
        let entries = [
            (roomName: "a", messageDate: makeDate(daysAgo: 0)),
            (roomName: "b", messageDate: makeDate(daysAgo: 1)),
            (roomName: "c", messageDate: makeDate(daysAgo: 2)),
        ]
        let (visible, overflow) = headerView.sortAndTrim(entries: entries, maxVisible: 3)
        XCTAssertEqual(visible.count, 3)
        XCTAssertTrue(overflow.isEmpty)
    }

    // MARK: More entries than maxVisible

    func testSortTrim_FourEntries_TrimsToThree() {
        let entries = [
            (roomName: "oldest",  messageDate: makeDate(daysAgo: 3)),
            (roomName: "a",       messageDate: makeDate(daysAgo: 0)),
            (roomName: "b",       messageDate: makeDate(daysAgo: 1)),
            (roomName: "c",       messageDate: makeDate(daysAgo: 2)),
        ]
        let (visible, overflow) = headerView.sortAndTrim(entries: entries, maxVisible: 3)
        XCTAssertEqual(visible.count, 3)
        XCTAssertEqual(overflow.count, 1)
        XCTAssertEqual(overflow.first?.roomName, "oldest")
    }

    func testSortTrim_VisibleAreNewestFirst() {
        // 5 rooms, newest-first → only top 3 visible
        let entries = (0..<5).map { i in
            (roomName: "room\(i)", messageDate: makeDate(daysAgo: i))
        }
        let (visible, overflow) = headerView.sortAndTrim(entries: entries, maxVisible: 3)
        XCTAssertEqual(visible.map(\.roomName), ["room0", "room1", "room2"])
        XCTAssertEqual(overflow.map(\.roomName), ["room3", "room4"])
    }

    // MARK: Overflow rooms reappear when a newer call ends

    func testSortTrim_RemovingNewerEntry_ExposesPreviousOverflow() {
        // 4 entries: room0(newest) .. room3(oldest)
        let allEntries = (0..<4).map { i in
            (roomName: "room\(i)", messageDate: makeDate(daysAgo: i))
        }
        let (_, overflow) = headerView.sortAndTrim(entries: allEntries, maxVisible: 3)
        XCTAssertEqual(overflow.first?.roomName, "room3")

        // Remove room0 (newest) → room1, room2, room3 should all be visible
        let reduced = allEntries.filter { $0.roomName != "room0" }
        let (visible2, overflow2) = headerView.sortAndTrim(entries: reduced, maxVisible: 3)
        XCTAssertEqual(visible2.count, 3)
        XCTAssertTrue(overflow2.isEmpty)
        XCTAssertEqual(visible2[0].roomName, "room1")
        XCTAssertEqual(visible2[2].roomName, "room3")
    }

    // MARK: Empty-participant exclusion (handled by showCallBanner caller, not sortAndTrim)

    /// The sort/trim function itself is agnostic to participants; the caller (showCallBanner)
    /// is responsible for calling hideCallBanner when participants list is empty.
    func testSortTrim_DoesNotFilterByParticipantCount() {
        let entries = [
            (roomName: "x", messageDate: makeDate(daysAgo: 0)),
        ]
        let (visible, _) = headerView.sortAndTrim(entries: entries, maxVisible: 3)
        XCTAssertEqual(visible.count, 1,
                       "sortAndTrim is not participant-aware; callers manage empty-room exclusion.")
    }
}

// MARK: - ActiveCallBannerView.configureWith Tests

/// Minimal fake delegate to satisfy the `ActiveCallBannerDelegate` requirement.
private class SpyBannerDelegate: NSObject, ActiveCallBannerDelegate {
    var joinedLink: String?
    var openedLink: String?

    func didTapJoin(callLink: String) { joinedLink = callLink }
    func didTapOpen(callLink: String) { openedLink = callLink }
}

final class ActiveCallBannerViewTests: XCTestCase {

    private var banner: ActiveCallBannerView!
    private var delegate: SpyBannerDelegate!

    override func setUp() {
        super.setUp()
        banner = ActiveCallBannerView(frame: CGRect(x: 0, y: 0, width: 375, height: 66))
        delegate = SpyBannerDelegate()
        // Force the view to install its subviews
        banner.layoutIfNeeded()
    }

    override func tearDown() {
        banner = nil
        delegate = nil
        super.tearDown()
    }

    // MARK: Button label

    func testConfigureWith_JoinLabel_WhenNotInCall() {
        banner.configureWith(
            participants: [makeParticipant(name: "Alice")],
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: false,
            delegate: delegate
        )
        let actionButton = findActionButton(in: banner)
        XCTAssertEqual(actionButton?.title(for: .normal), "join.call".localized,
                       "Button should say 'Join' when not already in call")
    }

    func testConfigureWith_OpenLabel_WhenAlreadyInCall() {
        banner.configureWith(
            participants: [makeParticipant(name: "Alice")],
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: true,
            delegate: delegate
        )
        let actionButton = findActionButton(in: banner)
        XCTAssertEqual(actionButton?.title(for: .normal), "open.call".localized,
                       "Button should say 'Open' when already in call")
    }

    // MARK: Participant row count

    func testConfigureWith_SingleParticipant_OneBox() {
        banner.configureWith(
            participants: [makeParticipant(name: "Alice")],
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: false,
            delegate: delegate
        )
        let boxes = findParticipantBoxes(in: banner)
        XCTAssertEqual(boxes.count, 1)
    }

    func testConfigureWith_MultipleParticipants_CorrectBoxCount() {
        let participants = ["Alice", "Bob", "Carol"].map { makeParticipant(name: $0) }
        banner.configureWith(
            participants: participants,
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: false,
            delegate: delegate
        )
        let boxes = findParticipantBoxes(in: banner)
        XCTAssertEqual(boxes.count, 3)
    }

    // MARK: Empty participants list

    func testConfigureWith_EmptyParticipants_ScrollViewHidden() {
        banner.configureWith(
            participants: [],
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: false,
            delegate: delegate
        )
        let scrollView = findScrollView(in: banner)
        XCTAssertEqual(scrollView?.isHidden, true,
                       "Participants scroll view should be hidden when list is empty")
    }

    func testConfigureWith_NonEmptyParticipants_ScrollViewVisible() {
        banner.configureWith(
            participants: [makeParticipant(name: "Alice")],
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: false,
            delegate: delegate
        )
        let scrollView = findScrollView(in: banner)
        XCTAssertEqual(scrollView?.isHidden, false,
                       "Participants scroll view should be visible when list is non-empty")
    }

    // MARK: Reconfigure with different participants

    func testConfigureWith_Reconfigure_UpdatesBoxCount() {
        banner.configureWith(
            participants: ["Alice", "Bob"].map { makeParticipant(name: $0) },
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: false,
            delegate: delegate
        )
        banner.configureWith(
            participants: ["Alice", "Bob", "Carol", "Dave"].map { makeParticipant(name: $0) },
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: false,
            delegate: delegate
        )
        let boxes = findParticipantBoxes(in: banner)
        XCTAssertEqual(boxes.count, 4, "Reconfiguring should replace the participant row entirely")
    }

    // MARK: State retained on configureWith

    func testConfigureWith_RetainsCallLink() {
        let link = "https://chat.sphinx.chat/rooms/sphinx.call.test123"
        banner.configureWith(
            participants: [makeParticipant(name: "Alice")],
            callLink: link,
            isAlreadyInCall: false,
            delegate: delegate
        )
        XCTAssertEqual(banner.callLink, link)
    }

    func testConfigureWith_RetainsIsAlreadyInCall() {
        banner.configureWith(
            participants: [makeParticipant(name: "Alice")],
            callLink: "https://example.com/room/abc",
            isAlreadyInCall: true,
            delegate: delegate
        )
        XCTAssertTrue(banner.isAlreadyInCall)
    }

    // MARK: - Private view-tree helpers

    private func findActionButton(in view: UIView) -> UIButton? {
        for subview in view.subviews {
            if let btn = subview as? UIButton { return btn }
        }
        return nil
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        for subview in view.subviews {
            if let sv = subview as? UIScrollView { return sv }
        }
        return nil
    }

    private func findParticipantBoxes(in view: UIView) -> [ParticipantBoxView] {
        var result: [ParticipantBoxView] = []
        guard let scrollView = findScrollView(in: view) else { return result }
        for inner in scrollView.subviews {
            if let stack = inner as? UIStackView {
                result = stack.arrangedSubviews.compactMap { $0 as? ParticipantBoxView }
            }
        }
        return result
    }
}
