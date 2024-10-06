//
//  sphinxOnionPlaintextMessagesTests.swift
//  sphinxTests
//
//  Created by James Carucci on 12/6/23.
//  Copyright © 2023 sphinx. All rights reserved.
//

//Test Regime 3 - Messaging

import XCTest
import Alamofire
import SwiftyJSON
@testable import sphinx


func sendRemoteServerMessageRequest(
    cmd: String,
    pubkey: String,
    theMsg: String,
    amount: Int = 0,
    useAmount: Bool = true,
    useMsg: Bool = true,
    additionalParams: [String] = [],
    omitPubkey: Bool = false
) {
    let url = "http://localhost:4020/command"
    var parametersArray: [Any] = []
    
    if cmd == "pay_invoice" {
        // For pay_invoice, we only want to send the invoice string
        parametersArray = [theMsg]
    } else {
        if !omitPubkey {
            parametersArray.append(pubkey)
        }
        if useAmount {
            parametersArray.append(amount)
        }
        if useMsg {
            parametersArray.append(theMsg)
        }
        parametersArray += additionalParams
    }
    
    let parameters: [String: Any] = [
        "command": cmd,
        "parameters": parametersArray
    ]
    
    AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { response in
        switch response.result {
        case .success(let value):
            print("Response: \(value)")
        case .failure(let error):
            print("Error: \(error)")
        }
    }
}

func requestListenForIncomingMessage(completion: @escaping (JSON) -> ()) {
    let url = "http://localhost:4020/arm"
    let parameters: [String: Any] = [:]
    
    AF.request(url, method: .get, encoding: JSONEncoding.default).responseJSON { response in
        switch response.result {
        case .success(let data):
            let json = JSON(data)
            print("Response: \(json)")
            completion(json)
        case .failure(let error):
            print("Error: \(error)")
            completion(JSON())
        }
    }
}//03ff1c4e658be3ee59575b24e631945cd640926fb7cb095a569da7bb3bfcad5867_02adccd7f574d17d627541b447f47493916e78e33c1583ba9936607b35ca99c392_529771090635784199

final class sphinxOnionPlaintextMessagesTests: XCTestCase {
    let sphinxOnionManager = SphinxOnionManager.sharedInstance
    //Account details for test account aka David
    let test_mnemonic2 = "hair live delay memory injury float extend mixture fetch excuse control hedgehog"
    
    var receivedMessage : [String:Any]? = nil
    let test_sender_pubkey = "023be900c195aee419e5f68bf4b7bc156597da7649a9103b1afec949d233e4d1aa"
    let test_contact_info = "023be900c195aee419e5f68bf4b7bc156597da7649a9103b1afec949d233e4d1aa_02adccd7f574d17d627541b447f47493916e78e33c1583ba9936607b35ca99c392_529771090670583808"
    var test_received_message_content = "SphinxIsAwesome"
    let self_alias = "satoshi"
    let myPubkey = "0224ac5c13ac02ba7b12b60e0661711952e371976df3e5de90247777ab9d708339"
    
    //Mnemonic for "sock puppet" account that helps test: post captain sister quit hurt stadium brand leopard air give funny begin
    
    
    func establish_self_contact(){
        guard let seed = sphinxOnionManager.getAccountSeed(mnemonic: test_mnemonic2),
            let xpub = sphinxOnionManager.getAccountXpub(seed: seed),
            let pubkey = sphinxOnionManager.getAccountOnlyKeysendPubkey(seed: seed) else{
                  XCTFail("failure to properly generate seed & then ok key (test_connect_to_mqtt_broker)")
                return
          }
        
        let success = sphinxOnionManager.connectToBroker(seed: seed, xpub: xpub)
        XCTAssert(success == true, "Failed to connect to test broker :/")
        
        //subscribe to relevant topics
        sphinxOnionManager.mqtt.didConnectAck = { _, _ in
            //self.showSuccessWithMessage("MQTT connected")
            print("SphinxOnionManager: MQTT Connected")
            print("mqtt.didConnectAck")
            self.sphinxOnionManager.subscribeAndPublishMyTopics(pubkey: pubkey, idx: 0)
            //self.sphinxOnionManager.getUnreadOkKeyMessages(sinceIndex: 1, limit: 1)
        }
        
    }
    
