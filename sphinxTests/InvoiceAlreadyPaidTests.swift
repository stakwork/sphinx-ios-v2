//
//  InvoiceAlreadyPaidTests.swift
//  sphinxTests
//
//  Unit tests for local already-paid invoice detection, in-flight guards,
//  network already-paid matching, and handleRunReturn side-effect skipping.
//

import XCTest
import CoreData
@testable import sphinx

final class InvoiceAlreadyPaidTests: XCTestCase {

    private var manager: SphinxOnionManager {
        SphinxOnionManager.sharedInstance
    }
    
    private var originalBalance: UInt64?

    override func setUp() {
        super.setUp()
        originalBalance = manager.walletBalanceService.balance
        resetManagerPayState()
    }

    override func tearDown() {
        resetManagerPayState()
        manager.walletBalanceService.balance = originalBalance
        super.tearDown()
    }

    private func resetManagerPayState() {
        manager.inFlightPaymentHashes.removeAll()
        manager.paidPaymentHashes.removeAll()
        manager.invoiceDetailsOverride = nil
        manager.checkAndFetchRouteOverride = nil
        SphinxOnionManager.confirmedAlreadyPaidErrorSignals = []
    }

    // MARK: - Helpers

    private func makeInvoiceDetails(
        paymentHash: String,
        pubkey: String = "02abc",
        value: Int? = 1000,
        hopHints: [String]? = ["hint"]
    ) -> ParseInvoiceResult {
        ParseInvoiceResult(
            value: value,
            paymentHash: paymentHash,
            pubkey: pubkey,
            hopHints: hopHints
        )
    }

    private func makeRunReturn(
        error: String? = nil,
        newBalance: UInt64? = nil,
        msgs: [Msg] = [],
        sentStatus: String? = nil
    ) -> RunReturn {
        RunReturn(
            msgs: msgs,
            msgsTotal: nil,
            msgsCounts: nil,
            subscriptionTopics: [],
            settleTopic: nil,
            settlePayload: nil,
            asyncpayTopic: nil,
            asyncpayPayload: nil,
            registerTopic: nil,
            registerPayload: nil,
            topics: [],
            payloads: [],
            stateMp: nil,
            stateToDelete: [],
            newBalance: newBalance,
            myContactInfo: nil,
            sentStatus: sentStatus,
            settledStatus: nil,
            registerResponse: nil,
            asyncpayTag: nil,
            error: error,
            newTribe: nil,
            tribeMembers: nil,
            newInvite: nil,
            inviterContactInfo: nil,
            inviterAlias: nil,
            initialTribe: nil,
            lspHost: nil,
            invoice: nil,
            route: nil,
            node: nil,
            lastRead: nil,
            muteLevels: nil,
            payments: nil,
            paymentsTotal: nil,
            tags: nil,
            deletedMsgs: nil,
            newChildIdx: nil,
            ping: nil
        )
    }

