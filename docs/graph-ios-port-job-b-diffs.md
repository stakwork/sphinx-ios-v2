# Job B: diffs Mac (stakwork/sphinx-mac-v2 @ 203a58ff) -> iOS

Generated with `diff -u` (Mac vs iOS copy). Empty diff = byte-identical copy. Nothing was compiled or run.

## Managers/Graph/GraphExtraction.swift

```diff
```

- No changes: byte-identical (header comment already says `sphinx`). Uses only APIs also used by iOS `AIAgentManager.swift` (`generateText(model:system:messages:)`, `tool`/`TypedTool`, `ToolExecutionResult`, `ToolCallOptions`, `JSONValue`).

## Managers/Graph/GraphExtractionPolicy.swift

```diff
```

- No changes: byte-identical (header comment already says `sphinx`). Uses only APIs also used by iOS `AIAgentManager.swift` (`generateText(model:system:messages:)`, `tool`/`TypedTool`, `ToolExecutionResult`, `ToolCallOptions`, `JSONValue`).

## Managers/AI Agent/AIAgentManager+GraphExtraction.swift

```diff
```

- No changes: byte-identical (header comment already says `sphinx`). Uses only APIs also used by iOS `AIAgentManager.swift` (`generateText(model:system:messages:)`, `tool`/`TypedTool`, `ToolExecutionResult`, `ToolCallOptions`, `JSONValue`).

## Managers/AI Agent/AIAgentManager+GraphRecall.swift

```diff
```

- No changes: byte-identical (header comment already says `sphinx`). Uses only APIs also used by iOS `AIAgentManager.swift` (`generateText(model:system:messages:)`, `tool`/`TypedTool`, `ToolExecutionResult`, `ToolCallOptions`, `JSONValue`).

## desktopTests/GraphRecallTests.swift

```diff
--- /tmp/mac/com.stakwork.sphinx.desktopTests/GraphRecallTests.swift	2026-10-19 14:20:55.461425891 +0000
+++ sphinxTests/Graph/GraphRecallTests.swift	2026-10-19 14:21:51.194868879 +0000
@@ -1,6 +1,6 @@
 //
 //  GraphRecallTests.swift
-//  com.stakwork.sphinx.desktopTests
+//  sphinxTests
 //
 //  Recall (job 3): read API on the in-memory store, ranking, summary builder and tool output.
 //  The service-level ranking test uses an in-memory Core Data journal like GraphJournalServiceTests.
@@ -8,7 +8,7 @@
 
 import XCTest
 import CoreData
-@testable import Sphinx
+@testable import sphinx
 
 private struct FixedClientId: GraphClientIdProviding {
     func clientId() throws -> String { "client-A" }
@@ -196,7 +196,7 @@
 
     func testServiceRankingUsesJournalTimestamps() async throws {
         let bundle = Bundle(for: GraphJournalEntry.self)
-        let modelURL = try XCTUnwrap(bundle.url(forResource: "com_stakwork_sphinx_desktop", withExtension: "momd"))
+        let modelURL = try XCTUnwrap(bundle.url(forResource: "sphinx", withExtension: "momd"))
         let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
         let container = NSPersistentContainer(name: "GraphRecallTests", managedObjectModel: model)
 
```

- Header project name `com.stakwork.sphinx.desktopTests` -> `sphinxTests`.
- `@testable import Sphinx` -> `@testable import sphinx` (iOS module name).
- momd resource `com_stakwork_sphinx_desktop` -> `sphinx` (iOS Core Data model name). All 19 tests kept; `InMemoryGraphStore` is identical to Mac apart from header/import, nothing missing.

## desktopTests/GraphExtractionTests.swift

