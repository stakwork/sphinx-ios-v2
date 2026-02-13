//
//  DataSyncManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 30/12/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import CoreData

class DataSyncManager: NSObject {

    // MARK: - Singleton

    static let sharedInstance = DataSyncManager()

    // MARK: - Properties

    private let syncQueue = DispatchQueue(label: "com.sphinx.datasync.queue", qos: .utility)
    private var syncWorkItem: DispatchWorkItem?
    private var isSyncing = false
    private let syncLock = NSLock()

    /// Dedicated background context for all DataSync operations
    private lazy var syncContext: NSManagedObjectContext = {
        return CoreDataManager.sharedManager.getBackgroundContext()
    }()

    /// Debounce interval in seconds before triggering sync
    private let syncDebounceInterval: TimeInterval = 2.0

    // MARK: - Setting Keys

    /// Typealias for backward compatibility
    typealias SettingKey = DataSyncSettingKey

    // MARK: - Private Init

    private override init() {
        super.init()
    }

    // MARK: - Public Save Methods

    func saveTipAmount(value: String) {
        saveDataSyncItemWith(
            key: SettingKey.tipAmount.rawValue,
            identifier: "0",
            value: value
        )
    }

    func savePrivatePhoto(value: String) {
        saveDataSyncItemWith(
            key: SettingKey.privatePhoto.rawValue,
            identifier: "0",
            value: value
        )
    }

    func saveTimezoneFor(
        chatPubkey: String,
        timezone: TimezoneSetting
    ) {
        if let jsonString = timezone.toJSONString() {
            saveDataSyncItemWith(
                key: SettingKey.timezone.rawValue,
                identifier: chatPubkey,
                value: jsonString
            )
        }
    }

    func saveFeedStatusFor(
        feedId: String,
        feedStatus: FeedStatus
    ) {
        if let stringValue = feedStatus.toJSONString() {
            saveDataSyncItemWith(
                key: SettingKey.feedStatus.rawValue,
                identifier: feedId,
                value: stringValue
            )
        }
    }

    func saveFeedItemStatusFor(
        feedId: String,
        itemId: String,
        feedItemStatus: FeedItemStatus
    ) {
        if let jsonString = feedItemStatus.toJSONString() {
            saveDataSyncItemWith(
                key: SettingKey.feedItemStatus.rawValue,
                identifier: "\(feedId)-\(itemId)",
                value: jsonString
            )
        }
    }

    // MARK: - Core Save Method

    private func saveDataSyncItemWith(
        key: String,
        identifier: String,
        value: String
    ) {
        syncContext.perform { [weak self] in
            guard let self = self else { return }

            let dataSyncItem = DataSync.getContentItemWith(
                key: key,
                identifier: identifier,
                context: self.syncContext
            ) ?? DataSync(context: self.syncContext)

            dataSyncItem.key = key
            dataSyncItem.identifier = identifier
            dataSyncItem.value = value
            dataSyncItem.date = Date()

            self.syncContext.saveContext()
            self.scheduleSyncWithServer()
        }
    }

    // MARK: - Sync Scheduling (Debouncing)

