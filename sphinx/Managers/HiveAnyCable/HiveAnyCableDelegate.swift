//
//  HiveAnyCableDelegate.swift
//  sphinx
//
//  Created on 2026-03-06.
//  Copyright © 2026 sphinx. All rights reserved.
//

protocol HiveAnyCableDelegate: AnyObject {
    func workflowStepUpdateReceived(projectId: Int)
}