```diff
--- /tmp/mac/com.stakwork.sphinx.desktopTests/GraphExtractionTests.swift	2026-10-19 14:20:55.461425891 +0000
+++ sphinxTests/Graph/GraphExtractionTests.swift	2026-10-19 14:21:55.731058452 +0000
@@ -1,74 +1,16 @@
 //
 //  GraphExtractionTests.swift
-//  com.stakwork.sphinx.desktopTests
+//  sphinxTests
 //
-//  Pure tests (no network, no Core Data): deterministic ids with fixed vectors (the iOS
-//  port must reproduce them), extraction parsing, skip rules, privacy switch, op building.
-//  Vectors are also listed in docs/graph-extraction.md (computed with python uuid.uuid5).
+//  Pure tests (no network, no Core Data): extraction parsing, skip rules, privacy switch, op
+//  building. The 6 identifier-vector tests of the Mac file live in GraphIdentifiersTests.swift.
 //
 
 import XCTest
-@testable import Sphinx
+@testable import sphinx
 
 final class GraphExtractionTests: XCTestCase {
 
-    // MARK: IDs
-
-    func testNamespaceConstant() {
-        XCTAssertEqual(GraphIdentifiers.namespace.uuidString.lowercased(), "4dcb6314-9c48-5148-b515-af314187e2fa")
-    }
-
-    func testNodeIdVectors() {
-        let vectors: [(GraphNodeType, String, String)] = [
-            (.person, "Alice", "82522da3-8cb7-5883-91a7-5124738e74e8"),
-            (.person, "  ALICE   ", "82522da3-8cb7-5883-91a7-5124738e74e8"),
-            (.person, "Alice  Smith", "fde501d2-3812-5d61-b796-8655f9149734"),
-            (.place, "Paris", "2d0c2181-9fdc-5e0f-8f4a-b297ad6c25ad"),
-            (.place, "\u{FF30}\u{FF41}\u{FF52}\u{FF49}\u{FF53}", "2d0c2181-9fdc-5e0f-8f4a-b297ad6c25ad"),   // fullwidth "Paris"
-            (.thing, "\u{FB01}le cabinet", "ca9860c5-aca5-5c79-ac9f-7d51cc5ecaa0"),                           // "ﬁ" ligature
-            (.thing, "file cabinet", "ca9860c5-aca5-5c79-ac9f-7d51cc5ecaa0"),
-            (.person, "Jos\u{00E9} M\u{00FC}ller", "6a102b2d-7c6c-5059-acce-664621026118"),
-            (.person, "\u{5F20}\u{4F1F}", "b79b7fb2-7e3a-5cc5-85c4-bd5ed3c1b828"),
-            (.topic, "Machine\tLearning", "977b6346-1a8c-5872-9da1-45e97be0e49e")
-        ]
-        for (type, name, expected) in vectors {
-            XCTAssertEqual(GraphIdentifiers.nodeID(type: type, name: name).uuidString.lowercased(), expected, "\(type) \(name)")
-        }
-    }
-
-    func testNormalization() {
-        XCTAssertEqual(GraphIdentifiers.normalize("  Alice \n  SMITH\t"), "alice smith")
-        XCTAssertEqual(GraphIdentifiers.normalize("\u{FF21}\u{FF22}"), "ab")
-    }
-
-    func testTypeIsPartOfNodeId() {
-        XCTAssertNotEqual(
-            GraphIdentifiers.nodeID(type: .person, name: "Paris"),
-            GraphIdentifiers.nodeID(type: .place, name: "Paris")
-        )
-    }
-
-    func testEdgeIdVectors() {
-        let alice = GraphIdentifiers.nodeID(type: .person, name: "Alice")
-        let paris = GraphIdentifiers.nodeID(type: .place, name: "Paris")
-        let aliceSmith = GraphIdentifiers.nodeID(type: .person, name: "Alice Smith")
-        XCTAssertEqual(
-            GraphIdentifiers.edgeID(source: alice, destination: paris, relation: .livesIn).uuidString.lowercased(),
-            "1b123321-1220-53ec-8662-0714da9b4253"
-        )
-        XCTAssertEqual(
-            GraphIdentifiers.edgeID(source: aliceSmith, destination: alice, relation: .knows).uuidString.lowercased(),
-            "2a5ca767-5e7f-5eba-82f1-21c5cc9ec744"
-        )
-    }
-
-    func testUuidV5VersionAndVariant() {
-        let id = GraphIdentifiers.nodeID(type: .person, name: "Alice").uuidString.lowercased()
-        let parts = id.split(separator: "-")
-        XCTAssertTrue(parts[2].hasPrefix("5"))
-        XCTAssertTrue(["8", "9", "a", "b"].contains(String(parts[3].prefix(1))))
-    }
-
     // MARK: Parsing
 
     private let validJSON = """
```