    private func makeInMemoryContainer() throws -> NSPersistentContainer {
        let bundles = [Bundle(for: InvoiceAlreadyPaidTests.self)] + Bundle.allBundles + Bundle.allFrameworks
        let model = bundles.compactMap {
            $0.url(forResource: "sphinx", withExtension: "momd")
                .flatMap { NSManagedObjectModel(contentsOf: $0) }
        }.first
        guard let model = model else {
            throw XCTSkip("CoreData model 'sphinx' not found in test bundle")
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

    private func insertMessage(
        into context: NSManagedObjectContext,
        paymentHash: String,
        type: TransactionMessage.TransactionMessageType,
        status: TransactionMessage.TransactionMessageStatus,
        id: Int
    ) throws {
        let message = NSEntityDescription.insertNewObject(
            forEntityName: "TransactionMessage",
            into: context
        ) as! TransactionMessage
        message.id = id
        message.createdAt = Date()
        message.updatedAt = Date()
        message.date = Date()
        message.receiverId = 0
        message.senderId = 1
        message.type = type.rawValue
        message.status = status.rawValue
        message.paymentHash = paymentHash
        message.seen = true
        message.encrypted = false
        message.push = false
        message.mediaFileSize = 0
        try context.save()
    }

    // MARK: - isInvoiceAlreadyPaidError

    func testIsInvoiceAlreadyPaidError_emptySignals_returnsFalse() {
        SphinxOnionManager.confirmedAlreadyPaidErrorSignals = []
        XCTAssertFalse(manager.isInvoiceAlreadyPaidError("invoice already paid"))
        XCTAssertFalse(manager.isInvoiceAlreadyPaidError("invoice settled"))
        XCTAssertFalse(manager.isInvoiceAlreadyPaidError(nil as String?))
        XCTAssertFalse(manager.isInvoiceAlreadyPaidError(""))
    }

    func testIsInvoiceAlreadyPaidError_matchesOnlyConfirmedSignal() {
        let signal = "confirmed.mixer.already.paid"
        SphinxOnionManager.confirmedAlreadyPaidErrorSignals = [signal]
        XCTAssertTrue(manager.isInvoiceAlreadyPaidError(signal))
        XCTAssertFalse(manager.isInvoiceAlreadyPaidError("invoice settled"))
        XCTAssertFalse(manager.isInvoiceAlreadyPaidError("no route"))
    }

    func testIsInvoiceAlreadyPaidError_matchesSendFailedAssociatedValueNotDebugDescription() {
        let signal = "confirmed.mixer.already.paid"
        SphinxOnionManager.confirmedAlreadyPaidErrorSignals = [signal]
        let sendFailed = SphinxError.SendFailed(r: signal)
        XCTAssertTrue(manager.isInvoiceAlreadyPaidError(sendFailed))

        let unrelated = SphinxError.SendFailed(r: "timeout")
        XCTAssertFalse(manager.isInvoiceAlreadyPaidError(unrelated))

        let otherCase = SphinxError.BadArgs(r: signal)
        XCTAssertFalse(manager.isInvoiceAlreadyPaidError(otherCase))
    }

    // MARK: - hasSettledPayment

    func testHasSettledPayment_trueForConfirmedRegardlessOfType() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.viewContext
        let hash = "settled-hash-confirmed"

        try insertMessage(
            into: ctx,
            paymentHash: hash,
            type: .invoice,
            status: .confirmed,
            id: 1
        )
        XCTAssertTrue(TransactionMessage.hasSettledPayment(forPaymentHash: hash, context: ctx))

        try insertMessage(
            into: ctx,
            paymentHash: "payment-type-hash",
            type: .payment,
            status: .received,
            id: 2
        )
        XCTAssertTrue(
            TransactionMessage.hasSettledPayment(forPaymentHash: "payment-type-hash", context: ctx)
        )
    }

    func testHasSettledPayment_falseForFailedAndPending() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.viewContext
        let hash = "retryable-hash"

        try insertMessage(
            into: ctx,
            paymentHash: hash,
            type: .payment,
            status: .failed,
            id: 10
        )
        XCTAssertFalse(TransactionMessage.hasSettledPayment(forPaymentHash: hash, context: ctx))

        try insertMessage(
            into: ctx,
            paymentHash: "pending-hash",
            type: .invoice,
            status: .pending,
            id: 11
        )
        XCTAssertFalse(
            TransactionMessage.hasSettledPayment(forPaymentHash: "pending-hash", context: ctx)
        )
    }

    func testHasSettledPayment_emptyHash_returnsFalse() {
        XCTAssertFalse(TransactionMessage.hasSettledPayment(forPaymentHash: ""))
    }

    // MARK: - Local payInvoice short-circuit

    func testPayInvoice_settledHash_doesNotCallRouteOrFFI() {
        let hash = "already-paid-hash"
        manager.paidPaymentHashes.insert(hash)
        manager.invoiceDetailsOverride = { _ in
            self.makeInvoiceDetails(paymentHash: hash)
        }

        var routeCalled = false
        manager.checkAndFetchRouteOverride = { _, _, _, _ in
            routeCalled = true
        }

        let expectation = expectation(description: "already-paid callback")
        var callbackSuccess: Bool?
        var callbackMessage: String?

        manager.payInvoice(invoice: "lnbc1already") { success, errorMsg in
            callbackSuccess = success
            callbackMessage = errorMsg
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callbackSuccess, false)
        XCTAssertEqual(callbackMessage, SphinxOnionManager.invoiceAlreadyPaidLocalized)
        XCTAssertFalse(routeCalled, "Must not fetch a route for an already-paid invoice")
        XCTAssertFalse(manager.inFlightPaymentHashes.contains(hash))
    }

