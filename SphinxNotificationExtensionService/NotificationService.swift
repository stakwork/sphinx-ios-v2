import UserNotifications
import CoreData
import UIKit
import KeychainAccess
import RNCryptor
import Bugsnag

class NotificationService: UNNotificationServiceExtension {
    
    let kSharedGroupName = "group.com.gl.sphinx.v2"
    let kPushKey = "push_key"
    let kChildIndexesStorageKey = "childIndexesStorageKey"
    public static let kKeychainGroup = "8297M44YTW.sphinxV2SharedItems"
    
    var pushKey: String? {
        get {
            if let value = getKeychainValueFor(
                composedKey: kPushKey
            ), !value.isEmpty
            {
                return value
            }
            return nil
        }
    }
    
    let keychain = Keychain(service: "sphinx-app", accessGroup: NotificationService.kKeychainGroup)
    
    override init() {
        super.init()
        
        configureBugsnag()
    }
    
    func configureBugsnag() {
        Bugsnag.start()
    }
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let contentHandler = contentHandler
        
        let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        bestAttemptContent?.title = "Sphinx"
        bestAttemptContent?.body = "You have new messages"
        
        var decryptedChildIndex: UInt64? = nil
        
        if
            let pushKey = self.pushKey,
            let userInfo = bestAttemptContent?.userInfo as? [String:AnyObject],
            let child = self.getEncryptedIndexFrom(notification: userInfo)
        {
            do {
                decryptedChildIndex = try decryptChildIndex(
                    encryptedChild: child,
                    pushKey: pushKey
                )
            } catch {
                if let bestAttemptContent = bestAttemptContent {
                    contentHandler(bestAttemptContent)
                } else {
                    contentHandler(request.content)
                }
                return
            }
        }
        
        if let decryptedChildIndex = decryptedChildIndex {
            let shareableUserDefaults = UserDefaults(suiteName: kSharedGroupName)
            
            guard let encryptedString = shareableUserDefaults?.string(forKey: kChildIndexesStorageKey) else {
                if let bestAttemptContent = bestAttemptContent {
                    contentHandler(bestAttemptContent)
                } else {
                    contentHandler(request.content)
                }
                return
            }
            
            guard let pushKey = self.pushKey, let decrypted = self.decryptString(text: encryptedString, key: pushKey) else {
                if let bestAttemptContent = bestAttemptContent {
                    contentHandler(bestAttemptContent)
                } else {
                    contentHandler(request.content)
                }
                return
            }
            
            if let contactsArray = getContactsJsonDic(contacts: decrypted) {
                if let contactName = contactsArray["contact-\(decryptedChildIndex)"] {
                    bestAttemptContent?.body = "You have new messages from \(contactName)"
                } else if let tribeName = contactsArray["tribe-\(decryptedChildIndex)"] {
                    bestAttemptContent?.body = "You have new messages in \(tribeName)"
                }
            }
        }
            
        if let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        } else {
            contentHandler(request.content)
        }
        return
    }
    
    func getContactsJsonDic(contacts: String) -> [String: String]? {
        if let jsonData = contacts.data(using: .utf8) {
            do {
                // Parse the JSON data into a dictionary
                if let jsonDict = try JSONSerialization.jsonObject(
                    with: jsonData,
                    options: []
                ) as? [String: String] {
                    return jsonDict
                }
            } catch {
                return nil
            }
        }
        return nil
    }
    
    func getKeychainValueFor(composedKey: String) -> String? {
        do {
            let value = try keychain.get(composedKey)
            return value
        } catch let error {
            print(error.localizedDescription)
            return nil
        }
    }
    
    func saveKeychain(value: String, forComposedKey key: String) -> Bool {
        do {
            try keychain.set(value, key: key)
            return true
        } catch let error {
            print(error.localizedDescription)
            return false
        }
    }
    
    func encryptString(text: String, key: String) -> String? {
        if let data = text.data(using: .utf8) {
            let encryptedData = RNCryptor.encrypt(data: data, withPassword: key)
            return encryptedData.base64EncodedString()
        }
        return nil
    }
    
    func decryptString(text: String, key: String) -> String? {
        var decryptedData : Data? = nil
        
        if let data = Data(base64Encoded: text) {
            do {
                decryptedData = try RNCryptor.decrypt(data: data, withPassword: key)
            } catch {
                print(error)
            }
            
            if let decryptedData = decryptedData {
                return String(decoding: decryptedData, as: UTF8.self)
            }
        }
        return nil
    }
    
    func getEncryptedIndexFrom(
        notification: [String: AnyObject]?
    ) -> String? {
        if
            let notification = notification,
            let aps = notification["aps"] as? [String: AnyObject],
            let customData = aps["custom_data"] as? [String: AnyObject]
        {
            if let chatId = customData["child"] as? String {
                return chatId
            }
        }
        return nil
    }
}
