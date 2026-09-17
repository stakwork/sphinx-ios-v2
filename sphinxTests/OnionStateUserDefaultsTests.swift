//
//  OnionStateUserDefaultsTests.swift
//  sphinxTests
//
//  Onion-state persistence, UserDefaults reset, and color hydrate
//  must not snapshot or synchronize the live standard defaults dictionary.
//

import XCTest
import UIKit
@testable import sphinx

final class OnionStateUserDefaultsTests: XCTestCase {

    private let testKeyPrefix = "sigtrap.onion."
    private let concurrentIterations = 24

    override func setUp() {
        super.setUp()
        resetOnionAndColorFixtures()
    }

    override func tearDown() {
        resetOnionAndColorFixtures()
        SphinxOnionManager.resetSharedInstance()
        super.tearDown()
    }

    private func makeFreshManager() -> SphinxOnionManager {
        SphinxOnionManager.resetSharedInstance()
        UserDefaults.Keys.onionState.removeValue()
        return SphinxOnionManager.sharedInstance
    }

    private func resetOnionAndColorFixtures() {
        let defaults = UserDefaults.standard
        let keysToRemove = [
            testKeyPrefix + "bytes",
            testKeyPrefix + "nsarray",
            testKeyPrefix + "data",
            testKeyPrefix + "skip",
            testKeyPrefix + "roundtrip",
            testKeyPrefix + "to-delete",
            testKeyPrefix + "keep",
            testKeyPrefix + "chat-color",
            testKeyPrefix + "set-color",
            testKeyPrefix + "remove-color",
            "c/testpubkey123",
            "legacy-color-key",
            "empty-index-unique-key",
            "sigtrap.reset.test",
            "onionState",
            "chatColorKeys"
        ]
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }
        for i in 0..<concurrentIterations {
            defaults.removeObject(forKey: "conc-\(i)")
        }
        ColorsManager.sharedInstance.colors = [:]
        UserDefaults.Keys.chatColorKeys.removeValue()
        UserDefaults.Keys.onionState.removeValue()
    }

    // MARK: - storeOnionStateInMemory hydration

    func test_storeOnionStateInMemory_hydratesNSArrayNSNumberAndData() {
        let mgr = makeFreshManager()
        let keyBytes = testKeyPrefix + "bytes"
        let keyArray = testKeyPrefix + "nsarray"
        let keyData = testKeyPrefix + "data"
        let keySkip = testKeyPrefix + "skip"

        UserDefaults.standard.set([1, 2, 3].map { NSNumber(value: $0) }, forKey: keyBytes)
        UserDefaults.standard.set(
            NSArray(array: [NSNumber(value: 4), NSNumber(value: 5), NSNumber(value: 255)]),
            forKey: keyArray
        )
        UserDefaults.standard.set(Data([6, 7, 8]), forKey: keyData)
        UserDefaults.standard.set("not-bytes", forKey: keySkip)

        mgr.mutationKeys = [keyBytes, keyArray, keyData, keySkip]
        mgr.storeOnionStateInMemory()

        let state = mgr.loadOnionState()
        XCTAssertEqual(state[keyBytes], [1, 2, 3])
        XCTAssertEqual(state[keyArray], [4, 5, 255])
        XCTAssertEqual(state[keyData], [6, 7, 8])
        XCTAssertNil(state[keySkip], "Non-convertible values must be skipped, not crash")
    }

    func test_storeOnionState_thenLoadOnionStateAsData_roundTrips() {
        let mgr = makeFreshManager()
        let key = testKeyPrefix + "roundtrip"
        let value: [UInt8] = [9, 8, 7, 6]
        let packed = mgr.packedOnionStateMutations([key: value])

        let _ = mgr.storeOnionState(inc: packed)

        XCTAssertEqual(mgr.loadOnionState()[key], value)
        XCTAssertFalse(mgr.loadOnionStateAsData().isEmpty)
        XCTAssertNotNil(UserDefaults.standard.object(forKey: key))
        XCTAssertTrue(mgr.mutationKeys.contains(key))
    }

    // MARK: - Concurrent access

    func test_concurrentStoreLoadAndDelete_doesNotCrashAndStaysConsistent() {
        let mgr = makeFreshManager()
        let group = DispatchGroup()

        let deleteKey = testKeyPrefix + "to-delete"
        let _ = mgr.storeOnionState(inc: mgr.packedOnionStateMutations([deleteKey: [9, 9, 9]]))

        for i in 0..<concurrentIterations {
            group.enter()
            DispatchQueue.global().async {
                let key = "conc-\(i)"
                let value: [UInt8] = [UInt8(i), 42, 255]
                let packed = mgr.packedOnionStateMutations([key: value])
                let _ = mgr.storeOnionState(inc: packed)
                group.leave()
            }

            group.enter()
            DispatchQueue.global().async {
                let _ = mgr.loadOnionStateAsData()
                group.leave()
            }
        }

        group.enter()
        DispatchQueue.global().async {
            mgr.handleStateToDelete(stateToDelete: [deleteKey])
            group.leave()
        }

        let waitResult = group.wait(timeout: .now() + 8)
        XCTAssertEqual(waitResult, .success, "onionState access must not deadlock")

        let state = mgr.loadOnionState()
        for i in 0..<concurrentIterations {
            XCTAssertEqual(
                state["conc-\(i)"],
                [UInt8(i), 42, 255],
                "stored onion-state values must be complete, not corrupted"
            )
        }
        XCTAssertNil(state[deleteKey])
        XCTAssertNil(UserDefaults.standard.object(forKey: deleteKey))
    }

    // MARK: - deleteContactFromState removes UserDefaults keys

    func test_deleteContactFromState_removesDroppedKeysFromUserDefaults() {
        let mgr = makeFreshManager()
        let pubkey = "testpubkey123"
        let contactKey = "c/" + pubkey
        let keepKey = testKeyPrefix + "keep"

        let _ = mgr.storeOnionState(inc: mgr.packedOnionStateMutations([
            contactKey: [1, 1, 1],
            keepKey: [2, 2, 2]
        ]))

        XCTAssertNotNil(UserDefaults.standard.object(forKey: contactKey))
        XCTAssertNotNil(UserDefaults.standard.object(forKey: keepKey))

        mgr.deleteContactFromState(pubkey: pubkey)

        XCTAssertNil(UserDefaults.standard.object(forKey: contactKey))
        XCTAssertEqual(mgr.loadOnionState()[keepKey], [2, 2, 2])
        XCTAssertNotNil(UserDefaults.standard.object(forKey: keepKey))
        XCTAssertFalse(mgr.mutationKeys.contains(contactKey))
        XCTAssertTrue(mgr.mutationKeys.contains(keepKey))
        XCTAssertNil(mgr.loadOnionState()[contactKey])
    }

    // MARK: - resetUserDefaults

    func test_resetUserDefaults_clearsStandardDomainWithoutDictionarySnapshot() {
        UserDefaults.standard.set("keep-me", forKey: "sigtrap.reset.test")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "sigtrap.reset.test"), "keep-me")

        UserDefaults.resetUserDefaults()

        XCTAssertNil(UserDefaults.standard.object(forKey: "sigtrap.reset.test"))
    }

    // MARK: - Color hydrate

    func test_storeColorsInMemory_readsPersistedKeyIndexOnly() {
        let colorKey = testKeyPrefix + "chat-color"
        let indexedHex = "#7077FF"
        let unindexedKey = "legacy-color-key"
        let unindexedHex = "#FF3D3D"

        UserDefaults.standard.set(indexedHex, forKey: colorKey)
        UserDefaults.standard.set(unindexedHex, forKey: unindexedKey)
        UserDefaults.Keys.chatColorKeys.set([colorKey])
        ColorsManager.sharedInstance.colors = [:]

        ColorsManager.sharedInstance.storeColorsInMemory()

        XCTAssertEqual(ColorsManager.sharedInstance.getColorFor(key: colorKey), indexedHex)
        XCTAssertNil(
            ColorsManager.sharedInstance.getColorFor(key: unindexedKey),
            "Keys missing from the persisted index must not be bulk-hydrated"
        )
    }

    func test_getColorFor_stillWorksWhenColorIndexIsEmpty() {
        let legacyKey = "legacy-color-key"
        UserDefaults.Keys.chatColorKeys.removeValue()
        ColorsManager.sharedInstance.colors = [:]
        UserDefaults.standard.set("#7077FF", forKey: legacyKey)

        ColorsManager.sharedInstance.storeColorsInMemory()
        XCTAssertTrue(ColorsManager.sharedInstance.colors.isEmpty)

        let color = UIColor.getColorFor(key: legacyKey)
        XCTAssertEqual(color.toHexString()?.lowercased(), "#7077ff")

        let generated = UIColor.getColorFor(key: "empty-index-unique-key")
        XCTAssertNotNil(generated.toHexString())
    }

    func test_setColorFor_updatesPersistedIndex() {
        let colorKey = testKeyPrefix + "set-color"
        ColorsManager.sharedInstance.setColorFor(colorHex: "#DBD23C", key: colorKey)

        let keys = UserDefaults.Keys.chatColorKeys.get(defaultValue: [String]())
        XCTAssertTrue(keys.contains(colorKey))
        XCTAssertEqual(UserDefaults.standard.string(forKey: colorKey), "#DBD23C")

        ColorsManager.sharedInstance.colors = [:]
        ColorsManager.sharedInstance.storeColorsInMemory()
        XCTAssertEqual(ColorsManager.sharedInstance.getColorFor(key: colorKey), "#DBD23C")
    }

    func test_removeColorFor_dropsKeyFromIndex() {
        let colorKey = testKeyPrefix + "remove-color"
        ColorsManager.sharedInstance.setColorFor(colorHex: "#F57D25", key: colorKey)
        UIColor.removeColorFor(key: colorKey)

        let keys = UserDefaults.Keys.chatColorKeys.get(defaultValue: [String]())
        XCTAssertFalse(keys.contains(colorKey))
        XCTAssertNil(UserDefaults.standard.object(forKey: colorKey))
        XCTAssertNil(ColorsManager.sharedInstance.getColorFor(key: colorKey))
    }
}
