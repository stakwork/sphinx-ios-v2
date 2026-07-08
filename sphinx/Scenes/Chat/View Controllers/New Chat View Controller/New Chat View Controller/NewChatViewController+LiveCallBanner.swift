//
//  NewChatViewController+LiveCallBanner.swift
//  sphinx
//
//  Live Call Banner lifecycle for NewChatViewController.
//
//  Responsibilities:
//    • `startLiveCallBannerPolling()` — fetches all recent call rooms for the chat,
//      subscribes each via the shared CallParticipantsSocketManager, and seeds initial
//      banner state.
//    • `stopLiveCallBannerPolling()` — unsubscribes ONLY banner-owned rooms that are
//      NOT also referenced by the visible-cell path (`messageIdToRoomName`).
//      ⚠️ NEVER calls `unsubscribeAllRooms()` here — that would nil the shared socket
//      manager and wipe `callParticipantsStore`/`messageIdToRoomName`, which the
//      visible-cell participant path in `NewChatTableDataSource+CellDelegateExtension`
//      still needs while cells are on screen.
//    • `shouldUpdateLiveCallBanner(roomName:participants:)` — show/hide a single banner.
//    • `refreshAllBanners()` — re-evaluate all tracked rooms from current participant store.
//
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit

// MARK: - NewChatViewController Live Call Banner Extension

extension NewChatViewController {

    // MARK: - Public Entry Points

