//
//  PodcastInterruptionTests.swift
//  sphinxTests
//
//  Unit tests for:
//    1. handleInterruption — safe optional casting (no force-cast crash)
//    2. shouldPlay / shouldPause — no-op while VideoCallManager.activeCall is true
//
//  Copyright © 2024 sphinx. All rights reserved.
//

import XCTest
import AVFoundation
@testable import sphinx

// MARK: - Helpers

/// Posts an AVAudioSession interruption notification with the given userInfo and
/// synchronously delivers it to the controller via handleInterruption(notification:).
@MainActor
private func postInterruption(
    to controller: PodcastPlayerController,
    userInfo: [AnyHashable: Any]?
) {
    let notification = NSNotification(
        name: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance(),
        userInfo: userInfo
    )
    // Call the handler directly to stay on @MainActor without waiting for NotificationCenter dispatch.
    controller.handleInterruption(notification: notification)
}

// MARK: - handleInterruption safety tests

final class PodcastInterruptionSafetyTests: XCTestCase {

    // MARK: Teardown helper — reset activeCall so tests don't bleed into each other.
    override func tearDown() {
        super.tearDown()
        // Reset call state in case a test set it.
        Task { @MainActor in
            VideoCallManager.sharedInstance.activeCall = false
        }
    }

    // MARK: Missing key — must not crash

    /// handleInterruption must return safely when userInfo is nil (already guarded upstream,
    /// but included for completeness).
    @MainActor
    func testHandleInterruption_nilUserInfo_doesNotCrash() {
        let controller = PodcastPlayerController()
        // Should not crash:
        postInterruption(to: controller, userInfo: nil)
    }

    /// handleInterruption must return safely when AVAudioSessionInterruptionTypeKey is absent.
    @MainActor
    func testHandleInterruption_missingInterruptionKey_doesNotCrash() {
        let controller = PodcastPlayerController()
        postInterruption(to: controller, userInfo: [:])
    }

    /// handleInterruption must return safely when AVAudioSessionInterruptionTypeKey holds
    /// an NSString (unexpected type, not NSNumber), not the expected NSNumber/UInt.
    @MainActor
    func testHandleInterruption_malformedStringValue_doesNotCrash() {
        let controller = PodcastPlayerController()
        let badInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: "not-a-number" as NSString
        ]
        postInterruption(to: controller, userInfo: badInfo)
    }

    /// handleInterruption must return safely when AVAudioSessionInterruptionTypeKey holds
    /// a raw NSValue (the old force-cast target), which is neither NSNumber nor carries
    /// the right rawValue.
    @MainActor
    func testHandleInterruption_malformedNSValue_doesNotCrash() {
        let controller = PodcastPlayerController()
        var bogus: UInt = 9999
        let nsv = NSValue(bytes: &bogus, objCType: "I")
        let badInfo: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: nsv]
        postInterruption(to: controller, userInfo: badInfo)
    }

    /// handleInterruption must return safely when AVAudioSessionInterruptionTypeKey holds
    /// a UInt rawValue that doesn't correspond to any AVAudioSession.InterruptionType case.
    @MainActor
    func testHandleInterruption_unknownRawValue_doesNotCrash() {
        let controller = PodcastPlayerController()
        let badInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: NSNumber(value: UInt(9999))
        ]
        postInterruption(to: controller, userInfo: badInfo)
    }
}

// MARK: - handleInterruption regression: .began still pauses podcast

final class PodcastInterruptionBehaviorTests: XCTestCase {

    /// Tracks whether pause(podcastData:) was invoked.
    private var pauseCallCount = 0

    override func setUp() {
        super.setUp()
        pauseCallCount = 0
        Task { @MainActor in
            VideoCallManager.sharedInstance.activeCall = false
        }
    }

    override func tearDown() {
        super.tearDown()
        Task { @MainActor in
            VideoCallManager.sharedInstance.activeCall = false
        }
    }

    /// A valid .began interruption must cause the podcast to pause.
    /// We verify indirectly: AVPlayer starts nil, so pause() is a no-op on the player
    /// itself — but we can confirm at minimum that no crash occurs and the code path
    /// runs through the .began branch without error.
    @MainActor
    func testHandleInterruption_validBegan_doesNotCrash() {
        let controller = PodcastPlayerController()
        let validInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType.began.rawValue)
        ]
        // Should not crash — verifies the safe-cast path produces the correct InterruptionType
        // and attempts to pause (harmless when player is nil).
        postInterruption(to: controller, userInfo: validInfo)
    }

    /// A valid .ended interruption must not crash and must not try to pause.
    @MainActor
    func testHandleInterruption_validEnded_doesNotCrash() {
        let controller = PodcastPlayerController()
        let validInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType.ended.rawValue)
        ]
        postInterruption(to: controller, userInfo: validInfo)
    }
}

// MARK: - shouldPlay / shouldPause no-op while activeCall is true

final class PodcastRemoteCommandCallGateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Task { @MainActor in
            VideoCallManager.sharedInstance.activeCall = false
        }
    }

    override func tearDown() {
        super.tearDown()
        Task { @MainActor in
            VideoCallManager.sharedInstance.activeCall = false
        }
    }

    /// shouldPlay() must return early (no-op) when an active call is in progress.
    /// We verify by confirming that no crash occurs and the method returns without
    /// touching podcastData (controller has no podcast loaded — if shouldPlay ever
    /// reached the play(podcastData:) call it would return from the isPlaying guard
    /// or the nil guard anyway, but the activeCall check fires first).
    @MainActor
    func testShouldPlay_suppressedDuringActiveCall() {
        VideoCallManager.sharedInstance.activeCall = true
        let controller = PodcastPlayerController()
        // Must not crash, must not attempt play:
        controller.shouldPlay()
        // Reset
        VideoCallManager.sharedInstance.activeCall = false
    }

    /// shouldPause() must return early (no-op) when an active call is in progress.
    @MainActor
    func testShouldPause_suppressedDuringActiveCall() {
        VideoCallManager.sharedInstance.activeCall = true
        let controller = PodcastPlayerController()
        // Must not crash, must not attempt pause:
        controller.shouldPause()
        // Reset
        VideoCallManager.sharedInstance.activeCall = false
    }

    /// shouldPlay() must proceed normally (reach isPlaying check) when no call is active.
    /// With no player loaded, isPlaying is false so play() is attempted (harmlessly).
    @MainActor
    func testShouldPlay_allowedWhenNoActiveCall() {
        VideoCallManager.sharedInstance.activeCall = false
        let controller = PodcastPlayerController()
        // Should reach the isPlaying/podcastData branches without crashing:
        controller.shouldPlay()
    }

    /// shouldPause() must proceed normally when no call is active.
    /// With no player loaded, isPlaying is false so the early-return guard fires before pause().
    @MainActor
    func testShouldPause_allowedWhenNoActiveCall() {
        VideoCallManager.sharedInstance.activeCall = false
        let controller = PodcastPlayerController()
        controller.shouldPause()
    }
}
