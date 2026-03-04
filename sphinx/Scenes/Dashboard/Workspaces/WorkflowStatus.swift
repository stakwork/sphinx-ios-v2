//
//  WorkflowStatus.swift
//  sphinx
//
//  Created on 2025-03-04.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation

enum WorkflowStatus: String {
    case PENDING    = "PENDING"
    case IN_PROGRESS = "IN_PROGRESS"
    case COMPLETED  = "COMPLETED"
    case ERROR      = "ERROR"
    case HALTED     = "HALTED"
    case FAILED     = "FAILED"
}
