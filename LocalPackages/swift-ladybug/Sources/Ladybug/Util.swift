//
//  swift-ladybug
//  https://github.com/LadybugDB/swift-ladybug
//
//  Copyright © 2023 - 2025 Kùzu Inc.
//  This code is licensed under MIT license (see LICENSE for details)

import Foundation
@_implementationOnly import cxx_ladybug

/// Constants for time unit conversions
private let MILLISECONDS_IN_A_SECOND: Double = 1_000
private let MICROSECONDS_IN_A_MILLISECOND: Double = 1_000
private let MICROSECONDS_IN_A_SECOND: Double =
    MILLISECONDS_IN_A_SECOND * MICROSECONDS_IN_A_MILLISECOND
private let NANOSECONDS_IN_A_MICROSECOND: Double = 1_000
private let NANOSECONDS_IN_A_SECOND: Double =
    MICROSECONDS_IN_A_SECOND * NANOSECONDS_IN_A_MICROSECOND
private let SECONDS_IN_A_MINUTE: Double = 60
private let MINUTES_IN_AN_HOUR: Double = 60
private let HOURS_IN_A_DAY: Double = 24
private let DAYS_IN_A_MONTH: Double = 30
private let SECONDS_IN_A_DAY =
    HOURS_IN_A_DAY * MINUTES_IN_AN_HOUR * SECONDS_IN_A_MINUTE
private let SECONDS_IN_A_MONTH = DAYS_IN_A_MONTH * SECONDS_IN_A_DAY

/// Converts a Swift Date to a Ladybug timestamp.
/// - Parameter date: The Swift Date to convert.
/// - Returns: A Ladybug timestamp representing the same time.
private func swiftDateToLadybugTimestamp(_ date: Date) -> lbug_timestamp_t {
    let timeInterval = date.timeIntervalSince1970
    let microseconds = timeInterval * MICROSECONDS_IN_A_SECOND
    return lbug_timestamp_t(value: Int64(microseconds))
}

/// Converts a Swift TimeInterval to a Ladybug interval.
/// - Parameter timeInterval: The Swift TimeInterval to convert.
/// - Returns: A Ladybug interval representing the same duration.
private func swiftTimeIntervalToLadybugInterval(_ timeInterval: TimeInterval)
    -> lbug_interval_t
{
    let microseconds = timeInterval * MICROSECONDS_IN_A_SECOND
    return lbug_interval_t(months: 0, days: 0, micros: Int64(microseconds))
}

/// Converts a Ladybug interval to a Swift TimeInterval.
/// - Parameter interval: The Ladybug interval to convert.
/// - Returns: A Swift TimeInterval representing the same duration.
private func ladybugIntervalToSwiftTimeInterval(_ interval: lbug_interval_t)
    -> TimeInterval
{
    var seconds = Double(interval.micros) / MICROSECONDS_IN_A_SECOND
    seconds += Double(interval.days) * SECONDS_IN_A_DAY
    seconds += Double(interval.months) * SECONDS_IN_A_MONTH
    return seconds
}

/// Converts a Swift array of key-value pairs to a Ladybug map value.
/// - Parameter array: An array of tuples containing key-value pairs.
/// - Returns: A Ladybug map value.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func swiftArrayOfMapItemsToLadybugMap(_ array: [(Any?, Any?)]) throws
    -> UnsafeMutablePointer<lbug_value>
{
    let numItems = array.count
    if numItems == 0 {
        throw LadybugError.valueConversionFailed(
            "Cannot convert empty array to Ladybug MAP"
        )
    }
    let keys: UnsafeMutablePointer<UnsafeMutablePointer<lbug_value>?> =
        .allocate(capacity: numItems)
    let values: UnsafeMutablePointer<UnsafeMutablePointer<lbug_value>?> =
        .allocate(capacity: numItems)
    for idx in 0..<numItems {
        keys[idx] = nil
        values[idx] = nil
    }
    defer {
        for idx in 0..<numItems {
            lbug_value_destroy(keys[idx])
            lbug_value_destroy(values[idx])
        }
        keys.deallocate()
        values.deallocate()
    }
    for (idx, (key, value)) in array.enumerated() {
        let key = try swiftValueToLadybugValue(key)
        let value = try swiftValueToLadybugValue(value)
        keys[idx] = key
        values[idx] = value
    }
    var valuePtr: UnsafeMutablePointer<lbug_value>?
    let state = lbug_value_create_map(UInt64(numItems), keys, values, &valuePtr)
    if state != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to create MAP value with status: \(state). Please make sure all the keys are of the same type and all the values are of the same type."
        )
    }
    return valuePtr!
}

