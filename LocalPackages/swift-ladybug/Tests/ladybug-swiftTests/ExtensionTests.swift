//
//  swift-ladybug
//  https://github.com/LadybugDB/swift-ladybug
//
//  Copyright © 2023 - 2025 Kùzu Inc.
//  This code is licensed under MIT license (see LICENSE for details)
import Foundation
import XCTest

@testable import Ladybug

final class ExtensionTests: XCTestCase {
    func testGds() async throws {
        #if os(iOS)
            throw XCTSkip("ALGO extension installation is not available on iOS simulator")
        #endif

        func normalize(_ rows: [[String]]) -> [[String]] {
            return
                rows
                .map { $0.sorted() }
                .sorted { $0.lexicographicallyPrecedes($1) }
        }

        let systemConfig = SystemConfig(
            bufferPoolSize: 256 * 1024 * 1024,
            maxNumThreads: 4,
            enableCompression: true,
            readOnly: false,
            maxDBSize: 1024 * 1024 * 1024,
            autoCheckpoint: true,
            checkpointThreshold: UInt64.max
        )
        let db = try Ladybug.Database(":memory:", systemConfig)
        let conn = try Ladybug.Connection(db)
        // Prebuilt liblbug is the default (LBUG_USE_PREBUILT=0 opts into a
        // from-source build), so this matches the Package.swift default.
        if ProcessInfo.processInfo.environment["LBUG_USE_PREBUILT"] != "0" {
            do {
                _ = try conn.query("INSTALL ALGO;")
                _ = try conn.query("LOAD EXTENSION ALGO;")
            } catch let error as LadybugError
                where error.message.contains("Failed to load library")
            {
                // The published ALGO extension binary for this Ladybug version
                // cannot be loaded (e.g. missing libnetworkit in the upstream
                // artifact). That is environmental, not a Swift binding failure,
                // so skip instead of failing. Any other error still fails.
                throw XCTSkip(
                    "ALGO extension binary cannot be loaded: \(error.message)"
                )
            }
        }
        _ = try conn.query(
            "CREATE NODE TABLE Node(id STRING PRIMARY KEY);"
        )
        _ = try conn.query(
            "CREATE REL TABLE Edge(FROM Node to Node, id INT64);"
        )
        _ = try conn.query(
            """
            CREATE (u0:Node {id: 'A'}),
                   (u1:Node {id: 'B'}),
                   (u2:Node {id: 'C'}),
                   (u3:Node {id: 'D'}),
                   (u4:Node {id: 'E'}),
                   (u5:Node {id: 'F'}),
                   (u6:Node {id: 'G'}),
                   (u7:Node {id: 'H'}),
                   (u8:Node {id: 'I'}),
                   (u0)-[:Edge {id:0}]->(u1),
                   (u1)-[:Edge {id:1}]->(u2),
                   (u5)-[:Edge {id:2}]->(u4),
                   (u6)-[:Edge {id:3}]->(u4),
                   (u6)-[:Edge {id:4}]->(u5),
                   (u6)-[:Edge {id:5}]->(u7),
                   (u7)-[:Edge {id:6}]->(u4),
                   (u6)-[:Edge {id:7}]->(u5)
            """
        )
        _ = try conn.query("CALL project_graph('Graph', ['Node'], ['Edge']);")
        let result = try conn.query(
            "CALL weakly_connected_components('Graph') RETURN group_id, collect(node.id);"
        )
        var rows: [[String]] = []
        for row in result {
            let rowValue = try row.getValue(1) as! [String]
            rows.append(rowValue)
        }
        let groundTruth: [[String]] = [
            ["I"], ["D"], ["B", "C", "A"], ["G", "F", "H", "E"],
        ]
        XCTAssertEqual(normalize(groundTruth), normalize(rows))
    }
}