    func enforceDelay(delay: TimeInterval) {
        let expectation3 = XCTestExpectation(description: "Expecting to have retrieved message in time")
        fulfillExpectationAfterDelay(expectation: expectation3, delayInSeconds: delay)
        // Wait for the expectation to be fulfilled.
        wait(for: [expectation3], timeout: delay + 1.0)
    }
    
    func establish_test_contact() {
        // Assuming `makeFriendRequest` and the existence of `test_contact_info` and `self_alias` are correct as provided
        sphinxOnionManager.mqtt.didReceiveMessage = { mqtt, receivedMessage, id in
            self.sphinxOnionManager.processMqttMessages(message: receivedMessage)
        }
        sphinxOnionManager.makeFriendRequest(contactInfo: test_contact_info, nickname: self_alias)
        let myUserId = UserData.sharedInstance.getUserId()
        
        
        guard let contact = UserContact.getContactWithDisregardStatus(pubkey: self.test_sender_pubkey) else{
            return
        }
        
        let expectation = XCTestExpectation(description: "Expecting to have established self contact in this time.")
        enforceDelay(delay: 8.0)
        
        // Assuming `sphinxOnionManager.managedContext` is a valid NSManagedObjectContext
        let chat = Chat(context: self.sphinxOnionManager.managedContext)
        
        // Set mandatory fields with neutral values
        chat.id = 21 // Provided as an example, assuming this is mandatory and unique for each chat
        chat.type = 0 // Assuming '0' is a neutral/placeholder value for type
        chat.status = 0 // Assuming '0' is a neutral/placeholder value for status
        chat.createdAt = Date() // Sets to current date and time
        chat.muted = false // Assuming 'false' as a neutral value for muted
        chat.seen = false // Assuming 'false' as a neutral value for seen
        chat.unlisted = false // Assuming 'false' as a neutral value for unlisted
        chat.privateTribe = false // Assuming 'false' as a neutral value for privateTribe
        chat.notify = 0 // Assuming '0' as a neutral/placeholder value for notify
        chat.isTribeICreated = false // Assuming 'false' as a neutral value for isTribeICreated
        chat.contactIds = [NSNumber(integerLiteral: myUserId),NSNumber(integerLiteral: contact.id)] // Assuming an empty array as a neutral value
        chat.pendingContactIds = [] // Assuming an empty array as a neutral value
        
        // Set the ownerPubkey if it's considered mandatory
        chat.ownerPubkey = self.test_sender_pubkey // Use a test or neutral public key value
        chat.name = self.self_alias
        
        // Save the context
        self.sphinxOnionManager.managedContext.saveContext()
    }

    
    func fulfillExpectationAfterDelay(expectation: XCTestExpectation, delayInSeconds delay: TimeInterval) {
        // Dispatch after the specified delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Fulfill the expectation
            expectation.fulfill()
        }
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        UserData.sharedInstance.save(walletMnemonic: test_mnemonic2)
        sphinxOnionManager.isUnitTestMode = true
        enforceDelay(delay: 2.0)
        let success = sphinxOnionManager.createMyAccount(mnemonic: test_mnemonic2)
        XCTAssert(success == true)
        
        enforceDelay(delay: 8.0)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    //inspect incoming messages
    @objc func handleNewOnionMessageReceived(n:Notification){
        
        guard let message = n.userInfo?["message"] as? TransactionMessage else{
              return
          }
        
        receivedMessage = [
            "content": message.messageContent ?? "",
            "alias": message.senderAlias?.lowercased() ?? "",
            "uuid": message.uuid ?? "",
            "mediaKey": message.mediaKey ?? "",
            "mediaToken": message.mediaToken ?? "",
            "replyUuid": message.replyUUID ?? "",
            "amount": message.amount ?? 0,
            "type" : message.type,
            "invoice": message.invoice
        ]
    }
    