- Header project name -> `sphinxTests`; `@testable import sphinx`.
- Removed the 6 identifier-vector tests (`testNamespaceConstant`, `testNodeIdVectors`, `testNormalization`, `testTypeIsPartOfNodeId`, `testEdgeIdVectors`, `testUuidV5VersionAndVariant`) and the `// MARK: IDs` heading: they are line-for-line the tests already in job A's `GraphIdentifiersTests.swift`. 15 of 21 tests remain.
- Header comment reworded accordingly.

## sphinx/Managers/AI Agent/AIAgentManager.swift (git diff)

```diff
diff --git a/sphinx/Managers/AI Agent/AIAgentManager.swift b/sphinx/Managers/AI Agent/AIAgentManager.swift
index 10a01783..5bcba2f9 100644
--- a/sphinx/Managers/AI Agent/AIAgentManager.swift	
+++ b/sphinx/Managers/AI Agent/AIAgentManager.swift	
@@ -463,6 +463,9 @@ final class AIAgentManager: @unchecked Sendable {
         // query_hive_graph's description — see buildQueryHiveGraphTool(ownerNickname:orgs:).
         let ownerNickname: String? = await MainActor.run { UserContact.getOwner()?.nickname }
         let cachedOrgs = AIAgentManager.cachedHiveOrgs()
+        // Per-turn system prompt: the constant systemPrompt stays FIRST and unchanged, the graph
+        // summary is appended after it ("" if the graph is empty/unavailable/slow; never fails the turn).
+        let turnSystemPrompt = systemPrompt + (await graphSummarySection())
 
         var tools: ToolSet = [
             "send_sphinx_message":     buildSendMessageTool().eraseToTool(),
@@ -498,7 +501,8 @@ final class AIAgentManager: @unchecked Sendable {
             "retry_task_workflow":     buildRetryTaskWorkflowTool().eraseToTool(),
             "archive_task":            buildArchiveTaskTool().eraseToTool(),
             "approve_proposal":        buildApproveProposalTool().eraseToTool(),
-            "reject_proposal":         buildRejectProposalTool().eraseToTool()
+            "reject_proposal":         buildRejectProposalTool().eraseToTool(),
+            "recall_personal_knowledge": buildRecallPersonalKnowledgeTool().eraseToTool()
         ]
         switch activeProvider {
         case .anthropic:
@@ -514,7 +518,7 @@ final class AIAgentManager: @unchecked Sendable {
             result = try await generateText(
                 model: model,
                 tools: tools,
-                system: systemPrompt,
+                system: turnSystemPrompt,
                 messages: conversationHistory,
                 stopWhen: [stepCountIs(10)]
             )
@@ -566,6 +570,16 @@ final class AIAgentManager: @unchecked Sendable {
         conversationHistory.append(.assistant(responseText))
         saveHistory()
         isProcessing = false
+
+        // Fire-and-forget: runs after the answer is returned, the user does not wait for it.
+        // The error path above returns earlier and never extracts.
+        scheduleGraphExtraction(
+            model: model,
+            userText: userText,
+            assistantText: responseText,
+            toolNames: allToolNames,
+            didFail: false
+        )
         return responseText
     }
 
```

