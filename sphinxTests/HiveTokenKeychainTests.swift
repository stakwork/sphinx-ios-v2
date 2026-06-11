//
//  HiveTokenKeychainTests.swift
//  sphinxTests
//
//  Created for visionOS SSO keychain co-write tests.
//

import XCTest
@testable import sphinx

class HiveTokenKeychainTests: XCTestCase {

    private let keychainKey = "com.sphinx.hiveToken"

    override func tearDown() {
        super.tearDown()
        // Clean up after each test
        UserDefaults.Keys.hiveToken.set("")
        _ = KeychainManager.sharedInstance.deleteValueFor(composedKey: keychainKey)
    }

    func testStoreWritesToUserDefaults() {
        API.sharedInstance.storeHiveToken("tok-123")
        let stored: String? = UserDefaults.Keys.hiveToken.get()
        XCTAssertEqual(stored, "tok-123", "UserDefaults should contain the stored token")
    }

    func testStoreWritesToSharedKeychain() {
        API.sharedInstance.storeHiveToken("tok-123")
        let keychainValue = KeychainManager.sharedInstance.getValueFor(composedKey: keychainKey)
        XCTAssertEqual(keychainValue, "tok-123", "Shared keychain should contain the stored token")
    }

    func testOverwriteUpdatesKeychain() {
        API.sharedInstance.storeHiveToken("tok-first")
        API.sharedInstance.storeHiveToken("tok-second")
        let keychainValue = KeychainManager.sharedInstance.getValueFor(composedKey: keychainKey)
        XCTAssertEqual(keychainValue, "tok-second", "Keychain should reflect the most recent token")
    }

    func testOverwriteUpdatesUserDefaults() {
        API.sharedInstance.storeHiveToken("tok-first")
        API.sharedInstance.storeHiveToken("tok-second")
        let stored: String? = UserDefaults.Keys.hiveToken.get()
        XCTAssertEqual(stored, "tok-second", "UserDefaults should reflect the most recent token")
    }
}