/// Converts a Ladybug map value to a Swift array of key-value pairs.
/// - Parameter cValue: The Ladybug map value to convert.
/// - Returns: An array of tuples containing key-value pairs.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func ladybugMapToSwiftArrayOfMapItems(_ cValue: inout lbug_value) throws
    -> [(Any?, Any?)]
{
    var mapSize: UInt64 = 0
    let state = lbug_value_get_map_size(&cValue, &mapSize)
    if state != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get map size with status: \(state)"
        )
    }
    var result: [(Any?, Any?)] = []
    var currentKey = lbug_value()
    var currentValue = lbug_value()
    for i in UInt64(0)..<mapSize {
        let keyState = lbug_value_get_map_key(&cValue, i, &currentKey)
        if keyState != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get map key with status: \(keyState)"
            )
        }
        defer { lbug_value_destroy(&currentKey) }
        let valueState = lbug_value_get_map_value(&cValue, i, &currentValue)
        if valueState != LbugSuccess {
            lbug_value_destroy(&currentKey)
            throw LadybugError.valueConversionFailed(
                "Failed to get map value with status: \(valueState)"
            )
        }
        defer { lbug_value_destroy(&currentValue) }
        let key = try ladybugValueToSwift(&currentKey)
        let value = try ladybugValueToSwift(&currentValue)
        result.append((key, value))
    }

    return result
}

/// Converts a Swift array to a Ladybug list value.
/// - Parameter array: The Swift array to convert.
/// - Returns: A Ladybug list value.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func swiftArrayToLadybugList(_ array: NSArray)
    throws -> UnsafeMutablePointer<lbug_value>
{
    let numberOfElements = array.count
    if numberOfElements == 0 {
        throw LadybugError.valueConversionFailed(
            "Cannot convert empty array to Ladybug list"
        )
    }
    let cElementArray: UnsafeMutablePointer<UnsafeMutablePointer<lbug_value>?> =
        .allocate(capacity: numberOfElements)
    for idx in 0..<numberOfElements {
        cElementArray[idx] = nil
    }
    defer {
        for idx in 0..<numberOfElements {
            lbug_value_destroy(cElementArray[idx])
        }
        cElementArray.deallocate()
    }
    for (idx, element) in array.enumerated() {
        let cElement = try swiftValueToLadybugValue(element)
        cElementArray[idx] = cElement
    }
    var cLadybugListValue: UnsafeMutablePointer<lbug_value>?
    let state = lbug_value_create_list(
        UInt64(numberOfElements),
        cElementArray,
        &cLadybugListValue
    )
    if state != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to create LIST value with status: \(state). Please make sure all the values are of the same type."
        )
    }
    return cLadybugListValue!
}

/// Converts a Ladybug list value to a Swift array.
/// - Parameter cValue: The Ladybug list value to convert.
/// - Returns: A Swift array containing the list elements.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func ladybugListToSwiftArray(_ cValue: inout lbug_value) throws -> [Any?] {
    var numElements: UInt64 = 0
    var logicalType = lbug_logical_type()
    lbug_value_get_data_type(&cValue, &logicalType)

    defer { lbug_data_type_destroy(&logicalType) }
    let logicalTypeId = lbug_data_type_get_id(&logicalType)
    if logicalTypeId == LBUG_ARRAY {
        let state = lbug_data_type_get_num_elements_in_array(
            &logicalType,
            &numElements
        )
        if state != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get number of elements in array with status: \(state)"
            )
        }
    } else {
        let state = lbug_value_get_list_size(&cValue, &numElements)
        if state != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get number of elements in list with status: \(state)"
            )
        }
    }
    var result: [Any?] = []
    var currentValue = lbug_value()
    for i in UInt64(0)..<numElements {
        let state = lbug_value_get_list_element(&cValue, i, &currentValue)
        if state != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get list element with status: \(state)"
            )
        }
        defer { lbug_value_destroy(&currentValue) }
        let swiftValue = try ladybugValueToSwift(&currentValue)
        result.append(swiftValue)
    }
    return result
}

