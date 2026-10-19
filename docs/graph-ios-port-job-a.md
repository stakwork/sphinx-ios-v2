# Personal knowledge graph: iOS port, Job A (local store)

## (a) Base
- iOS repo: branch `tt/feature/graph-db`, HEAD `91bec2ab1880216f963fe821ec9d14252690576d` (confirmed). Nothing committed/pushed.
- Mac source: `stakwork/sphinx-mac-v2` master `203a58ff` (fetched into the local clone, exported with `git archive` to /tmp; the clone's working tree was not touched).

## (b) Ported files (full diffs in `graph-ios-port-job-a-diffs.md`)
| Mac path (`com.stakwork.sphinx.desktop/...`) | iOS path | Changes vs Mac |
|---|---|---|
| Managers/Graph/GraphStore.swift | sphinx/Managers/Graph/ | none (byte-identical) |
| Managers/Graph/GraphOperation.swift | sphinx/Managers/Graph/ | none |
| Managers/Graph/GraphJournalService.swift | sphinx/Managers/Graph/ | none |
| Managers/Graph/LadybugGraphStore.swift | sphinx/Managers/Graph/ | One hunk, `defaultFileURL()` only: path is `<Application Support>/Graph/graph.lbug` (Mac: `.../Sphinx/Graph/...`, the "Sphinx" component only matched Mac's existing convention; iOS App Support is already per-app); added explicit `createDirectory(withIntermediateDirectories: true)` for the Graph dir; doc comment says private container, NOT the app group. `open()` still also creates the directory. |
| Managers/Graph/GraphClientIdProvider.swift | sphinx/Managers/Graph/ | none (`UserData.sharedInstance.accountUUID` exists on iOS, UserData.swift:49, same implementation) |
| Managers/Graph/GraphIdentifiers.swift | sphinx/Managers/Graph/ | none: UUIDv5 derivation byte-identical (namespace, `"<Type>:<normalized>"`, `"<src>:<rel>:<dst>"`) |
| Managers/Graph/PersonalGraph.swift | sphinx/Managers/Graph/ | none |
| Managers/Graph/GraphReadQueries.swift | sphinx/Managers/Graph/ | none. **Extra file, truly required**: `GraphStore` protocol read API, `LadybugGraphStore` and `InMemoryGraphStore` use `GraphNodeRecord/GraphNeighborhood/GraphRankedNode/GraphReadQueries` |
| Managers/Graph/GraphRecall.swift | sphinx/Managers/Graph/ | none. **Extra file, required**: `GraphJournalService.rankedNodes` calls `GraphRecallRanking.sort`, defined here. The whole file was ported verbatim (it also holds `GraphRecallSource` and the pure `GraphRecall` summary/tool-output formatters, depends only on GraphIdentifiers/ReadQueries). Not wired anywhere. Job B should keep it as is. Alternative if unwanted: move `GraphRecallRanking` out and delete the file. |
| CoreData/GraphJournalEntry/GraphJournalEntry+CoreDataClass.swift | sphinx/Core Data/GraphJournalEntry/ | none |
| CoreData/GraphJournalEntry/GraphJournalEntry+CoreDataProperties.swift | sphinx/Core Data/GraphJournalEntry/ | none (layout matches `Data Sync`: Class + Properties) |
| desktopTests/InMemoryGraphStore.swift | sphinxTests/Graph/ | header comment; `@testable import Sphinx` -> `@testable import sphinx` |
| desktopTests/GraphJournalServiceTests.swift (9 tests) | sphinxTests/Graph/ | header comment; `@testable import sphinx`; momd name `com_stakwork_sphinx_desktop` -> `sphinx` |
| desktopTests/GraphExtractionTests.swift (ID tests only) | sphinxTests/Graph/GraphIdentifiersTests.swift | new file containing only the 6 ID tests (namespace, node vectors, normalization, type-in-id, edge vectors, v5 version/variant), same expected UUIDs; I recomputed the node vectors and namespace with python `uuid5` + NFKC: all match |

Not ported (as instructed): GraphExtraction.swift, GraphExtractionPolicy.swift.

Other modified files:
- `sphinx/AppDelegate.swift`: `PersonalGraph.startInBackground()` right after `AppLogger.shared.start()` in `didFinishLaunchingWithOptions`.
- `sphinx/Configuration/UserData.swift`: `PersonalGraph.destroyStoreInBackground()` appended at end of `clearData()`.
- `sphinx/Core Data/sphinx.xcdatamodeld/sphinx 59.xcdatamodel/contents` (new), `.xccurrentversion` -> `sphinx 59.xcdatamodel`.
- `sphinx.xcodeproj/project.pbxproj` (see below).

### pbxproj registration
Project uses explicit references (no file-system-synchronized groups). Added 15 PBXFileReference + 15 PBXBuildFile (+ model ref), 3 PBXGroups (Managers/Graph, Core Data/GraphJournalEntry, sphinxTests/Graph) and group children entries. App sources (9 + 2 CoreData) are in the `sphinx` target Sources phase `4779F15A...` only; the 3 test files only in `sphinxTests` Sources phase `4779F171...`. `sphinx 59.xcdatamodel` added to the XCVersionGroup children and set as `currentVersion`. The extension Sources phase (`CE677B6D...`) is untouched. Ids are random 24-hex, verified unused/unique. Script check: braces/parens balance, no duplicate definitions, every new id referenced at least twice.

## Core Data model
`GraphJournalEntry` copied verbatim from Mac model 14 (clientId String non-optional default "", entityId UUID optional, opType Int16 default 0, payload Binary optional, schemaVersion Int16 default 1, seq Int64 default 0, timestamp Date optional, fetch index `byClientSeq` (clientId, seq), no uniqueness constraints, `codeGenerationType="none"`). Note: iOS's existing entities omit the attribute (also manual); I kept Mac's explicit `none`. The Swift properties are non-optional while entityId/payload/timestamp are optional in the model (as on Mac).
Mac model used `usedWithCloudKit="YES"` in its header; iOS header (58) kept unchanged.

## (c) Mac vs iOS differences found
- Module name `sphinx` (iOS) vs `Sphinx` (Mac); model name `sphinx` vs `com_stakwork_sphinx_desktop`.
- `clearData()` is `@MainActor` on Mac, not on iOS; Mac also calls `resetSignup`/strut key removal (unrelated).
- Mac `CoreDataManager.clearCoreDataStore` wraps in `performAndWait`; iOS doesn't (iOS CoreDataManager.swift:63-66).
- Mac deployment target macOS 14.x; iOS app 17.0 (unchanged; extension is 15.0, never links the graph code). `performAndWait` generic-return is iOS 15+, fine.
- Both use Swift 6.0 language mode; no code adaptation needed.

## (d) CoreDataManager findings
`sphinx/Core Data/CoreDataManager.swift`: line 21 `NSPersistentContainer(name: "sphinx")`, lines 23-27 plain `loadPersistentStores` with no `NSPersistentStoreDescription` options (so default `shouldMigrateStoreAutomatically` / `shouldInferMappingModelAutomatically` = true: lightweight migration; adding an entity is lightweight-compatible). A grep over `sphinx/` and `SphinxNotificationExtensionService/` for `NSMigratePersistentStoresAutomatically`, `NSInferMappingModelAutomatically`, mapping models, `momd`, `NSPersistentStoreCoordinator`, `persistentStoreDescriptions`, or version-name checks found nothing. The only hardcoded model name is the container name "sphinx" (line 21), which resolves to `sphinx.momd` and its current version; unaffected. Tests (`SnapshotIdentityTests`, `LiveCallBanner*`) look up `sphinx.momd` and load the current version: fine. The extension compiles `sphinx.xcdatamodeld` (Sources entry `CE67901F...`), so it also gets the new entity in its compiled model, but no class, no Ladybug, and it never uses `CoreDataManager` (no Swift reference in the extension dir).
`clearCoreDataStore` (line 63-66) -> `NSManagedObjectContext.deleteAllObjects()` (NSManagedObjectContext.swift:18-24) iterates ALL entities in the model, so it deletes `GraphJournalEntry` rows automatically, same as Mac (Mac's `destroyStoreInBackground` does not touch the journal either: it only calls `service.destroyStore()`, which deletes Ladybug files; journal wiped by Core Data itself). Nothing extra needed.

## (e) Launch wiring / clearData decision
- `PersonalGraph.startInBackground()` does `Task.detached(priority: .utility) { try await service.start() }`; `GraphJournalService.start()` hops onto its own serial `DispatchQueue(label: "com.stakwork.sphinx.graph", qos: .utility)` via `onQueue`; `LadybugGraphStore.open/close/reset/destroy/perform/snapshot` and the service's apply/rebuild have `precondition(!Thread.isMainThread)`. So Ladybug open and journal replay never run on main. What does run on the calling (main) thread: the first access of `PersonalGraph.service` (static let init): `CoreDataManager.sharedManager.persistentContainer` (lazy; stores are loaded synchronously here, including the one-time lightweight migration to model 59, if nothing touched it earlier) and `defaultFileURL()` (directory create). The app already loads Core Data on main at launch elsewhere, and migration is small, but this is the one main-thread cost.
- `destroyStoreInBackground()` is a plain (non-isolated) static func using `Task.detached`; it needs nothing main-actor. So I did NOT make iOS `clearData()` `@MainActor`; it can be called from any thread (callers: InitialWelcomeViewController.swift:21, MainCoordinator.swift:39). The static `service` is initialized in `didFinishLaunching`, and Swift static lets are thread-safe in any case. Ordering: clearData wipes Core Data first, then queues the file delete on the service queue; a concurrent `apply` after that finds the store closed (`storeNotOpen`) and per Mac design rebuilds from the (empty) journal.

## (f) Dependency check
- `LocalPackages/swift-ladybug` (product `Ladybug`) is referenced in project.pbxproj only by: the app target `sphinx` (packageProductDependencies + Frameworks phase `4779F15B`) and the local package reference. The extension (`CE677B70`) has neither a package dependency nor a Frameworks entry; the extension sources have no `Ladybug` text. sphinxTests has no direct link; it reaches Ladybug through the host app via `@testable import sphinx`.
- `import Ladybug` in LadybugGraphStore.swift matches the product/target name `Ladybug` in Package.swift (and the Mac code imports it the same way). API used (`Database`, `Connection`, `query`, `prepare`, `execute`, `getValue`) is identical to Mac, assumed the same package version: not diffed against Mac's package.

## (g) NOT verified / caveats
- **Not compiled, no tests run**: no Xcode/macOS/swiftc here. Only verified: XML well-formedness of the new model (python), pbxproj structure (script), UUID vectors (python recomputation).
- No runtime check of Ladybug on a real device/simulator, nor of the real-Ladybug test (`testRealLadybugRebuildAfterDeletedAndCorruptedFile`) in the iOS test host (it runs inside the app host; the first Ladybug open in the test host happens in the hosted app process).
- iOS data protection: Application Support default is `completeUntilFirstUserAuthentication`. If the app launches in the background before first unlock, `open()` may fail and `start()` takes the "rebuild" path, which deletes the file. Core Data is protected the same way, so rebuild would also fail; the file would be recreated on the next launch. Not changed (port, not redesign).
- The `.lbug` file is not excluded from iCloud/device backup (same as Mac behavior of not caring); it is a rebuildable cache, may be worth `isExcludedFromBackup` later.
- Xcode may reformat/reorder pbxproj on next open; codeGenerationType: explicit `none` vs the omitted attribute on other iOS entities.
- `GraphRecall.swift` was ported only because of `GraphRecallRanking` (see table).
