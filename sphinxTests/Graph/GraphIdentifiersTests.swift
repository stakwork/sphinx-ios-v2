//
//  GraphIdentifiersTests.swift
//  sphinxTests
//
//  Pure tests (no network, no Core Data): deterministic UUIDv5 ids with fixed vectors.
//  Ported verbatim from the Mac GraphExtractionTests (identifier vector tests only); the
//  expected values are the Mac ones and must never change (iOS ids must equal Mac ids).
//  Vectors are also listed in docs/graph-extraction.md (computed with python uuid.uuid5).
//

import XCTest
@testable import sphinx

final class GraphIdentifiersTests: XCTestCase {

    // MARK: IDs

    func testNamespaceConstant() {
        XCTAssertEqual(GraphIdentifiers.namespace.uuidString.lowercased(), "4dcb6314-9c48-5148-b515-af314187e2fa")
    }

    func testNodeIdVectors() {
        let vectors: [(GraphNodeType, String, String)] = [
            (.person, "Alice", "82522da3-8cb7-5883-91a7-5124738e74e8"),
            (.person, "  ALICE   ", "82522da3-8cb7-5883-91a7-5124738e74e8"),
            (.person, "Alice  Smith", "fde501d2-3812-5d61-b796-8655f9149734"),
            (.place, "Paris", "2d0c2181-9fdc-5e0f-8f4a-b297ad6c25ad"),
            (.place, "\u{FF30}\u{FF41}\u{FF52}\u{FF49}\u{FF53}", "2d0c2181-9fdc-5e0f-8f4a-b297ad6c25ad"),   // fullwidth "Paris"
            (.thing, "\u{FB01}le cabinet", "ca9860c5-aca5-5c79-ac9f-7d51cc5ecaa0"),                           // "ﬁ" ligature
            (.thing, "file cabinet", "ca9860c5-aca5-5c79-ac9f-7d51cc5ecaa0"),
            (.person, "Jos\u{00E9} M\u{00FC}ller", "6a102b2d-7c6c-5059-acce-664621026118"),
            (.person, "\u{5F20}\u{4F1F}", "b79b7fb2-7e3a-5cc5-85c4-bd5ed3c1b828"),
            (.topic, "Machine\tLearning", "977b6346-1a8c-5872-9da1-45e97be0e49e")
        ]
        for (type, name, expected) in vectors {
            XCTAssertEqual(GraphIdentifiers.nodeID(type: type, name: name).uuidString.lowercased(), expected, "\(type) \(name)")
        }
    }

    func testNormalization() {
        XCTAssertEqual(GraphIdentifiers.normalize("  Alice \n  SMITH\t"), "alice smith")
        XCTAssertEqual(GraphIdentifiers.normalize("\u{FF21}\u{FF22}"), "ab")
    }

    func testTypeIsPartOfNodeId() {
        XCTAssertNotEqual(
            GraphIdentifiers.nodeID(type: .person, name: "Paris"),
            GraphIdentifiers.nodeID(type: .place, name: "Paris")
        )
    }

    func testEdgeIdVectors() {
        let alice = GraphIdentifiers.nodeID(type: .person, name: "Alice")
        let paris = GraphIdentifiers.nodeID(type: .place, name: "Paris")
        let aliceSmith = GraphIdentifiers.nodeID(type: .person, name: "Alice Smith")
        XCTAssertEqual(
            GraphIdentifiers.edgeID(source: alice, destination: paris, relation: .livesIn).uuidString.lowercased(),
            "1b123321-1220-53ec-8662-0714da9b4253"
        )
        XCTAssertEqual(
            GraphIdentifiers.edgeID(source: aliceSmith, destination: alice, relation: .knows).uuidString.lowercased(),
            "2a5ca767-5e7f-5eba-82f1-21c5cc9ec744"
        )
    }

    func testUuidV5VersionAndVariant() {
        let id = GraphIdentifiers.nodeID(type: .person, name: "Alice").uuidString.lowercased()
        let parts = id.split(separator: "-")
        XCTAssertTrue(parts[2].hasPrefix("5"))
        XCTAssertTrue(["8", "9", "a", "b"].contains(String(parts[3].prefix(1))))
    }
}
