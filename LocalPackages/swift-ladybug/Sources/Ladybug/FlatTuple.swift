//
//  swift-ladybug
//  https://github.com/LadybugDB/swift-ladybug
//
//  Copyright © 2023 - 2025 Kùzu Inc.
//  This code is licensed under MIT license (see LICENSE for details)

import Foundation
@_implementationOnly import cxx_ladybug

/// A class representing a row in the result set of a query.
/// FlatTuple provides access to the values in a query result row and methods to convert them to different formats.
/// It conforms to `CustomStringConvertible` protocol for easy string representation.
public final class FlatTuple: CustomStringConvertible, @unchecked Sendable {
    internal var cFlatTuple: lbug_flat_tuple
    internal var queryResult: QueryResult

    internal init(
        _ queryResult: QueryResult,
        _ cFlatTuple: lbug_flat_tuple
    ) {
        self.cFlatTuple = cFlatTuple
        self.queryResult = queryResult
    }

    deinit {
        lbug_flat_tuple_destroy(&cFlatTuple)
    }

    /// Returns the string representation of the FlatTuple.
    /// The string representation contains the values of the tuple separated by vertical bars.
    public var description: String {
        let cString: UnsafeMutablePointer<CChar> = lbug_flat_tuple_to_string(
            &cFlatTuple
        )
        defer { lbug_destroy_string(cString) }
        return String(cString: cString)
    }

    /// Returns the value at the given index in the FlatTuple.
    /// - Parameter index: The index of the value to retrieve.
    /// - Returns: The value at the specified index, or nil if the value is null.
    /// - Throws: `LadybugError.getValueFailed` if retrieving the value fails.
    public func getValue(_ index: UInt64) throws -> Any? {
        var cValue = lbug_value()
        let state = lbug_flat_tuple_get_value(&cFlatTuple, index, &cValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Get value failed with error code: \(state)"
            )
        }
        defer { lbug_value_destroy(&cValue) }
        return try ladybugValueToSwift(&cValue)
    }

    /// Returns the values of the FlatTuple as a dictionary.
    /// The keys of the dictionary are the column names in the query result.
    /// - Returns: A dictionary mapping column names to their corresponding values.
    /// - Throws: `LadybugError.getValueFailed` if retrieving any value fails.
    public func getAsDictionary() throws -> [String: Any?] {
        var result: [String: Any] = [:]
        let keys = queryResult.getColumnNames()
        for i in 0..<keys.count {
            let key = keys[i]
            let value = try getValue(UInt64(i))
            result[key] = value
        }
        return result
    }

    /// Returns the values of the FlatTuple as an array.
    /// The order of the values in the array is the same as the order of the columns in the query result.
    /// - Returns: An array containing all values in the tuple.
    /// - Throws: `LadybugError.getValueFailed` if retrieving any value fails.
    public func getAsArray() throws -> [Any?] {
        var result: [Any?] = []
        let count = queryResult.getColumnCount()
        for i in UInt64(0)..<count {
            let value = try getValue(i)
            result.append(value)
        }
        return result
    }
}
