//
//  SphinxOnionManagerMqttQueueTests.swift
//  sphinxTests
//
//  MQTT callback queue-confinement: Core Data / Timer / UI work must hop to
//  main when CocoaMQTT invokes didReceiveMessage / didDisconnect / didConnectAck
//  from its CFStream/socket queue.
//

import XCTest
import CoreData
@testable import sphinx

final class SphinxOnionManagerMqttQueueTests: XCTestCase {

    private static let testSeed = "dea65b969cd1b0926889f35699586ff7e19469c64e7a944d0c6b68342158a1a8"
    private static let testXpub = "tpubDAGRb7j9yEF51RrPBjxYk6inEyxzX9oZEqRfWGGtnhEaux2xsma2eQFNBYeRgEHLC5pc4Cif4KPJXXRqS1aTErvhvTiZGaGggq9UoTZdEsH"

    override func tearDown() {
        let mgr = SphinxOnionManager.sharedInstance
        mgr.stopWatchdog()
        mgr.endReconnectionTimer()
        mgr.mqttTeardownTimeoutTimer?.invalidate()
        mgr.mqttTeardownTimeoutTimer = nil
        mgr.onProcessMqttMessages = nil
        mgr.onHandleDidConnectAck = nil
        mgr.onInitialInviteSetupFired = nil
        SphinxOnionManager.resetSharedInstance()
        super.tearDown()
    }

    private func makeFreshManager() -> SphinxOnionManager {
        SphinxOnionManager.resetSharedInstance()
        let mgr = SphinxOnionManager.sharedInstance
        mgr.isV2InitialSetup = false
        mgr.isV2Restore = false
        mgr.connectionInProgress = false
        mgr.onInitialInviteSetupFired = nil
        mgr.onProcessMqttMessages = nil
        mgr.onHandleDidConnectAck = nil
        return mgr
    }

    // MARK: - Shared hop helper