- Per-turn `turnSystemPrompt = systemPrompt + (await graphSummarySection())` (placed after `cachedOrgs`, before `tools`); `systemPrompt` unchanged.
- `generateText(system:)` now gets `turnSystemPrompt`.
- `recall_personal_knowledge` tool added as last tools entry (trailing comma added to `reject_proposal`).
- `scheduleGraphExtraction(...)` between the final `isProcessing = false` and `return responseText`; early-exit and error paths unchanged (no extraction).

## sphinx/AppDelegate.swift (git diff)

```diff
diff --git a/sphinx/AppDelegate.swift b/sphinx/AppDelegate.swift
index 79017fdb..3538d4a1 100644
--- a/sphinx/AppDelegate.swift
+++ b/sphinx/AppDelegate.swift
@@ -79,6 +79,10 @@ class AppDelegate: UIResponder, UIApplicationDelegate {
         
         AppLogger.shared.start()
         
+        // Registers the default (ON) for the "Remember things from AI agent chats" setting so it
+        // is already true before anything reads it. Must run before the graph pipeline is used.
+        GraphExtractionSettings.registerDefaults()
+        
         // Opens the personal graph (Ladybug) off the main thread; never blocks launch.
         PersonalGraph.startInBackground()
         
```

- `GraphExtractionSettings.registerDefaults()` (default ON) before `PersonalGraph.startInBackground()`.

## sphinx/Scenes/Profile/ProfileViewController.swift (git diff)

```diff
diff --git a/sphinx/Scenes/Profile/ProfileViewController.swift b/sphinx/Scenes/Profile/ProfileViewController.swift
index 48e0116c..c07557f7 100644
--- a/sphinx/Scenes/Profile/ProfileViewController.swift
+++ b/sphinx/Scenes/Profile/ProfileViewController.swift
@@ -41,6 +41,10 @@ class ProfileViewController: NewKeyboardHandlerViewController {
     @IBOutlet weak var changePINContainerView: UIView!
     @IBOutlet weak var setGithubPATContainerView: UIView!
     @IBOutlet weak var configureAIAgentContainerView: UIView!
+    
+    // Code-built row under the AI Agent row (not in the storyboard); see configureGraphExtractionRow().
+    private var graphExtractionContainerView: UIView?
+    private var graphExtractionSwitch: UISwitch?
     @IBOutlet weak var uploadingLabel: UILabel!
     @IBOutlet weak var uploadLoadingWheel: UIActivityIndicatorView!
     @IBOutlet weak var contentScrollView: UIScrollView!
@@ -114,6 +118,7 @@ class ProfileViewController: NewKeyboardHandlerViewController {
         
         exportKeyButton.layer.cornerRadius = exportKeyButton.frame.height / 2
         
+        configureGraphExtractionRow()
         setShadows()
         configureFields()
         configureProfile()
@@ -123,6 +128,68 @@ class ProfileViewController: NewKeyboardHandlerViewController {
         updateTimezoneLabel()
     }
     
+    /// Adds the "Remember things from AI agent chats" row directly under the AI Agent row.
+    /// The storyboard's row container has a fixed 590pt height constraint and the AI Agent row is
+    /// its last subview, so the container height is grown by the new row + 10pt gap. If that
+    /// constraint can't be found (storyboard changed) the row is NOT added, so layout never breaks.
+    private func configureGraphExtractionRow() {
+        guard graphExtractionContainerView == nil,
+              let rowsContainer = configureAIAgentContainerView.superview,
+              let heightConstraint = rowsContainer.constraints.first(where: {
+                  $0.firstItem === rowsContainer && $0.secondItem == nil &&
+                  $0.firstAttribute == .height && $0.constant == 590
+              }) else { return }
+        
+        let rowHeight: CGFloat = 80
+        let gap: CGFloat = 10
+        
+        let row = UIView()
+        row.translatesAutoresizingMaskIntoConstraints = false
+        row.backgroundColor = UIColor.Sphinx.Body
+        
+        let label = UILabel()
+        label.translatesAutoresizingMaskIntoConstraints = false
+        label.text = "Remember things from AI agent chats"
+        label.font = UIFont(name: "Roboto-Regular", size: 17.0)
+        label.textColor = UIColor.Sphinx.Text
+        label.numberOfLines = 0
+        
+        let toggle = UISwitch()
+        toggle.translatesAutoresizingMaskIntoConstraints = false
+        toggle.onTintColor = UIColor.Sphinx.PrimaryBlue
+        toggle.isOn = GraphExtractionSettings.isEnabled()
+        toggle.setContentHuggingPriority(.required, for: .horizontal)
+        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
+        toggle.addTarget(self, action: #selector(graphExtractionSwitchChanged(_:)), for: .valueChanged)
+        
+        row.addSubview(label)
+        row.addSubview(toggle)
+        rowsContainer.addSubview(row)
+        
+        // Same 30pt side inset the switch rows use inside their card.
+        NSLayoutConstraint.activate([
+            row.leadingAnchor.constraint(equalTo: rowsContainer.leadingAnchor),
+            row.trailingAnchor.constraint(equalTo: rowsContainer.trailingAnchor),
+            row.topAnchor.constraint(equalTo: configureAIAgentContainerView.bottomAnchor, constant: gap),
+            row.heightAnchor.constraint(equalToConstant: rowHeight),
+            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 30),
+            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
+            toggle.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 24.5),
+            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -30),
+            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor)
+        ])
+        
+        heightConstraint.constant += rowHeight + gap
+        
+        graphExtractionContainerView = row
+        graphExtractionSwitch = toggle
+    }
+    
+    /// Gates ONLY extraction (writes to the personal graph); recall/summary keep working.
+    @objc private func graphExtractionSwitchChanged(_ sender: UISwitch) {
+        GraphExtractionSettings.setEnabled(sender.isOn)
+    }
+    
     override func viewDidAppear(_ animated: Bool) {
         super.viewDidAppear(animated)
         setupMemoryManagement()
@@ -136,6 +203,7 @@ class ProfileViewController: NewKeyboardHandlerViewController {
         exportKeysContainer.addShadow(location: VerticalLocation.center, color: UIColor.black, opacity: 0.2, radius: 2.0)
         changePINContainerView.addShadow(location: VerticalLocation.center, color: UIColor.black, opacity: 0.2, radius: 2.0)
         configureAIAgentContainerView.addShadow(location: VerticalLocation.center, color: UIColor.black, opacity: 0.2, radius: 2.0)
+        graphExtractionContainerView?.addShadow(location: VerticalLocation.center, color: UIColor.black, opacity: 0.2, radius: 2.0)
         
         setStatusBarColor()
     }
```

