# Job A: diffs Mac (stakwork/sphinx-mac-v2 @ 203a58ff) -> iOS

Generated with `diff -u`. Empty diff = byte-identical copy.

## Managers/Graph/GraphStore.swift

```diff
```

## Managers/Graph/GraphOperation.swift

```diff
```

## Managers/Graph/GraphJournalService.swift

```diff
```

## Managers/Graph/LadybugGraphStore.swift

```diff
@@ -27,25 +27,23 @@
         self.fileURL = fileURL
     }
 
-    /// `<Application Support>/Sphinx/Graph/graph.lbug`. The app is sandboxed (see
-    /// entitlements), so Application Support resolves inside the app's own
-    /// container. No App Group or shared location is used.
+    /// `<Application Support>/Graph/graph.lbug`. Application Support resolves inside the
+    /// app's own sandbox container (private to the main app). NOT the App Group container
+    /// (group.com.gl.sphinx.v2): the notification extension must never see or open this file.
     ///
-    /// "Sphinx" is a literal, not `Bundle.main.bundleIdentifier` -- every other
-    /// piece of local app data (AppLogger's log file, Core Data's own default
-    /// container directory) already lives under `Application Support/Sphinx/`,
-    /// and this must match that convention, not invent a second one next to it.
+    /// Unlike the Mac app there is no extra "Sphinx" path component: an iOS app's
+    /// Application Support directory is already per-app.
     static func defaultFileURL() throws -> URL {
-        let support = try FileManager.default.url(
+        let fm = FileManager.default
+        let support = try fm.url(
             for: .applicationSupportDirectory,
             in: .userDomainMask,
             appropriateFor: nil,
             create: true
         )
-        return support
-            .appendingPathComponent("Sphinx", isDirectory: true)
-            .appendingPathComponent("Graph", isDirectory: true)
-            .appendingPathComponent(fileName)
+        let directory = support.appendingPathComponent("Graph", isDirectory: true)
+        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
+        return directory.appendingPathComponent(fileName)
     }
 
     // MARK: GraphStore
```

## Managers/Graph/GraphClientIdProvider.swift

```diff
```

## Managers/Graph/GraphIdentifiers.swift

```diff
```

## Managers/Graph/PersonalGraph.swift

```diff
```

## Managers/Graph/GraphReadQueries.swift

```diff
```

## Managers/Graph/GraphRecall.swift

```diff
```

## GraphJournalEntry+CoreDataClass.swift

```diff
```

## GraphJournalEntry+CoreDataProperties.swift

```diff
```

## tests/InMemoryGraphStore.swift

```diff
@@ -1,12 +1,12 @@
 //
 //  InMemoryGraphStore.swift
-//  com.stakwork.sphinx.desktopTests
+//  sphinxTests
 //
 //  Fake GraphStore for journal tests. Mirrors the contract of the Ladybug adapter:
 //  atomic batches, idempotent upserts, node delete removes incident edges.
 //
 import Foundation
-@testable import Sphinx
+@testable import sphinx
 
 final class InMemoryGraphStore: GraphStore, @unchecked Sendable {
 
```

## tests/GraphJournalServiceTests.swift

```diff
@@ -1,6 +1,6 @@
 //
 //  GraphJournalServiceTests.swift
-//  com.stakwork.sphinx.desktopTests
+//  sphinxTests
 //
 //  Journal/apply/tombstone/rebuild coverage. The journal uses an in-memory Core Data
 //  store; most tests use the in-memory fake GraphStore, the rebuild test also runs
@@ -9,7 +9,7 @@
 
 import XCTest
 import CoreData
-@testable import Sphinx
+@testable import sphinx
 
 private struct FixedClientId: GraphClientIdProviding {
     let id: String
@@ -24,7 +24,7 @@
     override func setUpWithError() throws {
         try super.setUpWithError()
         let bundle = Bundle(for: GraphJournalEntry.self)
-        let modelURL = try XCTUnwrap(bundle.url(forResource: "com_stakwork_sphinx_desktop", withExtension: "momd"))
+        let modelURL = try XCTUnwrap(bundle.url(forResource: "sphinx", withExtension: "momd"))
         let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
         container = NSPersistentContainer(name: "GraphJournalTests", managedObjectModel: model)
         let description = NSPersistentStoreDescription()
```

## Core Data model: iOS 'sphinx 58' -> 'sphinx 59'

```diff
@@ -129,6 +129,19 @@
         <attribute name="key" optional="YES" attributeType="String"/>
         <attribute name="value" optional="YES" attributeType="String"/>
     </entity>
+    <entity name="GraphJournalEntry" representedClassName="GraphJournalEntry" syncable="YES" codeGenerationType="none">
+        <attribute name="clientId" optional="NO" attributeType="String" defaultValueString=""/>
+        <attribute name="entityId" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
+        <attribute name="opType" optional="NO" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
+        <attribute name="payload" optional="YES" attributeType="Binary"/>
+        <attribute name="schemaVersion" optional="NO" attributeType="Integer 16" defaultValueString="1" usesScalarValueType="YES"/>
+        <attribute name="seq" optional="NO" attributeType="Integer 64" defaultValueString="0" usesScalarValueType="YES"/>
+        <attribute name="timestamp" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
+        <fetchIndex name="byClientSeq">
+            <fetchIndexElement property="clientId" type="Binary" order="ascending"/>
+            <fetchIndexElement property="seq" type="Binary" order="ascending"/>
+        </fetchIndex>
+    </entity>
     <entity name="LSat" representedClassName="LSat" syncable="YES">
         <attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
         <attribute name="identifier" attributeType="String"/>
```