/// Converts a Swift dictionary to a Ladybug struct value.
/// - Parameter dictionary: The Swift dictionary to convert.
/// - Returns: A Ladybug struct value.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func swiftDictionaryToLadybugStruct(_ dictionary: NSDictionary)
    throws -> UnsafeMutablePointer<lbug_value>
{
    let numFields = UInt64(dictionary.count)
    if numFields == 0 {
        throw LadybugError.valueConversionFailed(
            "Cannot convert empty map to Ladybug struct"
        )
    }
    var stringKeyMap: [String: UnsafeMutablePointer<lbug_value>?] = [:]
    defer {
        for (_, cValue) in stringKeyMap {
            lbug_value_destroy(cValue)
        }
    }
    for key in dictionary.allKeys {
        if let stringKey = key as? String {
            stringKeyMap[stringKey] = try swiftValueToLadybugValue(dictionary[key])
        } else {
            throw LadybugError.valueConversionFailed(
                "Cannot convert dictionary to Ladybug struct: keys must be strings"
            )
        }
    }
    // Sort the keys to ensure the order is consistent.
    // This is useful for creating a LIST of STRUCTs because in Ladybug, all the
    // LIST elements must have the same type (i.e., the same order of fields).
    let sortedKeys = Array(stringKeyMap.keys).sorted()

    var mutableSortedCStrings: [UnsafeMutablePointer<CChar>?] = []
    let sortedKeysCStrings: UnsafeMutablePointer<UnsafePointer<CChar>?> =
        .allocate(capacity: sortedKeys.count)
    let sortedValues: UnsafeMutablePointer<UnsafeMutablePointer<lbug_value>?> =
        .allocate(capacity: sortedKeys.count)

    for idx in 0..<sortedKeys.count {
        let currKey = sortedKeys[idx]
        let currKeyCString = strdup(sortedKeys[idx])
        mutableSortedCStrings.append(currKeyCString)
        sortedKeysCStrings[idx] = UnsafePointer(currKeyCString)
        sortedValues[idx] = stringKeyMap[currKey]!
    }
    defer {
        for idx in 0..<sortedKeys.count {
            free(mutableSortedCStrings[idx])
        }
        sortedKeysCStrings.deallocate()
        sortedValues.deallocate()
    }

    var cStructValue: UnsafeMutablePointer<lbug_value>?
    lbug_value_create_struct(
        numFields,
        sortedKeysCStrings,
        sortedValues,
        &cStructValue
    )
    return cStructValue!
}

/// Converts a Ladybug struct value to a Swift dictionary.
/// - Parameter cValue: The Ladybug struct value to convert.
/// - Returns: A Swift dictionary containing the struct fields.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func ladybugStructValueToSwiftDictionary(_ cValue: inout lbug_value) throws
    -> [String: Any?]
{
    var dict: [String: Any?] = [:]
    var propertySize: UInt64 = 0
    lbug_value_get_struct_num_fields(&cValue, &propertySize)
    var currentKey: UnsafeMutablePointer<CChar>?
    var currentValue = lbug_value()
    for i in UInt64(0)..<propertySize {
        var state = lbug_value_get_struct_field_name(&cValue, i, &currentKey)
        if state != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get struct field name with status: \(state)"
            )
        }
        defer {
            lbug_destroy_string(currentKey)
        }
        let key = String(cString: currentKey!)
        state = lbug_value_get_struct_field_value(&cValue, i, &currentValue)
        if state != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get struct field with status: \(state)"
            )
        }
        defer {
            lbug_value_destroy(&currentValue)
        }
        let swiftValue = try ladybugValueToSwift(&currentValue)
        dict[key] = swiftValue
    }
    return dict
}

