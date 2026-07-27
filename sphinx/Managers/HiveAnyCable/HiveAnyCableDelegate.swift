//
//  HiveAnyCableDelegate.swift
//  sphinx
//
//  Created on 2026-03-06.
//  Copyright © 2026 sphinx. All rights reserved.
//

@MainActor protocol HiveAnyCableDelegate: AnyObject {
    func workflowStepTextReceived(stepText: String)
    func anyCableDidDisconnect()
}

extension HiveAnyCableDelegate {
    func anyCableDidDisconnect() {}
}