- Code-built row (no storyboard edit) under the AI Agent row: Body background, Roboto-Regular 17 `Text` label, `UISwitch` with `PrimaryBlue` onTintColor (same as the storyboard switch rows), 80pt high, shadow added in `setShadows()` so it follows theme changes.
- The row is added to `configureAIAgentContainerView.superview` (the 590pt container, whose last subview is the AI row; nothing is below it). The height constraint is found at runtime (`firstAttribute == .height`, `constant == 590`) and grown by 90 (80 + 10 gap). If it is not found, the row is not added, so layout cannot break.
- Toggle writes `GraphExtractionSettings.setEnabled`; gates only extraction.
- Chosen over the SetupAIAgentViewController fallback because the safe runtime lookup was possible.

## project.pbxproj (git diff --stat)

```
 sphinx.xcodeproj/project.pbxproj | 24 ++++++++++++++++++++++++
 1 file changed, 24 insertions(+)
```

- 24 added lines: PBXBuildFile + PBXFileReference + group child + Sources entry for each of 6 files. App files in the `Graph` and `AI Agent` groups and the app target Sources phase (next to GraphRecall.swift / AIAgentManager+HiveGraphTool.swift); tests in the `sphinxTests/Graph` group and the sphinxTests Sources phase (next to GraphIdentifiersTests.swift). IDs random 24-hex, checked unused.
