//
//  swift-ladybug
//  https://github.com/LadybugDB/swift-ladybug
//
//  Copyright © 2023 - 2025 Kùzu Inc.
//  This code is licensed under MIT license (see LICENSE for details)

/// Errors that can occur during Ladybug operations.
public enum LadybugError: Error {
    /// Database initialization failed with the given error message.
    case databaseInitializationFailed(String)
    /// Connection initialization failed with the given error message.
    case connectionInitializationFailed(String)
    /// Query execution failed with the given error message.
    case queryExecutionFailed(String)
    /// Statement preparation failed with the given error message.
    case prepareStatmentFailed(String)
    /// Value conversion failed with the given error message.
    case valueConversionFailed(String)
    /// Failed to get a flat tuple with the given error message.
    case getFlatTupleFailed(String)
    /// Failed to get the next query result with the given error message.
    case getNextQueryResultFailed(String)
    /// Failed to get a value with the given error message.
    case getValueFailed(String)
    /// The error message.
    /// - Returns: The error message.
    public var message: String {
        switch self {
        case .databaseInitializationFailed(let msg),
            .connectionInitializationFailed(let msg),
            .queryExecutionFailed(let msg),
            .prepareStatmentFailed(let msg),
            .valueConversionFailed(let msg),
            .getFlatTupleFailed(let msg),
            .getNextQueryResultFailed(let msg),
            .getValueFailed(let msg):
            return msg
        }
    }
}

/// Represents the internal ID of a node or relationship in Ladybug.
/// It conforms to the Equatable protocol for easy comparison.
public struct LadybugInternalId: Equatable {
    /// The table ID of the node or relationship.
    public let tableId: UInt64
    /// The offset within the table.
    public let offset: UInt64

    /// Compares two LadybugInternalId instances for equality.
    /// - Parameters:
    ///   - lhs: The first LadybugInternalId to compare.
    ///   - rhs: The second LadybugInternalId to compare.
    /// - Returns: True if the two LadybugInternalId instances are equal, false otherwise.
    public static func == (lhs: LadybugInternalId, rhs: LadybugInternalId) -> Bool {
        return lhs.tableId == rhs.tableId && lhs.offset == rhs.offset
    }
}

/// Represents a node retrieved from Ladybug.
/// A node has an ID, a label, and properties.
public struct LadybugNode {
    /// The internal ID of the node.
    public let id: LadybugInternalId
    /// The label of the node.
    public let label: String
    /// The properties of the node, where keys are property names and values are property values.
    public let properties: [String: Any?]
}

/// Represents a relationship retrieved from Ladybug.
/// A relationship has a source ID, a destination ID, a label, and properties.
public struct LadybugRelationship {
    /// The internal ID of the relationship
    public let id: LadybugInternalId
    /// The internal ID of the source node.
    public let sourceId: LadybugInternalId
    /// The internal ID of the target node.
    public let targetId: LadybugInternalId
    /// The label of the relationship.
    public let label: String
    /// The properties of the relationship, where keys are property names and values are property values.
    public let properties: [String: Any?]
}

/// Represents a recursive relationship retrieved from a path query in Ladybug.
/// A recursive relationship has a list of nodes and a list of relationships.
public struct LadybugRecursiveRelationship {
    /// The list of nodes in the recursive relationship.
    public let nodes: [LadybugNode]
    /// The list of relationships in the recursive relationship.
    public let relationships: [LadybugRelationship]
}

/// A wrapper for UInt32 values to be passed as parameters to Ladybug.
/// The native Swift type UInt32 cannot be distinguished from Int64 because
/// the underlying NSNumber type is the same for both types (type 'q').
public struct LadybugUInt32Wrapper: Codable {
    public var value: UInt32

    public init(value: UInt32) {
        self.value = value
    }
}

/// A wrapper for UInt16 values to be passed as parameters to Ladybug.
/// The native Swift type UInt16 cannot be distinguished from Int32 because
/// the underlying NSNumber type is the same for both types (type 'i').
public struct LadybugUInt16Wrapper: Codable {
    public var value: UInt16

    public init(value: UInt16) {
        self.value = value
    }
}

/// A wrapper for UInt8 values to be passed as parameters to Ladybug.
/// The native Swift type UInt8 cannot be distinguished from Int16 because
/// the underlying NSNumber type is the same for both types (type 's').
public struct LadybugUInt8Wrapper: Codable {
    public var value: UInt8

    public init(value: UInt8) {
        self.value = value
    }
}

/// A wrapper for UInt64 values to be passed as parameters to Ladybug.
/// Using this wrapper is optional on macOS/iOS, because CoreFoundation
/// framework can automatically detect the type of the underlying NSNumber.
/// However, it is required on Linux, because CoreFoundation is not available.
public struct LadybugUInt64Wrapper: Codable {
    public var value: UInt64

    public init(value: UInt64) {
        self.value = value
    }
}

/// A wrapper for Int64 values to be passed as parameters to Ladybug.
/// Using this wrapper is optional on macOS/iOS, because CoreFoundation
/// framework can automatically detect the type of the underlying NSNumber.
/// However, it is required on Linux, because CoreFoundation is not available.
public struct LadybugInt64Wrapper: Codable {
    public var value: Int64

    public init(value: Int64) {
        self.value = value
    }
}

/// A wrapper for Int32 values to be passed as parameters to Ladybug.
/// Using this wrapper is optional on macOS/iOS, because CoreFoundation
/// framework can automatically detect the type of the underlying NSNumber.
/// However, it is required on Linux, because CoreFoundation is not available.
public struct LadybugInt32Wrapper: Codable {
    public var value: Int32

    public init(value: Int32) {
        self.value = value
    }
}

/// A wrapper for Int16 values to be passed as parameters to Ladybug.
/// Using this wrapper is optional on macOS/iOS, because CoreFoundation
/// framework can automatically detect the type of the underlying NSNumber.
/// However, it is required on Linux, because CoreFoundation is not available.
public struct LadybugInt16Wrapper: Codable {
    public var value: Int16

    public init(value: Int16) {
        self.value = value
    }
}

/// A wrapper for Int8 values to be passed as parameters to Ladybug.
/// Using this wrapper is optional on macOS/iOS, because CoreFoundation
/// framework can automatically detect the type of the underlying NSNumber.
/// However, it is required on Linux, because CoreFoundation is not available.
public struct LadybugInt8Wrapper: Codable {
    public var value: Int8

    public init(value: Int8) {
        self.value = value
    }
}

/// A wrapper for Float values to be passed as parameters to Ladybug.
/// Using this wrapper is optional on macOS/iOS, because CoreFoundation
/// framework can automatically detect the type of the underlying NSNumber.
/// However, it is required on Linux, because CoreFoundation is not available.
public struct LadybugFloatWrapper: Codable {
    public var value: Float

    public init(value: Float) {
        self.value = value
    }
}

/// A wrapper for Double values to be passed as parameters to Ladybug.
/// Using this wrapper is optional on macOS/iOS, because CoreFoundation
/// framework can automatically detect the type of the underlying NSNumber.
/// However, it is required on Linux, because CoreFoundation is not available.
public struct LadybugDoubleWrapper: Codable {
    public var value: Double

    public init(value: Double) {
        self.value = value
    }
}

/// A wrapper for Bool values to be passed as parameters to Ladybug.
/// Using this wrapper is optional on macOS/iOS, because CoreFoundation
/// framework can automatically detect the type of the underlying NSNumber.
/// However, it is required on Linux, because CoreFoundation is not available.
public struct LadybugBoolWrapper: Codable {
    public var value: Bool

    public init(value: Bool) {
        self.value = value
    }
}