/// Converts a Ladybug union value to a Swift value.
/// - Parameter cValue: The Ladybug union value to convert.
/// - Returns: A Swift value.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func ladybugUnionValueToSwiftValue(_ cValue: inout lbug_value) throws
    -> Any?
{
    var unionValue = lbug_value()
    // Only one member in the union can be active at a time and that member is always stored
    // at index 0.
    let state = lbug_value_get_struct_field_value(&cValue, 0, &unionValue)
    if state != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get union value with status: \(state)"
        )
    }
    defer { lbug_value_destroy(&unionValue) }
    return try ladybugValueToSwift(&unionValue)
}

/// Converts a Ladybug node value to a Swift LadybugNode.
/// - Parameter cValue: The Ladybug node value to convert.
/// - Returns: A Swift LadybugNode.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func ladybugNodeValueToSwiftNode(_ cValue: inout lbug_value) throws
    -> LadybugNode
{
    var idValue = lbug_value()
    let idState = lbug_node_val_get_id_val(&cValue, &idValue)
    if idState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get node ID with status: \(idState)"
        )
    }
    defer { lbug_value_destroy(&idValue) }
    let id = try ladybugValueToSwift(&idValue) as! LadybugInternalId

    var labelValue = lbug_value()
    let labelState = lbug_node_val_get_label_val(&cValue, &labelValue)
    if labelState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get node label with status: \(labelState)"
        )
    }
    defer { lbug_value_destroy(&labelValue) }
    let label = try ladybugValueToSwift(&labelValue) as! String

    var propertySize: UInt64 = 0
    let propertySizeState = lbug_node_val_get_property_size(
        &cValue,
        &propertySize
    )
    if propertySizeState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get property size with status: \(propertySizeState)"
        )
    }

    var properties: [String: Any?] = [:]
    var currentKey: UnsafeMutablePointer<CChar>?
    var currentValue = lbug_value()

    for i in UInt64(0)..<propertySize {
        let keyState = lbug_node_val_get_property_name_at(
            &cValue,
            i,
            &currentKey
        )
        if keyState != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get property name with status: \(keyState)"
            )
        }
        defer { lbug_destroy_string(currentKey) }
        let key = String(cString: currentKey!)

        let valueState = lbug_node_val_get_property_value_at(
            &cValue,
            i,
            &currentValue
        )
        if valueState != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get property value with status: \(valueState)"
            )
        }
        defer { lbug_value_destroy(&currentValue) }

        let value = try ladybugValueToSwift(&currentValue)
        properties[key] = value
    }

    return LadybugNode(id: id, label: label, properties: properties)
}

/// Converts a Ladybug relationship value to a Swift LadybugRelationship.
/// - Parameter cValue: The Ladybug relationship value to convert.
/// - Returns: A Swift LadybugRelationship.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func ladybugRelValueToSwiftRelationship(_ cValue: inout lbug_value) throws
    -> LadybugRelationship
{
    var idValue = lbug_value()
    
    let idState = lbug_rel_val_get_id_val(&cValue, &idValue)
    if idState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get relationship ID with status: \(idState)"
        )
    }
    let id = try ladybugValueToSwift(&idValue) as! LadybugInternalId
    lbug_value_destroy(&idValue)

    let srcState = lbug_rel_val_get_src_id_val(&cValue, &idValue)
    if srcState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get relationship source ID with status: \(srcState)"
        )
    }
    let sourceId = try ladybugValueToSwift(&idValue) as! LadybugInternalId
    lbug_value_destroy(&idValue)

    let dstState = lbug_rel_val_get_dst_id_val(&cValue, &idValue)
    if dstState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get relationship target ID with status: \(dstState)"
        )
    }
    let targetId = try ladybugValueToSwift(&idValue) as! LadybugInternalId
    lbug_value_destroy(&idValue)

    var labelValue = lbug_value()
    let labelState = lbug_rel_val_get_label_val(&cValue, &labelValue)
    if labelState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get relationship label with status: \(labelState)"
        )
    }
    let label = try ladybugValueToSwift(&labelValue) as! String

    lbug_value_destroy(&labelValue)

    // Get Properties
    var propertySize: UInt64 = 0
    let propertySizeState = lbug_rel_val_get_property_size(
        &cValue,
        &propertySize
    )
    if propertySizeState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get property size with status: \(propertySizeState)"
        )
    }

    var properties: [String: Any?] = [:]
    var currentKey: UnsafeMutablePointer<CChar>?
    var currentValue = lbug_value()

    for i in UInt64(0)..<propertySize {
        let keyState = lbug_rel_val_get_property_name_at(
            &cValue,
            i,
            &currentKey
        )
        if keyState != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get property name with status: \(keyState)"
            )
        }
        defer { lbug_destroy_string(currentKey) }
        let key = String(cString: currentKey!)

        let valueState = lbug_rel_val_get_property_value_at(
            &cValue,
            i,
            &currentValue
        )
        if valueState != LbugSuccess {
            throw LadybugError.valueConversionFailed(
                "Failed to get property value with status: \(valueState)"
            )
        }
        defer { lbug_value_destroy(&currentValue) }

        let value = try ladybugValueToSwift(&currentValue)
        properties[key] = value
    }

    return LadybugRelationship(
        id: id,
        sourceId: sourceId,
        targetId: targetId,
        label: label,
        properties: properties
    )
}

