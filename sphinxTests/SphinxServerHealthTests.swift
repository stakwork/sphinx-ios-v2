//
//  SphinxServerHealthTests.swift
//  sphinxTests
//
//  Server-health intercept, store, staleness, banner visibility, and mixer error copy.
//

import XCTest
@testable import sphinx

final class ServerHealthTests: XCTestCase {

    override func tearDown() {
        let mgr = SphinxOnionManager.sharedInstance
        mgr.stopWatchdog()
        mgr.stopServerHealthTracking()
        mgr.endReconnectionTimer()
        mgr.onProcessMqttMessages = nil
        mgr.onOnionHandleInvoked = nil
        mgr.onServerStatusIntercepted = nil
        mgr.nowMsProvider = nil
        SphinxOnionManager.resetSharedInstance()
        super.tearDown()
    }

    private func makeFreshManager() -> SphinxOnionManager {
        SphinxOnionManager.resetSharedInstance()
        let mgr = SphinxOnionManager.sharedInstance
        mgr.isV2InitialSetup = false
        mgr.isV2Restore = false
        mgr.connectionInProgress = false
        mgr.onOnionHandleInvoked = nil
        mgr.onServerStatusIntercepted = nil
        mgr.nowMsProvider = nil
        return mgr
    }

    private func healthyPayload(ts: UInt64) -> String {
        "{\"cln_ok\":true,\"degraded\":false,\"reason\":null,\"ts\":\(ts)}"
    }

    private func degradedPayload(ts: UInt64) -> String {
        "{\"cln_ok\":false,\"degraded\":true,\"reason\":\"cln down\",\"ts\":\(ts)}"
    }

    // MARK: - Intercept

    func test_statusTopic_isInterceptedBeforeHandle() {
        let mgr = makeFreshManager()
        var intercepted: String?
        var handleTopic: String?
        mgr.onServerStatusIntercepted = { intercepted = $0 }
        mgr.onOnionHandleInvoked = { handleTopic = $0 }

        mgr.processMqttMessageForTest(
            topic: serverStatusTopic(),
            payload: healthyPayload(ts: 1_700_000_000_000)
        )

        XCTAssertEqual(intercepted, serverStatusTopic())
        XCTAssertNil(handleTopic, "onion handle() must not run for the exact status topic")
    }

    func test_substringTopic_isNotIntercepted() {
        let mgr = makeFreshManager()
        var intercepted: String?
        mgr.onServerStatusIntercepted = { intercepted = $0 }

        mgr.processMqttMessageForTest(
            topic: "prefix/\(serverStatusTopic())/suffix",
            payload: healthyPayload(ts: 1_700_000_000_000)
        )

        XCTAssertNil(intercepted, "substring topics must not match")
        XCTAssertFalse("prefix/server_status/suffix" == serverStatusTopic())
        XCTAssertTrue("server_status" == serverStatusTopic())
    }

    // MARK: - Store start / recovery / staleness