    func test_runOnMainIfNeeded_fromBackground_runsOnMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "runOnMainIfNeeded")
        var ranOnMain = false

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.runOnMainIfNeeded {
                ranOnMain = Thread.isMainThread
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(ranOnMain)
    }

    func test_runOnMainIfNeeded_alreadyOnMain_runsInline() {
        let mgr = makeFreshManager()
        var ranInline = false
        mgr.runOnMainIfNeeded {
            ranInline = Thread.isMainThread
        }
        XCTAssertTrue(ranInline)
    }

    // MARK: - processMqttMessages via hop used at subscribeAndPublishMyTopics + createMyAccount

    func test_hopProcessIncomingMqttMessage_fromBackground_runsOnMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "processMqttMessages on main")
        var ranOnMain = false
        mgr.onProcessMqttMessages = { isMain in
            ranOnMain = isMain
            exp.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.hopProcessIncomingMqttMessageForTest()
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(ranOnMain, "processMqttMessages must run on main after hop")
    }

    func test_hopHandleDidConnectAck_fromBackground_invokesHandlerOnMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "handleDidConnectAck hop")
        var ranOnMain = false
        mgr.onHandleDidConnectAck = { isMain in
            ranOnMain = isMain
            exp.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.runOnMainIfNeeded {
                mgr.onHandleDidConnectAck?(Thread.isMainThread)
            }
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(ranOnMain)
    }

    /// Assignment site 1: `subscribeAndPublishMyTopics` uses `hopProcessIncomingMqttMessage`.
    func test_subscribeAndPublishMyTopics_site_hopsReceiveToMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "subscribeAndPublishMyTopics hop")
        var ranOnMain = false
        mgr.onProcessMqttMessages = { isMain in
            ranOnMain = isMain
            exp.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.hopProcessIncomingMqttMessageForTest()
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(ranOnMain)
    }

    /// Assignment site 2: `createMyAccount` uses the same `hopProcessIncomingMqttMessage`.
    func test_createMyAccount_site_hopsReceiveToMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "createMyAccount hop")
        var ranOnMain = false
        mgr.onProcessMqttMessages = { isMain in
            ranOnMain = isMain
            exp.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.hopProcessIncomingMqttMessageForTest()
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(ranOnMain)
    }

    // MARK: - handleDidConnectAck via hop used at connectToServer

    /// Assignment site 3: `connectToServer` uses `hopHandleDidConnectAck` → `runOnMainIfNeeded`.
    func test_connectToServer_site_hopsDidConnectAckToMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "didConnectAck hop")
        var ranOnMain = false

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.runOnMainIfNeeded {
                ranOnMain = Thread.isMainThread
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(ranOnMain, "handleDidConnectAck work must run on main")
    }

    func test_createMyAccount_didConnectAck_site_runsOnMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "createMyAccount didConnectAck on main")
        var ranOnMain = false

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.runOnMainIfNeeded {
                ranOnMain = Thread.isMainThread
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(ranOnMain)
    }

    // MARK: - Owner fetch stays on viewContext

    func test_processMqttMessages_ownerFetchUsesViewContext() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "owner fetch on main/viewContext")
        var ownerContextIsViewContext = false
        var ranOnMain = false

        mgr.onProcessMqttMessages = { isMain in
            ranOnMain = isMain
            let owner = UserContact.getOwner()
            let view = CoreDataManager.sharedManager.persistentContainer.viewContext
            ownerContextIsViewContext = (owner == nil) || (owner?.managedObjectContext === view)
            XCTAssertTrue(
                view.concurrencyType == .mainQueueConcurrencyType,
                "viewContext must remain the owner-fetch context"
            )
            exp.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.hopProcessIncomingMqttMessageForTest()
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(ranOnMain)
        XCTAssertTrue(ownerContextIsViewContext, "getOwner() must use viewContext, not backgroundContext")
    }

    // MARK: - Timers hop to main run loop

    func test_startDelayedRRTimeoutTimer_fromBackground_schedulesOnMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "delayed RR timer scheduled")

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.startDelayedRRTimeoutTimer(for: 4242)
            DispatchQueue.main.async {
                XCTAssertNotNil(mgr.delayedRRTimers[4242], "Timer must be stored after main hop")
                mgr.delayedRRTimers[4242]?.invalidate()
                mgr.delayedRRTimers[4242] = nil
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
    }

    func test_setupInvoicePaymentTimerFor_fromBackground_schedulesOnMain() {
        let mgr = makeFreshManager()
        let exp = expectation(description: "invoice timer scheduled")

        DispatchQueue.global(qos: .userInitiated).async {
            mgr.setupInvoicePaymentTimerFor(invoice: "lnbc1test", tag: "tag-queue")
            DispatchQueue.main.async {
                XCTAssertNotNil(mgr.paymentTimeoutTimers["tag-queue"])
                mgr.resetInvoicePaymentTimerFor(tag: "tag-queue")
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
    }

    // MARK: - Teardown

    func test_forceTeardownMqtt_nil_is_safe() {
        let mgr = makeFreshManager()
        mgr.mqtt = nil
        mgr.forceTeardownMqtt(nil)
        XCTAssertNil(mgr.mqtt)
    }

    func test_forceTeardownMqtt_retainsClientAndNoOpsCallbacks() {
        let mgr = makeFreshManager()
        mgr.attachDetachedMqttForTest()
        let original = mgr.mqtt
        XCTAssertNotNil(original)

        mgr.forceTeardownMqtt(mgr.mqtt)

        XCTAssertTrue(mgr.mqttTeardownInProgress)
        XCTAssertNotNil(mgr.mqtt)
        XCTAssertTrue(mgr.mqtt === original)

        var trustAccepted: Bool?
        mgr.invokeMqttDidReceiveTrustForTest { trustAccepted = $0 }
        XCTAssertEqual(trustAccepted, false)

        mgr.fireAssignedMqttDidReceiveMessageForTest()
        XCTAssertNotNil(mgr.mqtt.didConnectAck)
        XCTAssertNotNil(mgr.mqtt.didReceiveMessage)
        XCTAssertNotNil(mgr.mqtt.didReceiveTrust)
        XCTAssertTrue(mgr.mqttTeardownInProgress)
        XCTAssertTrue(mgr.mqtt === original)
    }

    func test_connectToBroker_whileTeardown_doesNotReplaceMqtt() {
        let mgr = makeFreshManager()
        mgr.attachDetachedMqttForTest()
        let original = mgr.mqtt

        mgr.forceTeardownMqtt(mgr.mqtt)
        XCTAssertTrue(mgr.mqttTeardownInProgress)

        let queued = mgr.connectToBroker(seed: Self.testSeed, xpub: Self.testXpub)
        XCTAssertTrue(queued)
        XCTAssertTrue(mgr.mqtt === original)
        XCTAssertEqual(mgr.pendingBrokerConnect?.seed, Self.testSeed)
        XCTAssertEqual(mgr.pendingBrokerConnect?.xpub, Self.testXpub)
    }

    func test_simulatedDidDisconnect_fromBackground_drainsThenFlushesPendingConnect() {
        let mgr = makeFreshManager()
        mgr.attachDetachedMqttForTest()
        let original = mgr.mqtt
        mgr.forceTeardownMqtt(mgr.mqtt)
        XCTAssertTrue(mgr.connectToBroker(seed: Self.testSeed, xpub: Self.testXpub))
        XCTAssertNotNil(mgr.pendingBrokerConnect)

        let exp = expectation(description: "teardown drain + pending connect")
        DispatchQueue.global(qos: .userInitiated).async {
            mgr.fireAssignedMqttDidDisconnectForTest()
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    XCTAssertNil(mgr.mqttTeardownTimeoutTimer, "hang timer must be cancelled on didDisconnect")
                    XCTAssertFalse(mgr.mqttTeardownInProgress)
                    XCTAssertNil(mgr.pendingBrokerConnect)
                    XCTAssertNotNil(mgr.mqtt)
                    XCTAssertFalse(mgr.mqtt === original)
                    exp.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 2)
    }

    func test_hangTimeout_releasesInstanceAndFlushesPendingConnect() {
        let mgr = makeFreshManager()
        mgr.mqttTeardownTimeoutInterval = 0.05
        mgr.invokeMqttDisconnectOnTeardown = false
        mgr.attachDetachedMqttForTest()
        let original = mgr.mqtt
        mgr.forceTeardownMqtt(mgr.mqtt)
        XCTAssertTrue(mgr.connectToBroker(seed: Self.testSeed, xpub: Self.testXpub))

        let exp = expectation(description: "hang-timeout drain")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertFalse(mgr.mqttTeardownInProgress)
            XCTAssertNil(mgr.pendingBrokerConnect)
            XCTAssertNil(mgr.mqttTeardownTimeoutTimer)
            XCTAssertNotNil(mgr.mqtt)
            XCTAssertFalse(mgr.mqtt === original)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
    }

    func test_expireBackgroundFetch_firesCompletionWithoutNillingMqtt() {
        let mgr = makeFreshManager()
        mgr.attachDetachedMqttForTest()
        let original = mgr.mqtt

        var completionFired = false
        mgr.backgroundFetchInProgress = true
        mgr.backgroundFetchCompletionHandler = { _ in
            completionFired = true
        }

        mgr.expireBackgroundFetch()

        XCTAssertTrue(completionFired)
        XCTAssertTrue(mgr.mqtt === original)
        XCTAssertNotNil(mgr.mqtt)
        XCTAssertTrue(mgr.mqttTeardownInProgress)
        XCTAssertFalse(mgr.backgroundFetchInProgress)
    }
}
