//
//  swift-ladybug
//  https://github.com/LadybugDB/swift-ladybug
//
//  Copyright © 2023 - 2025 Kùzu Inc.
//  This code is licensed under MIT license (see LICENSE for details)

import Foundation
@_implementationOnly import cxx_ladybug

/// A class representing a Ladybug database instance.
public final class Database: @unchecked Sendable {
    internal var cDatabase: lbug_database

    /// Initializes a new Ladybug database instance.
    /// - Parameters:
    ///   - databasePath: The path to the database. Defaults to ":memory:" for in-memory database.
    ///   - systemConfig: Optional configuration for the database system. If nil, default configuration will be used.
    /// - Throws: `LadybugError.databaseInitializationFailed` if the database initialization fails.
    public init(
        _ databasePath: String = ":memory:",
        _ systemConfig: SystemConfig? = nil
    ) throws {
        cDatabase = lbug_database()
        let cSystemConfg =
            systemConfig?.cSystemConfig ?? lbug_default_system_config()
        let state = lbug_database_init(
            databasePath,
            cSystemConfg,
            &self.cDatabase
        )
        if state == LbugSuccess {
            return
        } else {
            let cErrorMessage = lbug_get_last_error()
            defer { lbug_destroy_string(cErrorMessage) }
            if let cErrorMessage {
                let errorMessage = String(cString: cErrorMessage)
                throw LadybugError.databaseInitializationFailed(errorMessage)
            }
            throw LadybugError.databaseInitializationFailed(
                "Database initialization failed with error code: \(state)"
            )
        }
    }

    /// The version of the Ladybug library as a string.
    ///
    /// This property returns the version of the underlying Ladybug library.
    /// Useful for debugging and ensuring compatibility.
    public static var version: String {
        let resultCString = lbug_get_version()
        defer { lbug_destroy_string(resultCString) }
        return String(cString: resultCString!)
    }

    /// The storage version of the Ladybug library as an unsigned 64-bit integer.
    ///
    /// This property returns the storage format version used by the Ladybug library.
    /// It can be used to check compatibility of database files.
    public static var storageVersion: UInt64 {
        let storageVersion = lbug_get_storage_version()
        return storageVersion
    }

    deinit {
        lbug_database_destroy(&self.cDatabase)
    }
}