    func test_healthStoreStartsUnknown() {
        let mgr = makeFreshManager()
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertNil(mgr.lastServerStatus)
        XCTAssertNil(mgr.serverHealthTrackingStartedAtMs)
        XCTAssertFalse(mgr.hasReceivedServerStatus)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)
    }

    func test_unknownStaysHiddenWhenTrackingHasNotStartedEvenWithLargeNow() {
        let mgr = makeFreshManager()
        mgr.nowMsProvider = { UInt64.max }
        XCTAssertNil(mgr.serverHealthTrackingStartedAtMs)
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)
    }

    func test_unknownStaysHiddenDuringLaunchGrace() {
        let mgr = makeFreshManager()
        let started: UInt64 = 1_700_000_000_000
        mgr.nowMsProvider = { started }
        mgr.startServerHealthTracking()
        XCTAssertEqual(mgr.serverHealthTrackingStartedAtMs, started)

        mgr.nowMsProvider = { started + 1_000 }
        XCTAssertEqual(mgr.serverHealthTrackingStartedAtMs, started)
        XCTAssertFalse(mgr.hasReceivedServerStatus)
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)
    }

    func test_unknownShowsAfterLaunchGraceAndElapsedPostsNotification() {
        let mgr = makeFreshManager()
        let started: UInt64 = 1_700_000_000_000
        mgr.nowMsProvider = { started }
        mgr.startServerHealthTracking()

        mgr.nowMsProvider = { started + ServerHealthPresentation.launchGraceMs }
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertFalse(mgr.hasReceivedServerStatus)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)

        let exp = expectation(forNotification: .onServerHealthChanged, object: nil)
        mgr.handleServerHealthLaunchGraceElapsed()
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertNil(mgr.serverHealthLaunchGraceTimer)
    }

    func test_degradedShowsImmediatelyInsideLaunchGrace() {
        let mgr = makeFreshManager()
        let started: UInt64 = 1_700_000_000_000
        mgr.nowMsProvider = { started }
        mgr.startServerHealthTracking()

        let now = started + 1_000
        mgr.nowMsProvider = { now }
        mgr.ingestServerStatusPayloadString(degradedPayload(ts: now), nowMs: now)

        XCTAssertEqual(mgr.currentServerHealth, .degraded)
        XCTAssertTrue(mgr.hasReceivedServerStatus)
        XCTAssertNil(mgr.serverHealthLaunchGraceTimer)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    func test_unknownAfterHealthyShowsImmediatelyInsideLaunchGrace() {
        let mgr = makeFreshManager()
        let started: UInt64 = 1_700_000_120_000
        let healthySeen = started - 120_000
        mgr.nowMsProvider = { healthySeen }
        mgr.ingestServerStatusPayloadString(healthyPayload(ts: healthySeen), nowMs: healthySeen)
        XCTAssertEqual(mgr.currentServerHealth, .ok)
        XCTAssertTrue(mgr.hasReceivedServerStatus)

        mgr.nowMsProvider = { started }
        mgr.startServerHealthTracking()
        XCTAssertEqual(mgr.serverHealthTrackingStartedAtMs, started)

        mgr.nowMsProvider = { started + 1_000 }
        mgr.reevaluateServerHealthStaleness()
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertTrue(mgr.hasReceivedServerStatus)
        XCTAssertEqual(mgr.serverHealthTrackingStartedAtMs, started)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    func test_resetClearsGraceAndNextWindowStartsHidden() {
        let mgr = makeFreshManager()
        let seen: UInt64 = 1_700_000_000_000
        mgr.nowMsProvider = { seen }
        mgr.ingestServerStatusPayloadString(degradedPayload(ts: seen), nowMs: seen)
        XCTAssertTrue(mgr.hasReceivedServerStatus)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)

        mgr.resetServerHealthStore()
        XCTAssertFalse(mgr.hasReceivedServerStatus)
        XCTAssertNil(mgr.serverHealthTrackingStartedAtMs)
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)

        let restarted: UInt64 = seen + 30_000
        mgr.nowMsProvider = { restarted }
        mgr.startServerHealthTracking()
        mgr.nowMsProvider = { restarted + 1_000 }
        XCTAssertEqual(mgr.serverHealthTrackingStartedAtMs, restarted)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)
    }

    func test_restartingTrackingDoesNotResetLaunchGraceStart() {
        let mgr = makeFreshManager()
        let started: UInt64 = 1_700_000_000_000
        mgr.nowMsProvider = { started }
        mgr.startServerHealthTracking()
        XCTAssertEqual(mgr.serverHealthTrackingStartedAtMs, started)

        mgr.nowMsProvider = { started + 5_000 }
        mgr.startServerHealthTracking()
        XCTAssertEqual(mgr.serverHealthTrackingStartedAtMs, started)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)
    }

    func test_parseFailureInsideLaunchGraceShowsUnknownImmediately() {
        let mgr = makeFreshManager()
        let started: UInt64 = 1_700_000_000_000
        mgr.nowMsProvider = { started }
        mgr.startServerHealthTracking()

        mgr.nowMsProvider = { started + 1_000 }
        mgr.ingestServerStatusPayloadString("not-json", nowMs: started + 1_000)

        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertTrue(mgr.hasReceivedServerStatus)
        XCTAssertNil(mgr.serverHealthLaunchGraceTimer)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    func test_invalidPayloadMapsToUnknownWithoutCallingHandle() {
        let mgr = makeFreshManager()
        var handleTopic: String?
        mgr.onOnionHandleInvoked = { handleTopic = $0 }

        mgr.processMqttMessageForTest(topic: serverStatusTopic(), payload: "not-json")

        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertNil(handleTopic)
    }

    func test_healthyHeartbeatAfterDegradedRestoresOkAndHidesBanner() {
        let mgr = makeFreshManager()
        let now: UInt64 = 1_700_000_090_000
        mgr.nowMsProvider = { now }

        mgr.ingestServerStatusPayloadString(degradedPayload(ts: now), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, .degraded)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: now), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, .ok)
        XCTAssertFalse(mgr.isServerHealthBannerVisible)
    }

    func test_stalenessTransitionsToUnknownWhileMqttRemainsUp() {
        let mgr = makeFreshManager()
        let interval = ServerHealthPresentation.heartbeatIntervalMs
        let n = UInt64(ServerHealthPresentation.maxMissedIntervals)
        let seen: UInt64 = 1_700_000_000_000
        mgr.isConnected = true
        mgr.nowMsProvider = { seen }

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: seen), nowMs: seen)
        XCTAssertEqual(mgr.currentServerHealth, .ok)
        XCTAssertTrue(mgr.isConnected)

        mgr.nowMsProvider = { seen + interval * (n - 1) }
        mgr.reevaluateServerHealthStaleness()
        XCTAssertEqual(mgr.currentServerHealth, .ok, "N-1 missed intervals still trusts last sample")
        XCTAssertTrue(mgr.isConnected)

        mgr.nowMsProvider = { seen + interval * n + 1 }
        mgr.reevaluateServerHealthStaleness()
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertTrue(mgr.isConnected, "MQTT liveness is independent of health Unknown")
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    func test_staleRetainedTsDoesNotFlashOk() {
        let mgr = makeFreshManager()
        let now: UInt64 = 1_700_000_090_000
        let staleTs = now - (ServerHealthPresentation.heartbeatIntervalMs * 10)
        mgr.nowMsProvider = { now }

        mgr.ingestServerStatusPayloadString(healthyPayload(ts: staleTs), nowMs: now)
        XCTAssertEqual(mgr.currentServerHealth, .unknown)
        XCTAssertTrue(mgr.isServerHealthBannerVisible)
    }

    // MARK: - Error mapping

    func test_mappedErrorCopyForKnownAndUnknownCodes() {
        XCTAssertEqual(
            parseMixerErrorCode(raw: "CLN_UNAVAILABLE"),
            .clnUnavailable
        )
        XCTAssertEqual(
            parseMixerErrorCode(raw: "{\"code\":\"CLN_TIMEOUT\"}"),
            .clnTimeout
        )
        XCTAssertEqual(
            parseMixerErrorCode(raw: "INSUFFICIENT_BALANCE"),
            .insufficientBalance
        )
        XCTAssertEqual(
            parseMixerErrorCode(raw: "not-a-code"),
            .unknown
        )

        XCTAssertEqual(
            ServerHealthPresentation.userFacingMessage(for: .clnUnavailable),
            "mixer.error.cln-unavailable".localized
        )
        XCTAssertEqual(
            ServerHealthPresentation.userFacingMessage(for: .clnTimeout),
            "mixer.error.cln-timeout".localized
        )
        XCTAssertEqual(
            ServerHealthPresentation.userFacingMessage(for: .insufficientBalance),
            "mixer.error.insufficient-balance".localized
        )
        XCTAssertEqual(
            ServerHealthPresentation.userFacingMessage(forCode: nil),
            "generic.error.message".localized
        )
        XCTAssertEqual(
            ServerHealthPresentation.userFacingMessage(forCode: "UNKNOWN"),
            "mixer.error.unknown".localized
        )
        XCTAssertEqual(
            ServerHealthPresentation.userFacingMessage(forRawError: "Account seed not found"),
            "Account seed not found"
        )
    }

    func test_sentStatusMapsOptionalCode() {
        let json = "{\"tag\":\"abc\",\"status\":\"FAILED\",\"code\":\"CLN_UNAVAILABLE\"}"
        let sent = SentStatus(JSONString: json)
        XCTAssertEqual(sent?.code, "CLN_UNAVAILABLE")
        XCTAssertEqual(
            ServerHealthPresentation.userFacingMessage(forCode: sent?.code),
            "mixer.error.cln-unavailable".localized
        )
    }

    func test_bannerCopyNeverUsesPayloadReason() {
        XCTAssertEqual(
            ServerHealthPresentation.bannerCopy(for: .degraded),
            "server.health.degraded".localized
        )
        XCTAssertEqual(
            ServerHealthPresentation.bannerCopy(for: .unknown),
            "server.health.unknown".localized
        )
        XCTAssertNil(ServerHealthPresentation.bannerCopy(for: .ok))
        XCTAssertFalse(
            ServerHealthPresentation.bannerCopy(for: .degraded)?.contains("cln down") == true
        )
    }
}