/// Converts a Ladybug recursive relationship value to a Swift LadybugRecursiveRelationship.
/// - Parameter cValue: The Ladybug recursive relationship value to convert.
/// - Returns: A Swift LadybugRecursiveRelationship.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
private func ladybugRecursiveRelValueToSwiftRecursiveRelationship(
    _ cValue: inout lbug_value
) throws
    -> LadybugRecursiveRelationship
{
    var nodesValue = lbug_value()
    let nodesState = lbug_value_get_recursive_rel_node_list(
        &cValue,
        &nodesValue
    )
    if nodesState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get recursive relationship nodes with status: \(nodesState)"
        )
    }
    defer { lbug_value_destroy(&nodesValue) }

    var relsValue = lbug_value()
    let relsState = lbug_value_get_recursive_rel_rel_list(&cValue, &relsValue)
    if relsState != LbugSuccess {
        throw LadybugError.valueConversionFailed(
            "Failed to get recursive relationship relationships with status: \(relsState)"
        )
    }
    defer { lbug_value_destroy(&relsValue) }

    let nodesArray = try ladybugListToSwiftArray(&nodesValue)
    let relsArray = try ladybugListToSwiftArray(&relsValue)

    var nodes: [LadybugNode] = []
    for node in nodesArray {
        guard let ladybugNode = node as? LadybugNode else {
            throw LadybugError.valueConversionFailed(
                "Failed to convert node to LadybugNode"
            )
        }
        nodes.append(ladybugNode)
    }

    var relationships: [LadybugRelationship] = []
    for rel in relsArray {
        guard let ladybugRel = rel as? LadybugRelationship else {
            throw LadybugError.valueConversionFailed(
                "Failed to convert relationship to LadybugRelationship"
            )
        }
        relationships.append(ladybugRel)
    }

    return LadybugRecursiveRelationship(nodes: nodes, relationships: relationships)
}

