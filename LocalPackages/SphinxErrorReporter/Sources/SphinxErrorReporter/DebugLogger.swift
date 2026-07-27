// DebugLogger.swift
// SphinxErrorReporter
//
// Opt-in lifecycle logger. Enabled only when Config.debug == true.
// Never logs payload contents or keys.

import Foundation

enum DebugLogger {
    static var isEnabled: Bool = false

    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[SphinxErrorReporter] \(message())")
    }
}