    /// Schedules a sync with debouncing to prevent excessive server calls
    private func scheduleSyncWithServer() {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            // Cancel any pending sync
            self.syncWorkItem?.cancel()

            // Create new work item
            let workItem = DispatchWorkItem { [weak self] in
                self?.performSyncWithServer()
            }
            self.syncWorkItem = workItem

            // Schedule with debounce delay
            self.syncQueue.asyncAfter(
                deadline: .now() + self.syncDebounceInterval,
                execute: workItem
            )
        }
    }

    /// Called from AppDelegate when app comes to foreground
    func syncWithServerInBackground() {
        syncQueue.async { [weak self] in
            self?.performSyncWithServer()
        }
    }

    // MARK: - Sync Implementation

    private func performSyncWithServer() {
        // Prevent concurrent syncs
        syncLock.lock()
        guard !isSyncing else {
            syncLock.unlock()
            #if DEBUG
            print("DataSync: Sync already in progress, skipping")
            #endif
            return
        }
        isSyncing = true
        syncLock.unlock()

        Task {
            defer {
                syncLock.lock()
                isSyncing = false
                syncLock.unlock()
            }

            await syncWithServer()
        }
    }

    private func syncWithServer() async {
        let serverDataString = await getFileFromServer()
        var itemsResponse = parseFileText(text: serverDataString ?? "") ?? ItemsResponse(items: [])

        // Fetch local items within sync context
        var dbItems: [DataSync] = []
        await syncContext.perform {
            dbItems = DataSync.getAllDataSync(context: self.syncContext)
        }

        let missingItems = findMissingItems(localItems: dbItems, serverItems: itemsResponse.items)

        // Collect all items that need to be restored from server
        var itemsToRestore: [SettingItem] = []

        // Add missing items (items in server but not in local DB)
        itemsToRestore.append(contentsOf: missingItems)

        // Track items to delete after successful upload
        var itemsToDelete: [DataSync] = []

        // Merge local items with server items
        await syncContext.perform {
            for item in dbItems {
                if let index = itemsResponse.getItemIndex(key: item.key, identifier: item.identifier) {
                    let serverItem = itemsResponse.items[index]

                    if serverItem.date.timeIntervalSince1970 < item.date.timeIntervalSince1970 {
                        // Local is newer - update server item
                        if let key = SettingKey(rawValue: item.key),
                           let settingValue = SettingValue.from(string: item.value, forKey: key) {
                            let newItem = SettingItem(
                                key: item.key,
                                identifier: item.identifier,
                                dateString: "\(item.date.timeIntervalSince1970)",
                                value: settingValue
                            )
                            itemsResponse.items[index] = newItem
                        }
                    } else {
                        // Server is newer - add to restore list
                        itemsToRestore.append(serverItem)
                    }
                    itemsToDelete.append(item)
                } else {
                    // Item doesn't exist on server - add it
                    if let key = SettingKey(rawValue: item.key),
                       let settingValue = SettingValue.from(string: item.value, forKey: key) {
                        let newItem = SettingItem(
                            key: item.key,
                            identifier: item.identifier,
                            dateString: "\(item.date.timeIntervalSince1970)",
                            value: settingValue
                        )
                        itemsResponse.items.append(newItem)
                    }
                    itemsToDelete.append(item)
                }
            }
        }

        // Sort items so feed_status are restored before feed_item_status
        // This ensures feeds are available when their item statuses are applied
        let sortedItemsToRestore = sortItemsForRestore(itemsToRestore)

        for item in sortedItemsToRestore {
            await restoreDataFrom(serverItem: item)
        }

        // MARK: - Chat Colors Sync (First One Wins Logic)
        // Colors in server but not local are already handled above via restoreDataFrom
        // Now add local colors that don't exist in server
        await MainActor.run {
            itemsResponse = self.syncChatColors(itemsResponse: itemsResponse)
        }

        // Upload to server and only delete local items on success
        let uploadSuccess = await saveFileToServer(itemResponse: itemsResponse)

        if uploadSuccess {
            await syncContext.perform {
                for item in itemsToDelete {
                    self.syncContext.delete(item)
                }
                self.syncContext.saveContext()
            }
            #if DEBUG
            print("DataSync: Successfully synced \(itemsResponse.items.count) items")
            #endif
        } else {
            #if DEBUG
            print("DataSync: Upload failed, keeping local items for retry")
            #endif
        }
    }

    // MARK: - Helper Methods

    /// Finds items that exist on server but not in local database
    private func findMissingItems(localItems: [DataSync], serverItems: [SettingItem]) -> [SettingItem] {
        let localSet = Set(localItems.map { "\($0.key)-\($0.identifier)" })

        return serverItems.filter { item in
            let combinedKey = "\(item.key)-\(item.identifier)"
            return !localSet.contains(combinedKey)
        }
    }

    /// Parses the identifier for feedItemStatus which uses "feedId-itemId" format
    /// Handles feedIds that may contain hyphens by splitting on the last hyphen
    private func parseFeedItemIdentifier(_ identifier: String) -> (feedId: String, itemId: String)? {
        guard let lastHyphenIndex = identifier.lastIndex(of: "-") else {
            return nil
        }

        let feedId = String(identifier[..<lastHyphenIndex])
        let itemId = String(identifier[identifier.index(after: lastHyphenIndex)...])

        guard !feedId.isEmpty && !itemId.isEmpty else {
            return nil
        }

        return (feedId, itemId)
    }

    /// Sorts items so feed_status items are processed before feed_item_status items.
    /// This ensures feeds are created/fetched before their item statuses are applied.
    private func sortItemsForRestore(_ items: [SettingItem]) -> [SettingItem] {
        return items.sorted { item1, item2 in
            let isFeedStatus1 = item1.key == SettingKey.feedStatus.rawValue
            let isFeedStatus2 = item2.key == SettingKey.feedStatus.rawValue

            // feed_status items come first
            if isFeedStatus1 && !isFeedStatus2 {
                return true
            }
            if !isFeedStatus1 && isFeedStatus2 {
                return false
            }
            // Maintain original order for items of the same type
            return false
        }
    }

    // MARK: - Chat Colors Sync

    /// Syncs chat colors with "first one wins" logic.
    /// Colors from server are already applied to local via restoreDataFrom.
    /// This method adds local colors that don't exist on server to the items response.
    private func syncChatColors(itemsResponse: ItemsResponse) -> ItemsResponse {
        var updatedResponse = itemsResponse

        // Get all server color identifiers
        let serverColorIdentifiers = Set(
            itemsResponse.items
                .filter { $0.key == SettingKey.chatColor.rawValue }
                .map { $0.identifier }
        )

        // Get all local colors from ColorsManager
        let localColors = ColorsManager.sharedInstance.getAllColors()

        // Add local colors that don't exist on server
        for (colorKey, colorHex) in localColors {
            if !serverColorIdentifiers.contains(colorKey) {
                let newItem = SettingItem(
                    key: SettingKey.chatColor.rawValue,
                    identifier: colorKey,
                    dateString: "\(Int(Date().timeIntervalSince1970))",
                    value: .string(colorHex)
                )
                updatedResponse.items.append(newItem)

                #if DEBUG
                print("DataSync: Adding local chat color to server: \(colorKey) = \(colorHex)")
                #endif
            }
        }

        return updatedResponse
    }

    // MARK: - Data Restoration

    private func restoreDataFrom(serverItem: SettingItem) async {
        guard let key = SettingKey(rawValue: serverItem.key) else { return }

        await MainActor.run {
            switch key {
            case .tipAmount:
                if let intValue = serverItem.value.asInt {
                    UserContact.kTipAmount = intValue
                }

            case .privatePhoto:
                if let boolValue = serverItem.value.asBool {
                    if let owner = UserContact.getOwner() {
                        owner.privatePhoto = boolValue
                        owner.managedObjectContext?.saveContext()
                    }
                }

            case .timezone:
                if let chat = Chat.getChatWithOwnerPubkey(ownerPubkey: serverItem.identifier) {
                    chat.timezoneEnabled = serverItem.value.asTimezone?.timezoneEnabled ?? chat.timezoneEnabled
                    chat.timezoneIdentifier = serverItem.value.asTimezone?.timezoneIdentifier
                    chat.timezoneUpdated = true
                    chat.managedObjectContext?.saveContext()
                }

            case .feedStatus:
                if let feedStatus = serverItem.value.asFeedStatus {
                    if let feed = ContentFeed.getFeedById(feedId: serverItem.identifier) {
                        let podFeed = PodcastFeed.convertFrom(contentFeed: feed)
                        feed.chat = Chat.getChatWithOwnerPubkey(ownerPubkey: feedStatus.chatPubkey)
                        feed.feedURL = URL(string: feedStatus.feedUrl)
                        feed.isSubscribedToFromSearch = feedStatus.subscribed

                        podFeed.satsPerMinute = feedStatus.satsPerMinute
                        podFeed.playerSpeed = Float(feedStatus.playerSpeed)

                        if feedStatus.itemId.isNotEmpty, podFeed.currentEpisodeId != feedStatus.itemId {
                            podFeed.currentEpisodeId = feedStatus.itemId
                            
                            if feed.dateLastConsumed == nil {
                                feed.dateLastConsumed = Date()
                            }
                        }
                        feed.managedObjectContext?.saveContext()

                        // Refresh the feed UI to show in Recently Played
                        FeedsManager.sharedInstance.refreshFeedUI()
                    } else {
                        FeedsManager.sharedInstance.getContentFeedFor(
                            feedId: feedStatus.feedId,
                            feedUrl: feedStatus.feedUrl,
                            chat: Chat.getChatWithOwnerPubkey(ownerPubkey: feedStatus.chatPubkey),
                            context: syncContext,
                            shouldSaveFeedStatus: false,  // Don't save - we're restoring from server
                            completion: { contentFeed in
                                // After feed is fetched, set the current episode and date
                                if let feed = contentFeed, feedStatus.itemId.isNotEmpty {
                                    let podFeed = PodcastFeed.convertFrom(contentFeed: feed)
                                    podFeed.currentEpisodeId = feedStatus.itemId
                                    feed.dateLastConsumed = Date()
                                    feed.managedObjectContext?.saveContext()

                                    // Refresh the feed UI to show in Recently Played
                                    FeedsManager.sharedInstance.refreshFeedUI()
                                }
                            }
                        )
                    }
                }

            case .feedItemStatus:
                guard let parsed = parseFeedItemIdentifier(serverItem.identifier),
                      let feedItem = ContentFeedItem.getItemWith(itemID: parsed.itemId),
                      let feedItemStatus = serverItem.value.asFeedItemStatus else {
                    return
                }

                let podEpisode = PodcastEpisode.convertFrom(contentFeedItem: feedItem)
                podEpisode.feedID = parsed.feedId
                podEpisode.duration = feedItemStatus.duration
                podEpisode.currentTime = feedItemStatus.currentTime
                feedItem.managedObjectContext?.saveContext()

            case .chatColor:
                // Chat colors are restored directly to ColorsManager and UserDefaults
                if let colorHex = serverItem.value.asString {
                    ColorsManager.sharedInstance.setColorFor(
                        colorHex: colorHex,
                        key: serverItem.identifier
                    )
                }
            }
        }
    }

    // MARK: - File Parsing

    func parseFileText(text: String) -> ItemsResponse? {
        guard let data = text.data(using: .utf8) else {
            #if DEBUG
            print("DataSync: Failed to convert text to UTF-8 data")
            #endif
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(ItemsResponse.self, from: data)

            #if DEBUG
            printParsedItems(response)
            #endif

            return response
        } catch {
            #if DEBUG
            printDecodingError(error)
            #endif
            return nil
        }
    }

    #if DEBUG
    private func printParsedItems(_ response: ItemsResponse) {
        print("DataSync: Successfully parsed \(response.items.count) items")

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current

        for item in response.items {
            print("  - Key: \(item.key), Identifier: \(item.identifier), Date: \(formatter.string(from: item.date))")
        }
    }

    private func printDecodingError(_ error: Error) {
        print("DataSync: Error parsing JSON: \(error)")
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .dataCorrupted(let context):
                print("  Context: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("  Key '\(key.stringValue)' not found: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("  Type '\(type)' mismatch: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("  Value '\(type)' not found: \(context.debugDescription)")
            @unknown default:
                print("  Unknown decoding error")
            }
        }
    }
    #endif

    // MARK: - Server Communication

    private func getFileFromServer() async -> String? {
        let attachmentsManager = AttachmentsManager.sharedInstance
        let isAuthenticated = attachmentsManager.isAuthenticated()

        if !isAuthenticated.0 {
            let authSuccess = await authenticateWithServer()
            if !authSuccess {
                return nil
            }
            return await getFileFromServer()
        }

        guard let token = isAuthenticated.1 else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            API.sharedInstance.getPersonalPreferencesFile(
                token: token,
                callback: { [weak self] data in
                    guard let self = self,
                          let string = String(data: data, encoding: .utf8),
                          let decrypted = self.decrypt(value: string) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: decrypted)
                },
                errorCallback: {
                    continuation.resume(returning: nil)
                }
            )
        }
    }

    private func authenticateWithServer() async -> Bool {
        return await withCheckedContinuation { continuation in
            AttachmentsManager.sharedInstance.authenticate(
                completion: {
                    continuation.resume(returning: true)
                },
                errorCompletion: {
                    #if DEBUG
                    print("DataSync: Error authenticating with memes server")
                    #endif
                    continuation.resume(returning: false)
                }
            )
        }
    }

    private func saveFileToServer(itemResponse: ItemsResponse) async -> Bool {
        if itemResponse.items.isEmpty {
            return true // Nothing to save is considered success
        }

        guard let text = itemResponse.toOriginalFormatJSON(),
              let encrypted = encrypt(value: text) else {
            #if DEBUG
            print("DataSync: Failed to encrypt data for upload")
            #endif
            return false
        }

        guard let pubkey = UserContact.getOwner()?.publicKey,
              let base64URLPubkey = hexToBase64URL(pubkey) else {
            #if DEBUG
            print("DataSync: Failed to get owner pubkey")
            #endif
            return false
        }

        let attachmentsManager = AttachmentsManager.sharedInstance
        let isAuthenticated = attachmentsManager.isAuthenticated()

        if !isAuthenticated.0 {
            let authSuccess = await authenticateWithServer()
            if !authSuccess {
                return false
            }
            return await saveFileToServer(itemResponse: itemResponse)
        }

        guard let token = isAuthenticated.1,
              let data = encrypted.data(using: .utf8) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            API.sharedInstance.uploadPersonalPreferences(
                data: data,
                pubkey: base64URLPubkey,
                token: token,
                progressCallback: { progress in
                    #if DEBUG
                    print("DataSync: Upload progress: \(progress)%")
                    #endif
                },
                callback: { success, _ in
                    continuation.resume(returning: success)
                },
                errorCallback: { error in
                    #if DEBUG
                    print("DataSync: Upload error: \(error)")
                    #endif
                    continuation.resume(returning: false)
                }
            )
        }
    }

    // MARK: - Encryption

    private func encrypt(value: String) -> String? {
        guard let keys = SphinxOnionManager.sharedInstance.getPersonalKeys() else {
            return nil
        }
        return SymmetricEncryptionManager.sharedInstance.encryptString(text: value, key: keys.secret)
    }

    private func decrypt(value: String) -> String? {
        guard let keys = SphinxOnionManager.sharedInstance.getPersonalKeys() else {
            return nil
        }
        return SymmetricEncryptionManager.sharedInstance.decryptString(text: value, key: keys.secret)
    }

    // MARK: - Utilities

    private func hexToBase64URL(_ hex: String) -> String? {
        var data = Data()
        var hex = hex

        while hex.count > 0 {
            let index = hex.index(hex.startIndex, offsetBy: 2)
            let byteString = String(hex[..<index])
            hex = String(hex[index...])
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
        }

        let base64 = data.base64EncodedString()

        let base64URL = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return base64URL
    }

    // MARK: - Debug Utilities

    func deleteFile() {
        let fileName = "datasync.txt"
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)

        do {
            try fileManager.removeItem(at: fileURL)
            #if DEBUG
            print("DataSync: File deleted successfully")
            #endif
        } catch {
            #if DEBUG
            print("DataSync: Error deleting file: \(error)")
            #endif
        }
    }
}
