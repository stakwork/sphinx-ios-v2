//
//  swift-ladybug
//  https://github.com/LadybugDB/swift-ladybug
//
//  Copyright © 2023 - 2025 Kùzu Inc.
//  This code is licensed under MIT license (see LICENSE for details)

@_implementationOnly import cxx_ladybug

/// A class representing a prepared statement in Ladybug.
/// PreparedStatement can be used to execute a query with parameters.
/// It is returned by the `prepare` method of Connection.
public final class PreparedStatement: @unchecked Sendable {
    internal var cPreparedStatement: lbug_prepared_statement
    internal var connection: Connection

    /// Initializes a new PreparedStatement instance.
    /// - Parameters:
    ///   - connection: The connection associated with this prepared statement.
    ///   - cPreparedStatement: The underlying C prepared statement.
    internal init(
        _ connection: Connection,
        _ cPreparedStatement: lbug_prepared_statement
    ) {
        self.cPreparedStatement = cPreparedStatement
        self.connection = connection
    }

    deinit {
        lbug_prepared_statement_destroy(&cPreparedStatement)
    }
}