/// Converts a Swift value to a Ladybug value.
/// - Parameter value: The Swift value to convert.
/// - Returns: A Ladybug value.
/// - Throws: `LadybugError.valueConversionFailed` if the conversion fails.
internal func swiftValueToLadybugValue(_ value: Any?)
    throws -> UnsafeMutablePointer<lbug_value>
{
    if value == nil {
        return lbug_value_create_null()
    }
    var valuePtr: UnsafeMutablePointer<lbug_value>
    let dtype = Mirror(reflecting: value!).subjectType
    if let number = value as? NSNumber {
        #if os(Linux)
            throw LadybugError.valueConversionFailed(
                "Native Swift numeric types cannot be resolved correctly on Linux. Please use the wrapper structs instead."
            )
        #else
            // Handle numeric types based on the real type of the number, instead
            // of runtime casting (e.g. let number as Int), because a number can be
            // casted to multiple types, which can cause inconsistencies.
            // See https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
            let objCType = String(cString: number.objCType)
            switch objCType {
            case "c":
                // Boolean is encoded as char in Swift / Objective-C.
                valuePtr =
                    CFGetTypeID(number) == CFBooleanGetTypeID()
                    ? lbug_value_create_bool(number as! Bool)
                    : lbug_value_create_int8(number as! Int8)
            case "i":
                valuePtr = lbug_value_create_int32(number as! Int32)
            case "s":
                valuePtr = lbug_value_create_int16(number as! Int16)
            case "l":
                valuePtr = lbug_value_create_int32(number as! Int32)
            case "q":
                valuePtr = lbug_value_create_int64(number as! Int64)
            //        Internally Swift does not seem to really use these UInt
            //        type representations, so we use the `LadybugUIntWrapper`
            //        structs as a workaround.
            //        case "C":
            //            valuePtr = lbug_value_create_uint8(number as! UInt8)
            //        case "I":
            //            valuePtr = lbug_value_create_uint32(number as! UInt32)
            //        case "S":
            //            valuePtr = lbug_value_create_uint16(number as! UInt16)
            //        case "L":
            //            valuePtr = lbug_value_create_uint32(number as! UInt32)
            case "Q":
                valuePtr = lbug_value_create_uint64(number as! UInt64)
            case "f":
                valuePtr = lbug_value_create_float(number as! Float32)
            case "d":
                valuePtr = lbug_value_create_double(number as! Double)
            default:
                throw LadybugError.valueConversionFailed(
                    "Unsupported numeric type with encoding: \(objCType)"
                )
            }
        #endif
    } else {
        switch value! {
        case let ladybugUint64 as LadybugUInt64Wrapper:
            valuePtr = lbug_value_create_uint64(UInt64(ladybugUint64.value))
        case let ladybugUint32 as LadybugUInt32Wrapper:
            valuePtr = lbug_value_create_uint32(UInt32(ladybugUint32.value))
        case let ladybugUint16 as LadybugUInt16Wrapper:
            valuePtr = lbug_value_create_uint16(UInt16(ladybugUint16.value))
        case let ladybugUint8 as LadybugUInt8Wrapper:
            valuePtr = lbug_value_create_uint8(UInt8(ladybugUint8.value))
        case let ladybugInt64 as LadybugInt64Wrapper:
            valuePtr = lbug_value_create_int64(Int64(ladybugInt64.value))
        case let ladybugInt32 as LadybugInt32Wrapper:
            valuePtr = lbug_value_create_int32(Int32(ladybugInt32.value))
        case let ladybugInt16 as LadybugInt16Wrapper:
            valuePtr = lbug_value_create_int16(Int16(ladybugInt16.value))
        case let ladybugInt8 as LadybugInt8Wrapper:
            valuePtr = lbug_value_create_int8(Int8(ladybugInt8.value))
        case let ladybugFloat as LadybugFloatWrapper:
            valuePtr = lbug_value_create_float(Float(ladybugFloat.value))
        case let ladybugDouble as LadybugDoubleWrapper:
            valuePtr = lbug_value_create_double(Double(ladybugDouble.value))
        case let ladybugBool as LadybugBoolWrapper:
            valuePtr = lbug_value_create_bool(ladybugBool.value)
        case let string as String:
            valuePtr = lbug_value_create_string(string)
        case let date as Date:
            let timestamp = swiftDateToLadybugTimestamp(date)
            valuePtr = lbug_value_create_timestamp(timestamp)
        case let timeInterval as TimeInterval:
            let interval = swiftTimeIntervalToLadybugInterval(timeInterval)
            valuePtr = lbug_value_create_interval(interval)
        case let arrayOfMapItems as [(Any?, Any?)]:
            valuePtr = try swiftArrayOfMapItemsToLadybugMap(arrayOfMapItems)
        case let array as NSArray:
            valuePtr = try swiftArrayToLadybugList(array)
        case let dictionary as NSDictionary:
            valuePtr = try swiftDictionaryToLadybugStruct(dictionary)
        default:
            throw LadybugError.valueConversionFailed(
                "Unsupported Swift type \(dtype)"
            )
        }
    }
    return valuePtr
}