    //MARK: Test Helpers:
    func makeServerSendMessage(customMessage:String?=nil, replyUuid:String?=nil){
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewOnionMessageReceived), name: .newOnionMessageWasReceived, object: nil)
        
        guard let profile = UserContact.getOwner(),
              let pubkey = profile.publicKey else{
            XCTFail("Failed to establish self contact")
            return
        }
        let messageContent =  customMessage ?? test_received_message_content + "-\(sphinxOnionManager.getTimeWithEntropy())"
        //3. Send & Await results to come in
        let additionalParams = [replyUuid].compactMap({$0})
        sendRemoteServerMessageRequest(cmd: "send",pubkey: pubkey, theMsg: "\(messageContent)",additionalParams: additionalParams)
        enforceDelay(delay: 8.0)
    }
    
    func makeServerSendAttachment(mk:String,mt:String,customMessage:String?=nil){
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewOnionMessageReceived), name: .newOnionMessageWasReceived, object: nil)
        
        guard let profile = UserContact.getOwner(),
              let pubkey = profile.publicKey else{
            XCTFail("Failed to establish self contact")
            return
        }
        let messageContent =  customMessage ?? test_received_message_content + "-\(sphinxOnionManager.getTimeWithEntropy())"
        //3. Send & Await results to come in
        sendRemoteServerMessageRequest(cmd: "send_attachment",pubkey: pubkey, theMsg: "\(messageContent)",amount:0,additionalParams: [mk,mt])
        enforceDelay(delay: 8.0)
    }
    
    func makeServerSendBoost(replyUuid:String,amount:Int){
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewOnionMessageReceived), name: .newOnionMessageWasReceived, object: nil)
        
        guard let profile = UserContact.getOwner(),
              let pubkey = profile.publicKey else{
            XCTFail("Failed to establish self contact")
            return
        }

        //3. Send & Await results to come in
        sendRemoteServerMessageRequest(cmd: "boost",pubkey: pubkey, theMsg: "",amount:0,useAmount:false,useMsg:false,additionalParams: [replyUuid,String(describing: amount)])
        enforceDelay(delay: 10.0)
    }
    
    func makeServerSendDirectPayment(amount: Int, muid: String? = nil, content: String? = nil) {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewOnionMessageReceived), name: .newOnionMessageWasReceived, object: nil)
        
        guard let profile = UserContact.getOwner(),
              let pubkey = profile.publicKey else {
            XCTFail("Failed to establish self contact")
            return
        }

        // Convert amount from sats to msats
        let amountMsats = amount * 1000

        var additionalParams: [String] = []
        if let muid = muid {
            additionalParams.append(muid)
        }
        if let content = content {
            additionalParams.append(content)
        }

        // Send direct payment command
        sendRemoteServerMessageRequest(
            cmd: "send_direct_payment",
            pubkey: pubkey,
            theMsg: "",
            amount: amountMsats,
            useAmount: true,
            useMsg: false,
            additionalParams: additionalParams
        )

        enforceDelay(delay: 10.0)
    }
    
    func sendTestMessage(
        content:String,
        replyUuid:String?=nil,
        msgType:UInt8=0,
        muid:String?=nil,
        mediaKey:String?=nil,
        mediaType:String?=nil,
        invoiceString:String?=nil
        )->JSON?{
        guard let contact = UserContact.getContactWithDisregardStatus(pubkey: test_sender_pubkey),
            let chat = contact.getChat() else{
            XCTFail("Failed to establish self contact")
            return nil
        }
        var messageResult : JSON? = nil
        requestListenForIncomingMessage(completion: {result in
            messageResult = result
        })
        enforceDelay(delay: 8.0)
        
        sphinxOnionManager.sendMessage(to: contact, content: content, chat: chat, provisionalMessage: nil, amount: 0, shouldSendAsKeysend: false, msgType: msgType, muid: muid, mediaKey: mediaKey, mediaType: mediaType, threadUUID: nil, replyUUID: replyUuid,invoiceString: invoiceString, mnemonic: test_mnemonic2)
        
        enforceDelay( delay: 14.0)
        
        return messageResult
    }
    
    //END Helpers

    //MARK: Type 0 Messages:
    func test_receive_plaintext_message_3_1() throws {
        //0. Set up test client running on http://localhost:4020 from Sphinx repo
        //1. Listen to the correct channels -> handled in setup
        
        //2. Publish to a channel known to contain a message
        let test_content_value = test_received_message_content + "-\(sphinxOnionManager.getTimeWithEntropy())"
        makeServerSendMessage(customMessage: test_content_value)
        
        //4. Confirm that the known message content matches what we expect
        XCTAssertTrue(receivedMessage != nil)
        XCTAssertTrue(receivedMessage?["content"] as? String == test_content_value)
        XCTAssertTrue(receivedMessage?["alias"] as? String == "alice")
        //XCTAssert(receivedMessage?["senderPubkey"] as? String == test_sender_pubkey)
        
    }
    
    
    
    func test_send_plaintext_message_3_2() throws {
        let expectation = XCTestExpectation(description: "Expecting to have retrieved message in time")
        enforceDelay(delay: 8.0)
        //2. Send message with random content
        guard let rand = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100_000_000) else{
            XCTFail()
            return
        }
        let content = String(describing: rand)
        
        let messageResult = sendTestMessage(content: content)
        
        guard let resultDict = messageResult?.dictionaryValue,
              let dataDict = resultDict["data"]?.dictionaryValue,
                let msg = dataDict["msg"]?.rawString() else{
            XCTFail("Value coming back is invalid")
            return
        }
        for key in dataDict.keys{
            print("key:\(key), value:\(dataDict[key])")
        }
        
        let contentMatch = msg.contains(content)
        XCTAssert(contentMatch == true)
        
        print(messageResult)
        
        //let stringContent = String(content)
        
        //sphinxOnionManager.sendMessage(to: contact, content: stringContent)
        
        //3. Await ACK message
        
        //4. Ensure ACK message reflects same message we sent out.
    }
    
    //MARK: Type 6 Attachment Messages
    
    func test_receive_attachment_message_3_3() throws {
        let test_content_value = test_received_message_content + "-\(sphinxOnionManager.getTimeWithEntropy())"
        let testMediaKey = "Q0QxQjUyMkMzODM3NDE2NTg1NDgxQTBD"
        let testMediaToken = "bWVtZXMuc3BoaW54LmNoYXQ=.M_ZcxtcbRUZmDcHDYahSDvZJV4eOFvapZOb2wa-qNy0=..Z7X6KA==..ILxohNjxscIumj0f5NH1fySoR1HirySwMEHwVTGCAqzgPxXINtIyVO4agyf12hulTvCLDbKyOatmdotD9TBqLD4="
        makeServerSendAttachment(mk: testMediaKey, mt: testMediaToken, customMessage: test_content_value)
        
        XCTAssertTrue(receivedMessage?["content"] as? String == test_content_value)
        XCTAssertTrue(receivedMessage?["alias"] as? String == "alice")
        XCTAssertTrue(receivedMessage?["mediaKey"] as? String == testMediaKey)
        XCTAssertTrue(receivedMessage?["mediaToken"] as? String == testMediaToken)
        XCTAssert(receivedMessage != nil)
    }
    
    func test_send_attachment_message_3_4() throws {
        let expectation = XCTestExpectation(description: "Expecting to have retrieved message in time")
        enforceDelay(delay: 8.0)
        //2. Send message with random content
        guard let rand = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100_000_000) else{
            XCTFail()
            return
        }
        let content = String(describing: rand)
        
        let testMuid = "RnXZTEHHyVeAgvh6tGX_f8wjpAjSA-fLXHfp3YcPmhw="
        let testMediaKey = "5961753374583674655549543239554d6e73656a6b794f775955575236673050"
        let testMediaType = "image/jpg"
        let echoedMessage = sendTestMessage(content: content,msgType: UInt8(TransactionMessage.TransactionMessageType.attachment.rawValue),muid: testMuid, mediaKey: testMediaKey, mediaType: testMediaType)
                
        guard let resultDict = echoedMessage?.dictionaryValue,
              let dataDict = resultDict["data"]?.dictionaryValue,
              let msg = dataDict["msg"]?.dictionaryValue else {
            XCTFail("Value coming back is invalid")
            return
        }

        XCTAssertEqual(dataDict["msg_type"]?.stringValue, "attachment", "Incorrect message type")
        XCTAssertEqual(msg["content"]?.stringValue, content, "Incorrect content")
        XCTAssertEqual(msg["mediaKey"]?.stringValue, testMediaKey, "Incorrect media key")
        XCTAssertEqual(msg["mediaType"]?.stringValue, testMediaType, "Incorrect media type")
    }
    
    
    
    //MARK: Boost and replies related:
    func test_receive_reply_and_boost_3_5() throws {
        //1. Construct initial message
        guard let rand = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100_000_000) else{
            XCTFail()
            return
        }
        let content = String(describing: rand)
        let echoedMessage = sendTestMessage(content: content)
        guard let resultDict = echoedMessage?.dictionaryValue,
            let dataDict = resultDict["data"]?.dictionaryValue,
            let originalUuid = dataDict["uuid"]?.rawString() else{
            XCTFail("Value coming back is invalid")
            return
        }
        //2. Reply to initial message
        let test_content_value = test_received_message_content + "-\(sphinxOnionManager.getTimeWithEntropy())"
        makeServerSendMessage(customMessage: test_content_value,replyUuid: originalUuid)
        
        XCTAssertTrue(receivedMessage?["content"] as? String == test_content_value)
        XCTAssertTrue(receivedMessage?["replyUuid"] as? String == originalUuid)
        print(receivedMessage)
        receivedMessage = nil
        
        //3. Make server boost initial message: yarn auto boost MYPUBKEY MYMESSSAGEUUID RANDOMSATVALUE
        guard let rand_amount = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 1000) else{
            XCTFail()
            return
        }
        
        sphinxOnionManager.readyForPing = true
        makeServerSendBoost(replyUuid: originalUuid, amount: rand_amount * 1000)
        XCTAssertTrue(receivedMessage?["replyUuid"] as? String == originalUuid)
        XCTAssertTrue(receivedMessage?["amount"] as? Int == (rand_amount))
        XCTAssertTrue(receivedMessage?["type"] as? Int == TransactionMessage.TransactionMessageType.boost.rawValue)
        print(receivedMessage)
    }
    
    
    func test_send_reply_and_boost_3_6() throws {
        //Force message send
        makeServerSendMessage()
        guard let receivedMessage = receivedMessage,
        let rmUuid = receivedMessage["uuid"] as? String,
        let rand = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100_000_000) else{
            XCTFail()
            return
        }
        
        let content = String(describing: rand)
        
        //Reply to message with text, prove its receipt and fidelity
        let echoedMessage = sendTestMessage(content: content,replyUuid: rmUuid)
        
        guard let resultDict = echoedMessage?.dictionaryValue,
              let dataDict = resultDict["data"]?.dictionaryValue,
                let msg = dataDict["msg"]?.rawString() else{
            XCTFail("Value coming back is invalid")
            return
        }
        
        let contentMatch = msg.contains(content)
        XCTAssert(contentMatch == true)
        XCTAssert(msg.contains(rmUuid) == true)
        
        
        //Reply to message with boost, prove its receipt
        
        guard let contact = UserContact.getContactWithDisregardStatus(pubkey: test_sender_pubkey),
            let chat = contact.getChat() else{
            XCTFail("Failed to establish self contact")
            return 
        }
        
        let boost_amount_msats = 100000  // Changed from 1000 to 100000
        let params: [String: AnyObject] = [
            "message_price": 0 as AnyObject,
            "boost": 1 as AnyObject,
            "reply_uuid": rmUuid as AnyObject,
            "chat_id": chat.id as AnyObject,
            "text": "" as AnyObject,
            "amount": boost_amount_msats as AnyObject
        ]
        
        var messageResult : JSON? = nil
        requestListenForIncomingMessage(completion: {result in
            messageResult = result
        })
        
        enforceDelay(delay: 8.0)
        
        sphinxOnionManager.sendBoostReply(params: params, chat: chat, completion: {_ in},mnemonic: test_mnemonic2)
        
        enforceDelay( delay: 14.0)
        
        guard let resultDict = messageResult?.dictionaryValue,
              let dataDict = resultDict["data"]?.dictionaryValue,
                let msg = dataDict["msg"]?.rawString(),
              let msgType = dataDict["msg_type"]?.rawString(),
              let msats = dataDict["msat"]?.rawString() else{
            XCTFail("Value coming back is invalid")
            return
        }
        
        XCTAssert(msgType == "boost")
        let msatsString = String(boost_amount_msats)
        XCTAssert(msatsString == msats)
        
    }
    
    func test_receive_direct_payment_3_7() {
        guard let rand_dp_amount = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100) else{
            XCTFail()
            return
        }
        
        sphinxOnionManager.readyForPing = true
        makeServerSendDirectPayment(amount: rand_dp_amount)
        
        XCTAssertTrue(receivedMessage != nil)
        XCTAssertTrue(receivedMessage?["type"] as? Int == TransactionMessage.TransactionMessageType.directPayment.rawValue)
        XCTAssertTrue(receivedMessage?["amount"] as? Int == rand_dp_amount)
        // Add more assertions as needed
    }
    
    func test_send_direct_payment_3_8(){
        let testMuid = "YkZJhKWUYWcSRM5JmFhqwq7SJpeV_ayx1Feiu6oq3CE="
        guard let rand_dp_amount = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100) else{
            XCTFail()
            return
        }
        guard let contact = UserContact.getContactWithDisregardStatus(pubkey: test_sender_pubkey),
            let chat = contact.getChat() else{
            XCTFail("Failed to establish self contact")
            return
        }
        
        var messageResult : JSON? = nil
        requestListenForIncomingMessage(completion: {result in
            messageResult = result
        })
        
        enforceDelay(delay: 8.0)
        
        sphinxOnionManager.sendDirectPaymentMessage(amount: rand_dp_amount * 1000, muid: testMuid, content: nil, chat: chat,mnemonic:test_mnemonic2, completion: {success,_ in
            XCTAssertTrue(success)
        })
        
        enforceDelay(delay: 8.0)
        
        guard let resultDict = messageResult?.dictionaryValue,
              let dataDict = resultDict["data"]?.dictionaryValue,
              let msgType = dataDict["msg_type"]?.rawString(),
              let msats = dataDict["msat"]?.rawString() else{
            XCTFail("Value coming back is invalid")
            return
        }
        
        XCTAssert(msgType == "direct_payment")
        let msatsString = String(rand_dp_amount * 1000)
        XCTAssert(msatsString == msats)
        
    }
    
    func test_send_inline_invoice_3_9() {
        let expectation = XCTestExpectation(description: "Expecting to have sent and retrieved inline invoice message in time")
        enforceDelay(delay: 8.0)
        
        // Generate a random amount for the invoice
        guard let rand_amount = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 1000) else {
            XCTFail("Failed to generate random amount")
            return
        }
        let amount = rand_amount * 1000 // Convert to millisatoshis
        
        // Create a sample message with an inline invoice
        let content = "Here's an invoice for \(rand_amount) sats"
        
        // Generate a legitimate BOLT11 invoice using SphinxOnionManager
        guard let invoiceString = sphinxOnionManager.createInvoice(
            amountMsat: amount,
            description: content,
            mnemonic: test_mnemonic2
        ) else {
            XCTFail("Failed to create invoice")
            return
        }

        let echoedMessage = sendTestMessage(
            content: content,
            msgType: UInt8(TransactionMessage.TransactionMessageType.invoice.rawValue),
            invoiceString: invoiceString
        )
        
        guard let resultDict = echoedMessage?.dictionaryValue,
              let dataDict = resultDict["data"]?.dictionaryValue,
              let msg = dataDict["msg"]?.dictionaryValue else {
            XCTFail("Value coming back is invalid")
            return
        }

        // Verify the message content
        XCTAssertEqual(dataDict["msg_type"]?.stringValue, "invoice", "Incorrect message type")
        XCTAssertEqual(msg["content"]?.stringValue, content, "Incorrect content")
        
        // Verify the invoice
        XCTAssertEqual(msg["invoice"]?.stringValue, invoiceString, "Incorrect invoice string")
        
    }
    
    func test_receive_inline_invoice_3_10() {
        // Set up the test
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewOnionMessageReceived), name: .newOnionMessageWasReceived, object: nil)
        
        // Generate a random amount between 1000 and 100,000 millisats
        guard let randomAmount = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100) else {
            XCTFail("Failed to generate random amount")
            return
        }
        let amountMsats = randomAmount * 1000 // Ensure minimum of 1000 msats
        
        // Generate a random memo
        let randomMemo = "Invoice-\(UUID().uuidString.prefix(8))"
        
        // Prepare the command for the remote server
        guard let profile = UserContact.getOwner(),
              let pubkey = profile.publicKey else {
            XCTFail("Failed to get owner's public key")
            return
        }
        
        // Send the invoice message using the remote server
        let cmd = "send_invoice_msg"
        sendRemoteServerMessageRequest(cmd: cmd, pubkey: pubkey, theMsg: randomMemo, amount: amountMsats)
        
        // Wait for the message to be received
        enforceDelay(delay: 10.0)
        
        // Verify the received message
        XCTAssertNotNil(receivedMessage, "No message was received")
        
        guard let receivedMessage = receivedMessage else {
            XCTFail("Received message is nil")
            return
        }
        
        XCTAssertEqual(receivedMessage["type"] as? Int, TransactionMessage.TransactionMessageType.invoice.rawValue, "Incorrect message type")
        XCTAssertEqual(receivedMessage["content"] as? String, randomMemo, "Incorrect memo")
        XCTAssertEqual(receivedMessage["amount"] as! Int, amountMsats/1000)
    }
    
    func test_send_invoice_and_receive_payment_3_11() {
        // Set up the test
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewOnionMessageReceived), name: .newOnionMessageWasReceived, object: nil)
        
        // Generate a random amount between 1000 and 100,000 millisats
        guard let randomAmount = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100) else {
            XCTFail("Failed to generate random amount")
            return
        }
        let amountMsats = randomAmount * 1000 // Ensure minimum of 1000 msats
        
        // Generate a random memo
        let randomMemo = "Invoice-\(UUID().uuidString.prefix(8))"
        
        // Create an invoice using the Swift client
        guard let invoiceString = sphinxOnionManager.createInvoice(
            amountMsat: amountMsats,
            description: randomMemo,
            mnemonic: test_mnemonic2
        ) else {
            XCTFail("Failed to create invoice")
            return
        }
        
        // Send the invoice message
        let messageResult = sendTestMessage(
            content: randomMemo,
            msgType: UInt8(TransactionMessage.TransactionMessageType.invoice.rawValue),
            invoiceString: invoiceString
        )
        
        // Verify the sent invoice message
        XCTAssertNotNil(messageResult, "Failed to send invoice message")
        
        // Extract the UUID of the sent message
        guard let resultDict = messageResult?.dictionaryValue,
              let dataDict = resultDict["data"]?.dictionaryValue else {
            XCTFail("Failed to extract message UUID")
            return
        }
        
        // Trigger payment of the invoice using the remote server
        let payCmd = "pay_contact_invoice"
        sendRemoteServerMessageRequest(cmd: payCmd, pubkey: "", theMsg: invoiceString, amount: 0, useAmount: false, useMsg: true, additionalParams: [], omitPubkey: true)
        
        // Wait for the payment to be processed
        enforceDelay(delay: 10.0)
        
        // Verify the payment was successful
        XCTAssertNotNil(receivedMessage, "No payment confirmation message was received")
        
        guard let paymentConfirmation = receivedMessage else {
            XCTFail("Payment confirmation message is nil")
            return
        }
        
        XCTAssertEqual(paymentConfirmation["type"] as? Int, TransactionMessage.TransactionMessageType.payment.rawValue, "Incorrect payment message type")
        XCTAssertEqual(paymentConfirmation["amount"] as? Int, amountMsats/1000, "Incorrect payment amount")
    }
    
    func test_receive_invoice_and_send_payment_3_12() {
        // Set up the test
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewOnionMessageReceived), name: .newOnionMessageWasReceived, object: nil)
        
        // Generate a random amount between 1000 and 100,000 millisats
        guard let randomAmount = CrypterManager().generateCryptographicallySecureRandomInt(upperBound: 100) else {
            XCTFail("Failed to generate random amount")
            return
        }
        let amountMsats = randomAmount * 1000 // Ensure minimum of 1000 msats
        
        // Generate a random memo
        let randomMemo = "Invoice-\(UUID().uuidString.prefix(8))"
        
        // Prepare the command for the remote server
        guard let profile = UserContact.getOwner(),
              let pubkey = profile.publicKey else {
            XCTFail("Failed to get owner's public key")
            return
        }
        
        // Send the invoice message using the remote server
        let cmd = "send_invoice_msg"
        sendRemoteServerMessageRequest(cmd: cmd, pubkey: pubkey, theMsg: randomMemo, amount: amountMsats)
        
        // Wait for the message to be received
        enforceDelay(delay: 10.0)
        
        // Verify the received invoice message
        XCTAssertNotNil(receivedMessage, "No invoice message was received")
        
        guard let invoiceMessage = receivedMessage else {
            XCTFail("Received invoice message is nil")
            return
        }
        
        XCTAssertEqual(invoiceMessage["type"] as? Int, TransactionMessage.TransactionMessageType.invoice.rawValue, "Incorrect message type")
        XCTAssertEqual(invoiceMessage["content"] as? String, randomMemo, "Incorrect memo")
        XCTAssertEqual(invoiceMessage["amount"] as? Int, amountMsats/1000, "Incorrect amount")
        
        // Extract the invoice string from the received message
        guard let invoiceString = invoiceMessage["invoice"] as? String else {
            XCTFail("Failed to extract invoice string from received message")
            return
        }
        
        guard let uuid = invoiceMessage["uuid"] as? String,
              let invoiceMessageDb = TransactionMessage.getMessageWith(uuid: uuid) else{
            XCTFail()
            return
        }
    
        var messageResult : JSON? = nil
        requestListenForIncomingMessage(completion: {result in
            messageResult = result
        })
        enforceDelay(delay: 8.0)
        sphinxOnionManager.payInvoiceMessage(message: invoiceMessageDb,mnemonic:test_mnemonic2)
        
//    // Wait for the payment confirmation message
        enforceDelay(delay: 10.0)
        XCTAssertTrue(invoiceMessageDb.isPaid() == true)
    }
}