    func testPayInvoice_inFlightHash_blocksSecondSubmit() {
        let hash = "in-flight-hash"
        manager.invoiceDetailsOverride = { _ in
            self.makeInvoiceDetails(paymentHash: hash)
        }

        var routeCallCount = 0
        manager.checkAndFetchRouteOverride = { _, _, _, callback in
            routeCallCount += 1
            // Leave the first attempt in-flight; do not complete.
            _ = callback
        }

        manager.payInvoice(invoice: "lnbc1first") { _, _ in
            XCTFail("First payInvoice should not complete while route is outstanding")
        }

        XCTAssertTrue(manager.inFlightPaymentHashes.contains(hash))
        XCTAssertEqual(routeCallCount, 1)

        let second = expectation(description: "second submit already paid")
        var secondSuccess: Bool?
        var secondMessage: String?

        manager.payInvoice(invoice: "lnbc1second") { success, errorMsg in
            secondSuccess = success
            secondMessage = errorMsg
            second.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(routeCallCount, 1, "Second submit must not reach FFI/route")
        XCTAssertEqual(secondSuccess, false)
        XCTAssertEqual(secondMessage, SphinxOnionManager.invoiceAlreadyPaidLocalized)
    }

    func testPayInvoice_zeroAmountStillShortCircuitsOnSettledHash() {
        let hash = "zero-amount-paid"
        manager.paidPaymentHashes.insert(hash)
        manager.invoiceDetailsOverride = { _ in
            self.makeInvoiceDetails(paymentHash: hash, value: nil)
        }

        var routeCalled = false
        manager.checkAndFetchRouteOverride = { _, _, _, _ in
            routeCalled = true
        }

        let expectation = expectation(description: "zero amount already paid")
        var callbackSuccess: Bool?

        manager.payInvoice(invoice: "lnbc1zero") { success, _ in
            callbackSuccess = success
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callbackSuccess, false)
        XCTAssertFalse(routeCalled)
    }

    func testPayInvoiceMessage_settledHash_doesNotCallRouteAndReportsAlreadyPaid() throws {
        let container = try makeInMemoryContainer()
        let ctx = container.viewContext
        let hash = "chat-paid-hash"

        let message = NSEntityDescription.insertNewObject(
            forEntityName: "TransactionMessage",
            into: ctx
        ) as! TransactionMessage
        message.id = 42
        message.createdAt = Date()
        message.updatedAt = Date()
        message.date = Date()
        message.receiverId = 0
        message.senderId = 1
        message.type = TransactionMessage.TransactionMessageType.invoice.rawValue
        message.status = TransactionMessage.TransactionMessageStatus.pending.rawValue
        message.invoice = "lnbc1chat"
        message.paymentHash = hash
        message.seen = true
        message.encrypted = false
        message.push = false
        message.mediaFileSize = 0

        manager.paidPaymentHashes.insert(hash)
        manager.invoiceDetailsOverride = { _ in
            self.makeInvoiceDetails(paymentHash: hash)
        }

        var routeCalled = false
        manager.checkAndFetchRouteOverride = { _, _, _, _ in
            routeCalled = true
        }

        let expectation = expectation(description: "chat already paid")
        var callbackSuccess: Bool?
        var callbackMessage: String?

        manager.payInvoiceMessage(message: message) { success, errorMsg in
            callbackSuccess = success
            callbackMessage = errorMsg
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callbackSuccess, false)
        XCTAssertEqual(callbackMessage, SphinxOnionManager.invoiceAlreadyPaidLocalized)
        XCTAssertFalse(routeCalled)
    }

    func testPayInvoice_failedPendingHash_isNotShortCircuitedByPaidSet() {
        let hash = "retryable-unpaid"
        manager.invoiceDetailsOverride = { _ in
            self.makeInvoiceDetails(paymentHash: hash)
        }

        var routeCalled = false
        manager.checkAndFetchRouteOverride = { _, _, _, callback in
            routeCalled = true
            callback(false)
        }

        let expectation = expectation(description: "retry allowed")
        var callbackSuccess: Bool?
        var callbackMessage: String?

        manager.payInvoice(invoice: "lnbc1retry") { success, errorMsg in
            callbackSuccess = success
            callbackMessage = errorMsg
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(routeCalled, "Unpaid hash must still attempt routing")
        XCTAssertEqual(callbackSuccess, false)
        XCTAssertNotEqual(callbackMessage, SphinxOnionManager.invoiceAlreadyPaidLocalized)
        XCTAssertFalse(manager.inFlightPaymentHashes.contains(hash))
    }

    // MARK: - handleRunReturn

    func testHandleRunReturn_alreadyPaid_skipsBalanceAndPaymentSideEffects() {
        let signal = "confirmed.mixer.already.paid"
        SphinxOnionManager.confirmedAlreadyPaidErrorSignals = [signal]

        let originalBalance = manager.walletBalanceService.balance
        let sentStatusJSON = """
        {"payment_hash":"abc123","preimage":"preimagevalue","status":"COMPLETE"}
        """
        let rr = makeRunReturn(
            error: signal,
            newBalance: 99_999,
            msgs: [
                Msg(
                    message: nil,
                    type: nil,
                    uuid: nil,
                    tag: nil,
                    index: nil,
                    sender: nil,
                    msat: nil,
                    timestamp: nil,
                    sentTo: nil,
                    fromMe: nil,
                    paymentHash: "abc123",
                    error: nil
                )
            ],
            sentStatus: sentStatusJSON
        )

        let balanceExp = expectation(description: "no balance notification")
        balanceExp.isInverted = true
        let invoiceSettledExp = expectation(description: "no invoiceIPaidSettled")
        invoiceSettledExp.isInverted = true
        let sentInvoiceExp = expectation(description: "no sentInvoiceSettled")
        sentInvoiceExp.isInverted = true

        let balanceObserver = NotificationCenter.default.addObserver(
            forName: .onBalanceDidChange,
            object: nil,
            queue: .main
        ) { _ in
            balanceExp.fulfill()
        }
        let paidObserver = NotificationCenter.default.addObserver(
            forName: .invoiceIPaidSettled,
            object: nil,
            queue: .main
        ) { _ in
            invoiceSettledExp.fulfill()
        }
        let sentObserver = NotificationCenter.default.addObserver(
            forName: .sentInvoiceSettled,
            object: nil,
            queue: .main
        ) { _ in
            sentInvoiceExp.fulfill()
        }

        let _ = manager.handleRunReturn(rr: rr)

        waitForExpectations(timeout: 0.4)
        NotificationCenter.default.removeObserver(balanceObserver)
        NotificationCenter.default.removeObserver(paidObserver)
        NotificationCenter.default.removeObserver(sentObserver)

        XCTAssertEqual(manager.walletBalanceService.balance, originalBalance)
    }

    func testHandleRunReturn_unrelatedError_stillUpdatesBalance() {
        SphinxOnionManager.confirmedAlreadyPaidErrorSignals = ["confirmed.mixer.already.paid"]

        let rr = makeRunReturn(
            error: "no route found",
            newBalance: 12_345
        )

        let balanceExp = expectation(description: "balance notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .onBalanceDidChange,
            object: nil,
            queue: .main
        ) { note in
            let balance = note.userInfo?["balance"] as? UInt64
            XCTAssertEqual(balance, 12_345)
            balanceExp.fulfill()
        }

        let _ = manager.handleRunReturn(rr: rr)

        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
        XCTAssertEqual(manager.walletBalanceService.balance, 12_345)
    }

    // MARK: - Network already-paid callback helper

    func testReportAlreadyPaidFromNetwork_invokesFailureCallback() {
        let expectation = expectation(description: "network already paid")
        var callbackSuccess: Bool?
        var callbackMessage: String?

        manager.markPaymentHashInFlight("net-hash")
        manager.reportAlreadyPaidFromNetwork(paymentHash: "net-hash") { success, errorMsg in
            callbackSuccess = success
            callbackMessage = errorMsg
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callbackSuccess, false)
        XCTAssertEqual(callbackMessage, SphinxOnionManager.invoiceAlreadyPaidLocalized)
        XCTAssertFalse(manager.inFlightPaymentHashes.contains("net-hash"))
    }
}
