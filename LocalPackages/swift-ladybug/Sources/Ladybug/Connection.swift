//
//  swift-ladybug
//  https://github.com/LadybugDB/swift-ladybug
//
//  Copyright © 2023 - 2025 Kùzu Inc.
//  This code is licensed under MIT license (see LICENSE for details)

@_implementationOnly import cxx_ladybug

/// Represents a connection to a Ladybug database.
public final class Connection: @unchecked Sendable {
    internal var cConnection: lbug_connection
    internal var database: Database

    /// Opens a connection to the specified database.
    /// - Parameter database: The database to connect to
    /// - Throws: LadybugError if connection initialization fails
    public init(_ database: Database) throws {
        cConnection = lbug_connection()
        let state = lbug_connection_init(&database.cDatabase, &self.cConnection)
        if state != LbugSuccess {
            throw LadybugError.connectionInitializationFailed(
                "Connection initialization failed with error code: \(state)"
            )
        }
        self.database = database
    }

    deinit {
        lbug_connection_destroy(&cConnection)
    }

    /// Executes a query string and returns the result.
    /// - Parameter cypher: The Cypher query string to execute
    /// - Returns: A QueryResult containing the results of the query
    /// - Throws: LadybugError if query execution fails
    public func query(_ cypher: String) throws -> QueryResult {
        var cQueryResult = lbug_query_result()
        lbug_connection_query(&cConnection, cypher, &cQueryResult)
        if !lbug_query_result_is_success(&cQueryResult) {
            let cErrorMesage: UnsafeMutablePointer<CChar>? =
                lbug_query_result_get_error_message(&cQueryResult)
            defer {
                lbug_query_result_destroy(&cQueryResult)
                lbug_destroy_string(cErrorMesage)
            }
            if cErrorMesage == nil {
                throw LadybugError.queryExecutionFailed(
                    "Query execution failed with an unknown error."
                )
            } else {
                let errorMessage = String(cString: cErrorMesage!)
                throw LadybugError.queryExecutionFailed(errorMessage)
            }
        }
        let queryResult = QueryResult(self, cQueryResult)
        return queryResult
    }

    /// Returns a prepared statement for the specified query string.
    /// The prepared statement can be used to execute the query with parameters.
    /// - Parameter cypher: The Cypher query string to prepare
    /// - Returns: A PreparedStatement that can be used to execute the query with parameters
    /// - Throws: LadybugError if statement preparation fails
    public func prepare(_ cypher: String) throws -> PreparedStatement {
        var cPreparedStatement = lbug_prepared_statement()
        lbug_connection_prepare(&cConnection, cypher, &cPreparedStatement)
        if !lbug_prepared_statement_is_success(&cPreparedStatement) {
            let cErrorMesage: UnsafeMutablePointer<CChar>? =
                lbug_prepared_statement_get_error_message(&cPreparedStatement)
            defer {
                lbug_destroy_string(cErrorMesage)
                lbug_prepared_statement_destroy(&cPreparedStatement)
            }
            if cErrorMesage == nil {
                throw LadybugError.prepareStatmentFailed(
                    "Prepare statement failed with an unknown error."
                )
            } else {
                let errorMessage = String(cString: cErrorMesage!)
                throw LadybugError.prepareStatmentFailed(errorMessage)
            }
        }
        let preparedStatement = PreparedStatement(self, cPreparedStatement)
        return preparedStatement
    }

    /// Executes the specified prepared statement with the given parameters and returns the result.
    /// - Parameters:
    ///   - preparedStatement: The prepared statement to execute
    ///   - parameters: A dictionary mapping parameter names to their values
    /// - Returns: A QueryResult containing the results of the query
    /// - Throws: LadybugError if query execution fails
    public func execute<T>(
        _ preparedStatement: PreparedStatement,
        _ parameters: [String: T?]
    ) throws -> QueryResult {
        var cQueryResult = lbug_query_result()
        for (key, value) in parameters {
            let cValue = try swiftValueToLadybugValue(value)
            defer {
                lbug_value_destroy(cValue)
            }
            let state = lbug_prepared_statement_bind_value(
                &preparedStatement.cPreparedStatement,
                key,
                cValue
            )
            if state != LbugSuccess {
                throw LadybugError.queryExecutionFailed(
                    "Failed to bind value with status \(state)"
                )
            }
        }
        lbug_connection_execute(
            &cConnection,
            &preparedStatement.cPreparedStatement,
            &cQueryResult
        )
        if !lbug_query_result_is_success(&cQueryResult) {
            let cErrorMesage: UnsafeMutablePointer<CChar>? =
                lbug_query_result_get_error_message(&cQueryResult)
            defer {
                lbug_query_result_destroy(&cQueryResult)
                lbug_destroy_string(cErrorMesage)
            }
            if cErrorMesage == nil {
                throw LadybugError.queryExecutionFailed(
                    "Query execution failed with an unknown error."
                )
            } else {
                let errorMessage = String(cString: cErrorMesage!)
                throw LadybugError.queryExecutionFailed(errorMessage)
            }
        }
        let queryResult = QueryResult(self, cQueryResult)
        return queryResult
    }

    /// Sets the maximum number of threads that can be used for executing a query in parallel.
    /// - Parameter numThreads: The maximum number of threads to use
    public func setMaxNumThreadForExec(_ numThreads: UInt64) {
        lbug_connection_set_max_num_thread_for_exec(&cConnection, numThreads)
    }

    /// Returns the maximum number of threads that can be used for executing a query in parallel.
    /// - Returns: The maximum number of threads
    public func getMaxNumThreadForExec() -> UInt64 {
        var numThreads = UInt64()
        lbug_connection_get_max_num_thread_for_exec(&cConnection, &numThreads)
        return numThreads
    }

    /// Sets the timeout for the queries executed on the connection.
    /// The timeout is specified in milliseconds. A value of 0 means no timeout.
    /// If a query takes longer than the specified timeout, it will be interrupted.
    /// - Parameter milliseconds: The timeout duration in milliseconds
    public func setQueryTimeout(_ milliseconds: UInt64) {
        lbug_connection_set_query_timeout(&cConnection, milliseconds)
    }

    /// Interrupts the execution of the current query on the connection.
    public func interrupt() {
        lbug_connection_interrupt(&cConnection)
    }
}
