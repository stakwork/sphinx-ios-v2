//
//  swift-ladybug
//  https://github.com/LadybugDB/swift-ladybug
//
//  Copyright © 2023 - 2025 Kùzu Inc.
//  This code is licensed under MIT license (see LICENSE for details)

import Foundation
import XCTest

@testable import Ladybug

final class ParameterTests: XCTestCase {
    private var db: Database!
    private var conn: Connection!
    private var path: String!

    override func setUp() {
        super.setUp()
        (db, conn, path) = try! getTestDatabase()
    }

    override func tearDown() {
        deleteTestDatabaseDirectory(path)
        super.tearDown()
    }

    private func basicParamTestHelper(_ param: Any?) throws {
        let preparedStatement = try conn.prepare("RETURN $1")
        let params = ["1": param]
        let result = try conn.execute(preparedStatement, params)
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0)

        if param == nil && value == nil {
            return
        }

        // Handle different types explicitly
        switch (param, value) {
        case (let p as String, let v as String):
            XCTAssertEqual(p, v)
        case (let p as Bool, let v as Bool):
            XCTAssertEqual(p, v)
        case (let p as Int64, let v as Int64):
            XCTAssertEqual(p, v)
        case (let p as Int32, let v as Int32):
            XCTAssertEqual(p, v)
        case (let p as Int16, let v as Int16):
            XCTAssertEqual(p, v)
        case (let p as Int8, let v as Int8):
            XCTAssertEqual(p, v)
        case (let p as UInt64, let v as UInt64):
            XCTAssertEqual(p, v)
        case (let p as LadybugUInt64Wrapper, let v as UInt64):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugUInt32Wrapper, let v as UInt32):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugUInt16Wrapper, let v as UInt16):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugUInt8Wrapper, let v as UInt8):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugInt64Wrapper, let v as Int64):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugInt32Wrapper, let v as Int32):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugInt16Wrapper, let v as Int16):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugInt8Wrapper, let v as Int8):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugFloatWrapper, let v as Float):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugDoubleWrapper, let v as Double):
            XCTAssertEqual(p.value, v)
        case (let p as LadybugBoolWrapper, let v as Bool):
            XCTAssertEqual(p.value, v)
        case (let p as TimeInterval, let v as TimeInterval):
            XCTAssertEqual(p, v)
        case (is NSNull, is NSNull):
            // Both are NSNull, which is what we want
            break
        case (let p as [String: Any], let v as [String: Any]):
            XCTAssertEqual(p.count, v.count)
            for (key, pValue) in p {
                guard v[key] != nil else {
                    XCTFail("Missing key in result: \(key)")
                    continue
                }
                try basicParamTestHelper(pValue)
            }
        case (let p as [(String, Any)], let v as [(String, Any)]):
            XCTAssertEqual(p.count, v.count)
            for i in 0..<p.count {
                XCTAssertEqual(p[i].0, v[i].0)
                try basicParamTestHelper(p[i].1)
            }
        case (let p as [Any], let v as [Any]):
            XCTAssertEqual(p.count, v.count)
            for i in 0..<p.count {
                try basicParamTestHelper(p[i])
            }
        default:
            XCTFail(
                "Type mismatch: expected \(type(of: param!)), got \(type(of: value!))"
            )
        }
    }

    private func floatParamTestHelper(_ param: Any) throws {
        let preparedStatement = try conn.prepare("RETURN $1")
        let params = ["1": param]
        let result = try conn.execute(preparedStatement, params)
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0)
        if let floatValue = value as? Double, let paramValue = param as? Double
        {
            XCTAssertLessThan(abs(floatValue - paramValue), 0.000001)
        } else if let floatValue = value as? Float,
            let paramValue = param as? Float
        {
            XCTAssertLessThan(abs(floatValue - paramValue), 0.000001)
        } else {
            XCTFail("Type mismatch in floatParamTestHelper")
        }
    }

    private func timeParamTestHelper(_ param: Date) throws {
        let preparedStatement = try conn.prepare("RETURN $1")
        let params = ["1": param]
        let result = try conn.execute(preparedStatement, params)
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! Date
        XCTAssertEqual(value, param)
    }

    func testStringParam() throws {
        try basicParamTestHelper("Hello World")
    }

    #if !os(Linux)
        func testBoolParam() throws {
            try basicParamTestHelper(true)
            try basicParamTestHelper(false)
        }

        func testInt64Param() throws {
            try basicParamTestHelper(Int64(1_000_000_000_000))
        }

        func testInt32Param() throws {
            try basicParamTestHelper(Int32(200))
        }

        func testInt16Param() throws {
            try basicParamTestHelper(Int16(300))
        }

        func testInt8Param() throws {
            try basicParamTestHelper(Int8(4))
        }

        func testUint64Param() throws {
            try basicParamTestHelper(UInt64.max)
        }

        func testDoubleParam() throws {
            try floatParamTestHelper(Double(3.14159235))
        }

        func testFloatParam() throws {
            try floatParamTestHelper(Float(2.71828))
        }
    #endif

    func testUint32Param() throws {
        try basicParamTestHelper(LadybugUInt32Wrapper(value: 600))
    }

    func testUint16Param() throws {
        try basicParamTestHelper(LadybugUInt16Wrapper(value: 700))
    }

    func testUint8Param() throws {
        try basicParamTestHelper(LadybugUInt8Wrapper(value: 8))
    }

    func testBoolWrapperParam() throws {
        try basicParamTestHelper(LadybugBoolWrapper(value: true))
    }

    func testInt64WrapperParam() throws {
        try basicParamTestHelper(LadybugInt64Wrapper(value: 900))
    }

    func testInt32WrapperParam() throws {
        try basicParamTestHelper(LadybugInt32Wrapper(value: 1000))
    }

    func testInt16WrapperParam() throws {
        try basicParamTestHelper(LadybugInt16Wrapper(value: 1100))
    }

    func testInt8WrapperParam() throws {
        try basicParamTestHelper(LadybugInt8Wrapper(value: 12))
    }

    func testUInt64WrapperParam() throws {
        try basicParamTestHelper(LadybugUInt64Wrapper(value: UInt64.max - 3))
    }

    func testDoubleWrapperParam() throws {
        try basicParamTestHelper(LadybugDoubleWrapper(value: 14.12435))
    }

    func testFloatWrapperParam() throws {
        try basicParamTestHelper(LadybugFloatWrapper(value: 13.0))
    }

    func testTimeParam() throws {
        let date = Calendar.current.date(
            from: DateComponents(year: 2020, month: 1, day: 1)
        )!
        try timeParamTestHelper(date)
    }

    func testTimeWithNanosecondsParam() throws {
        var components = DateComponents()
        components.year = 2020
        components.month = 1
        components.day = 1
        components.nanosecond = 1
        let date = Calendar.current.date(from: components)!
        try timeParamTestHelper(date)
    }

    func testDurationParam() throws {
        #if os(Linux)
            try basicParamTestHelper(LadybugInt64Wrapper(value: 1_000_000_000))
        #else
            try basicParamTestHelper(TimeInterval(1_000_000_000))
        #endif
    }

    func testNilParam() throws {
        try basicParamTestHelper(nil)
    }

    func testStructParam() throws {
        let structParam: [String: Any]
        #if os(Linux)
            structParam = [
                "name": "Alice",
                "age": LadybugInt64Wrapper(value: 30),
                "isStudent": LadybugBoolWrapper(value: false),
            ]
        #else
            structParam = [
                "name": "Alice",
                "age": Int64(30),
                "isStudent": false,
            ]
        #endif
        try basicParamTestHelper(structParam)
    }

    func testStructWithNestedStructParam() throws {
        let structParam: [String: Any] = [
            "name": "Alice",
            "address": [
                "city": "New York",
                "country": "USA",
            ] as [String: Any],
        ]
        try basicParamTestHelper(structParam)
    }

    func testStructWithUnsupportedTypeParam() throws {
        let structParam: [String: Any] = [
            "name": "Alice",
            "age": try! NSRegularExpression(pattern: ".*", options: []),
        ]
        let preparedStatement = try conn.prepare("RETURN $1")
        do {
            _ = try conn.execute(preparedStatement, ["1": structParam])
            XCTFail("Expected error for unsupported type")
        } catch let error as LadybugError {
            XCTAssertTrue(error.message.contains("Unsupported Swift type"))
        }
    }

    func testEmptyMapParam() throws {
        let emptyMap: [String: Any] = [:]
        let preparedStatement = try conn.prepare("RETURN $1")
        do {
            _ = try conn.execute(preparedStatement, ["1": emptyMap])
            XCTFail("Expected error for empty map")
        } catch let error as LadybugError {
            XCTAssertTrue(error.message.contains("empty"))
        }
    }

    func testMapParam() throws {
        #if os(Linux)
            let mapParam: [(String, LadybugInt64Wrapper)] = [
                ("1", LadybugInt64Wrapper(value: 1)),
                ("2", LadybugInt64Wrapper(value: 2)),
                ("3", LadybugInt64Wrapper(value: 3)),
            ]
        #else
            let mapParam: [(String, Int64)] = [
                ("1", 1),
                ("2", 2),
                ("3", 3),
            ]
        #endif
        try basicParamTestHelper(mapParam)
    }

    func testMapParamNested() throws {
        let mapParam: [(String, [(String, String)])] = [
            ("1", [("a", "A")]),
            ("2", [("b", "B")]),
            ("3", [("c", "C")]),
        ]
        try basicParamTestHelper(mapParam)
    }

    func testMapParamWithUnsupportedType() throws {
        let mapParam: [(String, Any)] = [
            ("1", try! NSRegularExpression(pattern: ".*", options: []))
        ]
        let preparedStatement = try conn.prepare("RETURN $1")
        do {
            _ = try conn.execute(preparedStatement, ["1": mapParam])
            XCTFail("Expected error for unsupported type")
        } catch let error as LadybugError {
            XCTAssertTrue(error.message.contains("Unsupported Swift type"))
        }
    }

    func testMapWithMixedTypesParam() throws {
        // Since Ladybug 0.17, mixed-type values are coerced to a common type
        // (here STRING) instead of raising an error.
        #if os(Linux)
            let mapParam: [(String, Any)] = [
                ("1", "One"),
                ("2", "Two"),
                ("3", "Three"),
                ("4", LadybugInt64Wrapper(value: 4)),
            ]
        #else
            let mapParam: [(String, Any)] = [
                ("1", "One"),
                ("2", "Two"),
                ("3", "Three"),
                ("4", 4),
            ]
        #endif
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": mapParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [(String, Any)]
        XCTAssertEqual(value.count, mapParam.count)
        let expected: [(String, String)] = [
            ("1", "One"), ("2", "Two"), ("3", "Three"), ("4", "4"),
        ]
        for i in 0..<expected.count {
            XCTAssertEqual(value[i].0, expected[i].0)
            XCTAssertEqual(value[i].1 as! String, expected[i].1)
        }
        XCTAssertFalse(result.hasNext())
    }

    func testArrayParam() throws {
        let arrayParam: [Any] = ["One", "Two", "Three"]
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": arrayParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [Any]
        XCTAssertEqual(value.count, arrayParam.count)
        for i in 0..<arrayParam.count {
            XCTAssertEqual(value[i] as! String, arrayParam[i] as! String)
        }
        XCTAssertFalse(result.hasNext())
    }

    func testArrayParamNested() throws {
        let arrayParam: [[Any]] = [
            ["a", "A"],
            ["b", "B"],
            ["c", "C"],
        ]
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": arrayParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [[Any]]
        XCTAssertEqual(value.count, arrayParam.count)
        for i in 0..<arrayParam.count {
            XCTAssertEqual(value[i].count, arrayParam[i].count)
            for j in 0..<arrayParam[i].count {
                XCTAssertEqual(
                    value[i][j] as! String,
                    arrayParam[i][j] as! String
                )
            }
        }
        XCTAssertFalse(result.hasNext())
    }

    func testArrayParamNestedStruct() throws {
        let arrayParam: [[String: Any]] = [
            ["name": "Alice", "age": LadybugInt64Wrapper(value: 30)],
            ["name": "Bob", "age": LadybugInt64Wrapper(value: 40)],
            ["name": "Charlie", "age": LadybugInt64Wrapper(value: 50)],
        ]
        let expectedValue: [[String: Any]] = [
            ["name": "Alice", "age": Int64(30)],
            ["name": "Bob", "age": Int64(40)],
            ["name": "Charlie", "age": Int64(50)],
        ]
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": arrayParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [[String: Any]]
        XCTAssertEqual(value.count, expectedValue.count)
        for i in 0..<expectedValue.count {
            XCTAssertEqual(value[i].count, expectedValue[i].count)
            for (key, paramValue) in expectedValue[i] {
                let resultValue = value[i][key]!
                if let paramInt = paramValue as? Int64,
                    let resultInt = resultValue as? Int64
                {
                    XCTAssertEqual(paramInt, resultInt)
                } else if let paramString = paramValue as? String,
                    let resultString = resultValue as? String
                {
                    XCTAssertEqual(paramString, resultString)
                } else {
                    XCTFail("Unexpected type in nested struct")
                }
            }
        }
        XCTAssertFalse(result.hasNext())
    }

    func testArrayParamWithUnsupportedType() throws {
        let arrayParam: [Any] = [
            "One", try! NSRegularExpression(pattern: ".*", options: []),
        ]
        let preparedStatement = try conn.prepare("RETURN $1")
        do {
            _ = try conn.execute(preparedStatement, ["1": arrayParam])
            XCTFail("Expected error for unsupported type")
        } catch let error as LadybugError {
            XCTAssertTrue(error.message.contains("Unsupported Swift type"))
        }
    }

    func testArrayWithMixedTypesParam() throws {
        // Since Ladybug 0.17, mixed-type elements are coerced to a common type
        // (here STRING) instead of raising an error.
        #if os(Linux)
            let arrayParam: [Any] = [
                "One", "Two", "Three", LadybugInt64Wrapper(value: 4),
            ]
        #else
            let arrayParam: [Any] = ["One", "Two", "Three", 4]
        #endif
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": arrayParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [Any]
        let expected = ["One", "Two", "Three", "4"]
        XCTAssertEqual(value.count, expected.count)
        for i in 0..<expected.count {
            XCTAssertEqual(value[i] as! String, expected[i])
        }
        XCTAssertFalse(result.hasNext())
    }

    func testInt64ArrayParam() throws {
        #if os(Linux)
            let arrayParam: [LadybugInt64Wrapper] = [
                LadybugInt64Wrapper(value: 1),
                LadybugInt64Wrapper(value: 2),
                LadybugInt64Wrapper(value: 3),
            ]
        #else
            let arrayParam: [Int64] = [1, 2, 3]
        #endif
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": arrayParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [Any]
        XCTAssertEqual(value.count, arrayParam.count)
        for i in 0..<arrayParam.count {
            #if os(Linux)
                XCTAssertEqual(value[i] as! Int64, arrayParam[i].value)
            #else
                XCTAssertEqual(value[i] as! Int64, arrayParam[i])
            #endif
        }
        XCTAssertFalse(result.hasNext())
    }

    func testStringArrayParam() throws {
        let arrayParam: [String] = ["One", "Two", "Three"]
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": arrayParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [Any]
        XCTAssertEqual(value.count, arrayParam.count)
        for i in 0..<arrayParam.count {
            XCTAssertEqual(value[i] as! String, arrayParam[i])
        }
        XCTAssertFalse(result.hasNext())
    }

    func testNestedInt64ArrayParam() throws {
        #if os(Linux)
            let arrayParam: [[LadybugInt64Wrapper]] = [
                [
                    LadybugInt64Wrapper(value: 0), LadybugInt64Wrapper(value: 1),
                    LadybugInt64Wrapper(value: 2), LadybugInt64Wrapper(value: 3),
                ],
                [
                    LadybugInt64Wrapper(value: 4), LadybugInt64Wrapper(value: 5),
                    LadybugInt64Wrapper(value: 6), LadybugInt64Wrapper(value: 7),
                ],
            ]
        #else
            let arrayParam: [[Int64]] = [
                [0, 1, 2, 3],
                [4, 5, 6, 7],
            ]
        #endif
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": arrayParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [[Any]]
        XCTAssertEqual(value.count, arrayParam.count)
        for i in 0..<arrayParam.count {
            XCTAssertEqual(value[i].count, arrayParam[i].count)
            for j in 0..<arrayParam[i].count {
                #if os(Linux)
                    XCTAssertEqual(
                        value[i][j] as! Int64,
                        arrayParam[i][j].value
                    )
                #else
                    XCTAssertEqual(value[i][j] as! Int64, arrayParam[i][j])
                #endif
            }
        }
        XCTAssertFalse(result.hasNext())
    }

    func testDictionaryParam() throws {
        #if os(Linux)
            let dictParam: [(String, LadybugInt64Wrapper)] = [
                ("1", LadybugInt64Wrapper(value: 1)),
                ("2", LadybugInt64Wrapper(value: 2)),
                ("3", LadybugInt64Wrapper(value: 3)),
            ]
        #else
            let dictParam: [(String, Int64)] = [
                ("1", 1),
                ("2", 2),
                ("3", 3),
            ]
        #endif
        try basicParamTestHelper(dictParam)
    }

    func testDictionaryParamNested() throws {
        let dictParam: [(String, [(String, String)])] = [
            ("1", [("a", "A")]),
            ("2", [("b", "B")]),
            ("3", [("c", "C")]),
        ]
        try basicParamTestHelper(dictParam)
    }

    func testDictionaryParamWithUnsupportedType() throws {
        let dictParam: [(String, Any)] = [
            ("1", try! NSRegularExpression(pattern: ".*", options: []))
        ]
        let preparedStatement = try conn.prepare("RETURN $1")
        do {
            _ = try conn.execute(preparedStatement, ["1": dictParam])
            XCTFail("Expected error for unsupported type")
        } catch let error as LadybugError {
            XCTAssertTrue(error.message.contains("Unsupported Swift type"))
        }
    }

    func testDictionaryWithMixedTypesParam() throws {
        // Since Ladybug 0.17, mixed-type values are coerced to a common type
        // (here STRING) instead of raising an error.
        #if os(Linux)
            let dictParam: [(String, Any)] = [
                ("1", "One"),
                ("2", "Two"),
                ("3", "Three"),
                ("4", LadybugInt64Wrapper(value: 4)),
            ]
        #else
            let dictParam: [(String, Any)] = [
                ("1", "One"),
                ("2", "Two"),
                ("3", "Three"),
                ("4", 4),
            ]
        #endif
        let preparedStatement = try conn.prepare("RETURN $1")
        let result = try conn.execute(preparedStatement, ["1": dictParam])
        XCTAssertTrue(result.hasNext())
        let tuple = try result.getNext()!
        let value = try tuple.getValue(0) as! [(String, Any)]
        XCTAssertEqual(value.count, dictParam.count)
        let expected: [(String, String)] = [
            ("1", "One"), ("2", "Two"), ("3", "Three"), ("4", "4"),
        ]
        for i in 0..<expected.count {
            XCTAssertEqual(value[i].0, expected[i].0)
            XCTAssertEqual(value[i].1 as! String, expected[i].1)
        }
        XCTAssertFalse(result.hasNext())
    }
}