    /// Call from `viewDidLoad` (after `configureTableView`) to wire up:
    ///  - banner stack height callback (already done in `setupLayouts`, this is a no-op if already wired)
    ///  - banner polling for public group chats
    ///  - `.videoCallStateDidChange` observation
    func installActiveCallBannerIfNeeded() {
        // Observation is a one-time setup; guard against duplicate registration.
        guard !isObservingVideoState else { return }
        isObservingVideoState = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVideoCallStateDidChange),
            name: .videoCallStateDidChange,
            object: nil
        )
        print("[LiveCallBanner] Installed banner observation")
    }

    // MARK: - Polling

    /// Starts chat-wide live-call banner polling.
    ///
    /// Guarded to public-group, non-thread chats only (banners are not shown in
    /// direct messages or thread views).
    ///
    /// Fetches `getRecentCallMessages` for the chat, subscribes each discovered
    /// room via the shared socket manager (creating it if needed — same pattern as
    /// `shouldLoadCallParticipantsFor` in the cell delegate), tracks them in
    /// `bannerRooms`/`liveCallRooms`/`liveCallRoomDates`, then seeds each banner
    /// with whatever participants are already in `callParticipantsStore`.
    func startLiveCallBannerPolling() {
        guard let chat = chat,
              chat.isPublicGroup(),
              !isThread else {
            print("[LiveCallBanner] startLiveCallBannerPolling skipped (not a public group or is thread)")
            return
        }

        let chatId = chat.id

        print("[LiveCallBanner] startLiveCallBannerPolling for chat \(chatId)")

        let recentCallMessages = TransactionMessage.getRecentCallMessages(for: chatId)

        // Extract room name + call link from each call message.
        var newBannerRooms = Set<String>()
        var newLiveCallRooms = [String: String]()
        var newLiveCallRoomDates = [String: Date]()

        for message in recentCallMessages {
            guard let content = message.messageContent, content.isNotEmpty else { continue }
            let link = VoIPRequestMessage.getFromString(content)?.link ?? content
            guard link.isLiveKitCallLink, let roomName = link.liveKitRoomName else { continue }

            newBannerRooms.insert(roomName)
            newLiveCallRooms[roomName] = link
            newLiveCallRoomDates[roomName] = message.date ?? Date()
            print("[LiveCallBanner] Discovered room '\(roomName)' from call message id \(message.id)")
        }

        bannerRooms = newBannerRooms
        liveCallRooms = newLiveCallRooms
        liveCallRoomDates = newLiveCallRoomDates

        // Subscribe each room via the shared socket manager.
        for roomName in bannerRooms {
            subscribeRoomForBanner(roomName: roomName)
        }

        // Seed banners from whatever participants are already cached.
        refreshAllBanners()
    }

    /// Stops banner polling and cleans up banner UI.
    ///
    /// ⚠️ OWNERSHIP BOUNDARY — do NOT change to `unsubscribeAllRooms()`:
    ///
    /// The banner path and the visible-cell path share one `callParticipantsSocketManager`
    /// plus the `subscribedRooms`, `callParticipantsStore`, and `messageIdToRoomName`
    /// dictionaries owned by `NewChatTableDataSource`. Calling `unsubscribeAllRooms()`
    /// would nil the manager and wipe those stores, breaking in-progress participant
    /// displays in any cell that is still visible on screen.
    ///
    /// Instead we only unsubscribe rooms that:
    ///   a) Are in `bannerRooms` (we subscribed them), AND
    ///   b) Are NOT also referenced by a visible cell in `messageIdToRoomName`.
    func stopLiveCallBannerPolling() {
        print("[LiveCallBanner] stopLiveCallBannerPolling — unsubscribing banner-only rooms")

        // Rooms that visible cells still need — must not be unsubscribed.
        let cellOwnedRooms = chatTableDataSource.map { Set($0.messageIdToRoomName.values) } ?? []

        for roomName in bannerRooms {
            if cellOwnedRooms.contains(roomName) {
                // A visible cell is still using this room — leave the subscription alive.
                print("[LiveCallBanner] Skipping unsubscribe for '\(roomName)' — still used by a cell")
            } else {
                chatTableDataSource?.callParticipantsSocketManager?.unsubscribe(roomName: roomName)
                chatTableDataSource?.subscribedRooms.remove(roomName)
                print("[LiveCallBanner] Unsubscribed banner-only room '\(roomName)'")
            }
        }

        bannerRooms.removeAll()
        liveCallRooms.removeAll()
        liveCallRoomDates.removeAll()

        headerView.hideAllCallBanners()
        print("[LiveCallBanner] All banners hidden and state cleared")
    }

    // MARK: - Per-Room Banner Update

    /// Updates (or hides) the banner for a specific room.
    ///
    /// Hides the banner when `participants` is empty (room empty or finished).
    /// Computes `isAlreadyInCall` by comparing `roomName` against
    /// `VideoCallManager.sharedInstance.currentRoomName`.
    func shouldUpdateLiveCallBanner(roomName: String, participants: [BubbleMessageLayoutState.CallParticipantInfo]) {
        guard let callLink = liveCallRooms[roomName],
              let messageDate = liveCallRoomDates[roomName] else {
            // Room not tracked by the banner — nothing to do.
            return
        }

        let isAlreadyInCall = VideoCallManager.sharedInstance.currentRoomName == roomName

        if participants.isEmpty {
            print("[LiveCallBanner] hideCallBanner for room '\(roomName)' — no participants")
            headerView.hideCallBanner(roomName: roomName)
        } else {
            print("[LiveCallBanner] showCallBanner for room '\(roomName)' — \(participants.count) participant(s), isAlreadyInCall=\(isAlreadyInCall)")
            headerView.showCallBanner(
                roomName: roomName,
                participants: participants,
                callLink: callLink,
                messageDate: messageDate,
                isAlreadyInCall: isAlreadyInCall,
                delegate: self
            )
        }
    }

    /// Re-evaluates all tracked banner rooms using the current `callParticipantsStore`.
    ///
    /// Called on initial polling start, on `.videoCallStateDidChange`, and when any
    /// socket event fires for a banner room.
    func refreshAllBanners() {
        guard let store = chatTableDataSource?.callParticipantsStore else {
            // Data source not yet set up — hide everything and bail.
            headerView.hideAllCallBanners()
            return
        }
        print("[LiveCallBanner] refreshAllBanners — \(liveCallRooms.count) tracked room(s)")
        for roomName in liveCallRooms.keys {
            let participants = store[roomName] ?? []
            shouldUpdateLiveCallBanner(roomName: roomName, participants: participants)
        }
    }

    // MARK: - Restart on New Call Message

    /// Called by the data-source delegate when a new call-type message is inserted into
    /// the results controller while the chat is already open.  Restarts banner polling so
    /// the new room gets subscribed and its banner appears.
    func didReceiveNewCallMessage() {
        print("[LiveCallBanner] didReceiveNewCallMessage — restarting banner polling")
        stopLiveCallBannerPolling()
        startLiveCallBannerPolling()
    }

    // MARK: - Notification Handler

    /// Fired by `VideoCallManager` whenever `currentRoomName` changes.
    /// Re-evaluates all banners so Join↔Open flips immediately.
    @objc func handleVideoCallStateDidChange() {
        print("[LiveCallBanner] .videoCallStateDidChange received — currentRoomName=\(VideoCallManager.sharedInstance.currentRoomName ?? "nil")")
        refreshAllBanners()
    }

    // MARK: - Private Helpers

    /// Subscribes a room via the shared socket manager, creating it if needed.
    /// Mirrors the pattern in `shouldLoadCallParticipantsFor` so both paths share one manager.
    private func subscribeRoomForBanner(roomName: String) {
        guard let dataSource = chatTableDataSource else { return }

        if dataSource.callParticipantsSocketManager == nil {
            dataSource.callParticipantsSocketManager = CallParticipantsSocketManager()
            dataSource.callParticipantsSocketManager?.delegate = dataSource
            print("[LiveCallBanner] Created shared CallParticipantsSocketManager")
        }

        if !dataSource.subscribedRooms.contains(roomName) {
            dataSource.subscribedRooms.insert(roomName)
            dataSource.callParticipantsSocketManager?.subscribe(roomName: roomName)
            print("[LiveCallBanner] Subscribed to room '\(roomName)'")
        } else {
            print("[LiveCallBanner] Room '\(roomName)' already subscribed — requesting fresh participant list")
            dataSource.callParticipantsSocketManager?.sendSubscribeTo(roomName: roomName)
        }
    }
}

// MARK: - ActiveCallBannerDelegate

extension NewChatViewController: ActiveCallBannerDelegate {

    /// User tapped "Join" on a banner.
    ///
    /// `VideoCallManager.startVideoCall` already handles the teardown-then-start
    /// logic added in T1: if the user is already in a *different* call it tears that
    /// down first; if they are in the *same* room it returns to it.
    func didTapJoin(callLink: String) {
        print("[LiveCallBanner] didTapJoin — link: \(callLink)")
        VideoCallManager.sharedInstance.startVideoCall(link: callLink, audioOnly: false, isHost: false)
    }

    /// User tapped "Open" on a banner — they are already in this call.
    ///
    /// Brings the active call forward by exiting Picture-in-Picture.
    func didTapOpen(callLink: String) {
        print("[LiveCallBanner] didTapOpen — bringing active call forward via PiP exit")
        VideoCallManager.sharedInstance.togglePip(pipEnabled: false)
    }
}