/// Converts a Ladybug value to a Swift value.
/// - Parameter cValue: The Ladybug value to convert.
/// - Returns: A Swift value.
/// - Throws: `LadybugError.getValueFailed` if the conversion fails.
internal func ladybugValueToSwift(_ cValue: inout lbug_value) throws -> Any? {
    if lbug_value_is_null(&cValue) {
        return nil
    }
    var logicalType = lbug_logical_type()
    lbug_value_get_data_type(&cValue, &logicalType)
    defer { lbug_data_type_destroy(&logicalType) }
    let logicalTypeId = lbug_data_type_get_id(&logicalType)
    switch logicalTypeId {
    case LBUG_BOOL:
        var value: Bool = Bool()
        let state = lbug_value_get_bool(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get bool value with status \(state)"
            )
        }
        return value
    case LBUG_INT64, LBUG_SERIAL:
        var value: Int64 = Int64()
        let state = lbug_value_get_int64(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get int64 value with status \(state)"
            )
        }
        return value
    case LBUG_INT32:
        var value: Int32 = Int32()
        let state = lbug_value_get_int32(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get int32 value with status \(state)"
            )
        }
        return value
    case LBUG_INT16:
        var value: Int16 = Int16()
        let state = lbug_value_get_int16(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get int16 value with status \(state)"
            )
        }
        return value
    case LBUG_INT8:
        var value: Int8 = Int8()
        let state = lbug_value_get_int8(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get int8 value with status \(state)"
            )
        }
        return value
    case LBUG_INT128:
        var int128Value = lbug_int128_t()
        let getValueState = lbug_value_get_int128(&cValue, &int128Value)
        if getValueState != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get int128 value with status \(getValueState)"
            )
        }
        var valueString: UnsafeMutablePointer<CChar>?
        let valueConversionState = lbug_int128_t_to_string(
            int128Value,
            &valueString
        )
        if valueConversionState != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to convert int128 to string with status \(valueConversionState)"
            )
        }
        defer {
            lbug_destroy_string(valueString)
        }
        let decimalString = String(cString: valueString!)
        let decimal = Decimal(string: decimalString)
        return decimal
    case LBUG_UUID:
        var valueString: UnsafeMutablePointer<CChar>?
        let state = lbug_value_get_uuid(&cValue, &valueString)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get uuid value with status \(state)"
            )
        }
        defer {
            lbug_destroy_string(valueString)
        }
        let uuidString = String(cString: valueString!)
        return UUID(uuidString: uuidString)!
    case LBUG_UINT64:
        var value: UInt64 = UInt64()
        let state = lbug_value_get_uint64(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get uint64 value with status \(state)"
            )
        }
        return value
    case LBUG_UINT32:
        var value: UInt32 = UInt32()
        let state = lbug_value_get_uint32(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get uint32 value with status \(state)"
            )
        }
        return value
    case LBUG_UINT16:
        var value: UInt16 = UInt16()
        let state = lbug_value_get_uint16(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get uint16 value with status \(state)"
            )
        }
        return value
    case LBUG_UINT8:
        var value: UInt8 = UInt8()
        let state = lbug_value_get_uint8(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get uint8 value with status \(state)"
            )
        }
        return value
    case LBUG_FLOAT:
        var value: Float = Float()
        let state = lbug_value_get_float(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get float value with status \(state)"
            )
        }
        return value
    case LBUG_DOUBLE:
        var value: Double = Double()
        let state = lbug_value_get_double(&cValue, &value)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get double value with status \(state)"
            )
        }
        return value
    case LBUG_STRING:
        var strValue: UnsafeMutablePointer<CChar>?
        let state = lbug_value_get_string(&cValue, &strValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get string value with status \(state)"
            )
        }
        defer {
            lbug_destroy_string(strValue)
        }
        return String(cString: strValue!)
    case LBUG_TIMESTAMP:
        var cTimestampValue = lbug_timestamp_t()
        let state = lbug_value_get_timestamp(&cValue, &cTimestampValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get timestamp value with status \(state)"
            )
        }
        let microseconds = cTimestampValue.value
        let seconds: Double = Double(microseconds) / MICROSECONDS_IN_A_SECOND
        return Date(timeIntervalSince1970: seconds)
    case LBUG_TIMESTAMP_NS:
        var cTimestampValue = lbug_timestamp_ns_t()
        let state = lbug_value_get_timestamp_ns(&cValue, &cTimestampValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get timestamp value with status \(state)"
            )
        }
        let nanoseconds = cTimestampValue.value
        let seconds: Double = Double(nanoseconds) / NANOSECONDS_IN_A_SECOND
        return Date(timeIntervalSince1970: seconds)
    case LBUG_TIMESTAMP_MS:
        var cTimestampValue = lbug_timestamp_ms_t()
        let state = lbug_value_get_timestamp_ms(&cValue, &cTimestampValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get timestamp value with status \(state)"
            )
        }
        let milliseconds = cTimestampValue.value
        let seconds: Double = Double(milliseconds) / MILLISECONDS_IN_A_SECOND
        return Date(timeIntervalSince1970: seconds)
    case LBUG_TIMESTAMP_SEC:
        var cTimestampValue = lbug_timestamp_sec_t()
        let state = lbug_value_get_timestamp_sec(&cValue, &cTimestampValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get timestamp value with status \(state)"
            )
        }
        let seconds = cTimestampValue.value
        return Date(timeIntervalSince1970: Double(seconds))
    case LBUG_TIMESTAMP_TZ:
        var cTimestampValue = lbug_timestamp_tz_t()
        let state = lbug_value_get_timestamp_tz(&cValue, &cTimestampValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get timestamp value with status \(state)"
            )
        }
        let microseconds = cTimestampValue.value
        let seconds: Double = Double(microseconds) / MICROSECONDS_IN_A_SECOND
        return Date(timeIntervalSince1970: seconds)
    case LBUG_DATE:
        var cDateValue = lbug_date_t()
        let state = lbug_value_get_date(&cValue, &cDateValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get date value with status \(state)"
            )
        }
        let days = cDateValue.days
        let seconds: Double = Double(days) * SECONDS_IN_A_DAY
        return Date(timeIntervalSince1970: seconds)
    case LBUG_INTERVAL:
        var cIntervalValue = lbug_interval_t()
        let state = lbug_value_get_interval(&cValue, &cIntervalValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get interval value with status \(state)"
            )
        }
        return ladybugIntervalToSwiftTimeInterval(cIntervalValue)
    case LBUG_INTERNAL_ID:
        var cInternalIdValue = lbug_internal_id_t()
        let state = lbug_value_get_internal_id(&cValue, &cInternalIdValue)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get internal id value with status \(state)"
            )
        }
        return LadybugInternalId(
            tableId: cInternalIdValue.table_id,
            offset: cInternalIdValue.offset
        )
    case LBUG_BLOB:
        var cBlobValue: UnsafeMutablePointer<UInt8>?
        var blobLength: UInt64 = 0
        let state = lbug_value_get_blob(&cValue, &cBlobValue, &blobLength)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get blob value with status \(state)"
            )
        }
        defer {
            lbug_destroy_blob(cBlobValue)
        }
        let blobData = Data(bytes: cBlobValue!, count: Int(blobLength))
        return blobData
    case LBUG_DECIMAL:
        var outString: UnsafeMutablePointer<CChar>?
        let state = lbug_value_get_decimal_as_string(&cValue, &outString)
        if state != LbugSuccess {
            throw LadybugError.getValueFailed(
                "Failed to get string value of decimal type with status: \(state)"
            )
        }
        defer {
            lbug_destroy_string(outString)
        }
        let decimalString = String(cString: outString!)
        guard let decimal = Decimal(string: decimalString) else {
            throw LadybugError.valueConversionFailed(
                "Failed to convert decimal value from string: \(decimalString)"
            )
        }
        return decimal
    case LBUG_LIST, LBUG_ARRAY:
        return try ladybugListToSwiftArray(&cValue)
    case LBUG_STRUCT:
        return try ladybugStructValueToSwiftDictionary(&cValue)
    case LBUG_UNION:
        return try ladybugUnionValueToSwiftValue(&cValue)
    case LBUG_MAP:
        return try ladybugMapToSwiftArrayOfMapItems(&cValue)
    case LBUG_NODE:
        return try ladybugNodeValueToSwiftNode(&cValue)
    case LBUG_REL:
        return try ladybugRelValueToSwiftRelationship(&cValue)
    case LBUG_RECURSIVE_REL:
        return try ladybugRecursiveRelValueToSwiftRecursiveRelationship(&cValue)
    default:
        let valueString = lbug_value_to_string(&cValue)
        defer { lbug_destroy_string(valueString) }
        throw LadybugError.valueConversionFailed(
            "Unsupported C value with value \(String(cString: valueString!)) and typeId \(logicalTypeId)"
        )
    }
}
