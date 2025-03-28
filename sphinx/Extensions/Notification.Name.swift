//
//  Notification.Name.swift
//  sphinx
//
//  Created by Tomas Timinskas on 08/04/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let onKeyboardShown = Notification.Name("onKeyboardShown")
    static let onMessageLongPressed = Notification.Name("onMessageLongPressed")
    static let onBalanceDidChange = Notification.Name("onBalanceDidChange")
    static let onGroupDeleted = Notification.Name("onGroupDeleted")
    static let onMessageMenuShow = Notification.Name("onMessageMenuShow")
    static let onMessageMenuHide = Notification.Name("onMessageMenuHide")
    static let onConnectionStatusChanged = Notification.Name("onConnectionStatusChanged")
    static let onMQTTConnectionStatusChanged = Notification.Name("onMQTTConnectionStatusChanged")
    static let autocompleteMention = Notification.Name("autocompleteMention")
    static let refreshFeedUI = Notification.Name(rawValue: "refreshFeedUI")
    static let refreshFeedDataAndUI = Notification.Name(rawValue: "refreshFeedDataAndUI")
    static let onContactsAndChatsChanged = Notification.Name("onContactsAndChatsChanged")
    static let onMessagesStatusChanged = Notification.Name("onMessagesStatusChanged")
    static let onSizeConfigurationChanged = Notification.Name("onSizeConfigurationChanged")
    static let webViewImageClicked = Notification.Name("webViewImageClicked")
    static let keyExchangeResponseMessageWasConstructed = Notification.Name("keyExchangeMessageWasConstructed")
    static let newContactWasRegisteredWithServer = Notification.Name("newContactWasRegisteredWithServer")
    static let newContactKeyExchangeResponseWasReceived = Notification.Name("newContactKeyExchangeResponseWasReceived")
    static let newOnionMessageWasReceived = Notification.Name("newOnionMessageWasReceived")
    static let newTribeMemberListRetrieved = Notification.Name("newTribeMemberListRetrieved")
    static let invoiceIPaidSettled = Notification.Name("invoiceIPaidSettled")
    static let sentInvoiceSettled = Notification.Name("sentInvoiceSettled")
    static let connectedToInternet = Notification.Name("connectedToInternet")
    static let disconnectedFromInternet = Notification.Name("disconnectedFromInternet")
    static let onKeysendStatusReceived = Notification.Name("onKeysendStatusReceived")
}
