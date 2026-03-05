//
//  TaskProgress.swift
//  sphinx
//
//  Created on 2025-03-05.
//  Copyright © 2025 sphinx. All rights reserved.
//

import CoreGraphics

struct TaskProgress {
    let total: Int
    let doneCount: Int
    let inProgressCount: Int
    let todoCount: Int
    let cancelledCount: Int

    var activeTotal: Int { total - cancelledCount }
    var completePercent: Int {
        guard activeTotal > 0 else { return 0 }
        return Int(round(Double(doneCount) / Double(activeTotal) * 100))
    }
    var doneSegmentWidth: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(doneCount) / CGFloat(total)
    }
    var inProgressSegmentWidth: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(inProgressCount) / CGFloat(total)
    }

    init(tasks: [WorkspaceTask]) {
        total = tasks.count
        doneCount = tasks.filter { $0.status == "DONE" }.count
        inProgressCount = tasks.filter { $0.status == "IN_PROGRESS" }.count
        todoCount = tasks.filter { $0.status == "TODO" }.count
        cancelledCount = tasks.filter { $0.status == "CANCELLED" }.count
    }
}
