//
//  WebAppSessionManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 03/06/2026.
//  Copyright © 2026 Sphinx. All rights reserved.
//

import Foundation

struct WebAppSessionKey: Hashable {
    let chatId: Int
    let isAppURL: Bool
}

struct WebAppSessionEntry {
    let vc: WebAppViewController
}

class WebAppSessionManager {
    static let sharedInstance = WebAppSessionManager()
    private init() {}

    private var sessions: [WebAppSessionKey: WebAppSessionEntry] = [:]

    func store(_ vc: WebAppViewController, chatId: Int, isAppURL: Bool) {
        sessions[WebAppSessionKey(chatId: chatId, isAppURL: isAppURL)] = WebAppSessionEntry(vc: vc)
    }

    func retrieve(chatId: Int, isAppURL: Bool) -> WebAppViewController? {
        return sessions[WebAppSessionKey(chatId: chatId, isAppURL: isAppURL)]?.vc
    }

    func evict(chatId: Int, isAppURL: Bool) {
        let key = WebAppSessionKey(chatId: chatId, isAppURL: isAppURL)
        sessions[key]?.vc.teardown()
        sessions.removeValue(forKey: key)
    }

    func evictAll() {
        sessions.values.forEach { $0.vc.teardown() }
        sessions.removeAll()
    }
}
