# Context

## Swift 6 Concurrency Compliance

All Swift code in this repository should follow Swift 6 concurrency conventions:

- **Concurrency safety**: prefer `async`/`await` over completion handlers or manual `DispatchQueue` juggling where feasible.
- **Actor isolation**: use `@MainActor` annotations on UI-facing types/methods; use explicit actor boundaries for shared mutable state instead of locks or `DispatchSemaphore` where appropriate.
- **Sendable conformance**: types crossing concurrency boundaries should conform to `Sendable`. Use `@unchecked Sendable` only when truly justified, and always include a comment explaining why.
- **No data races**: avoid shared mutable state across actors/tasks without proper isolation; do not capture non-`Sendable` types in `Task { }` closures; avoid unstructured concurrency that could cause races.
- **Strict concurrency checking**: write code as if `SWIFT_STRICT_CONCURRENCY=complete` is enabled — it should compile cleanly without warnings about actor isolation, sendability, or non-isolated access.

## Swift File Registration

`sphinx-ios-v2` is a Swift/Xcode project with source files located under `sphinx/`. Any new `.swift` file added to the project **must** have a corresponding entry in `sphinx.xcodeproj/project.pbxproj`. Specifically:

1. **`PBXFileReference`** — add an entry for the new file so Xcode knows it exists on disk.
2. **`PBXBuildFile`** — add an entry linking the file to the target's Sources build phase so it gets compiled.
3. **Group membership** — place the file in the correct `PBXGroup` so it appears in the right folder in Xcode's navigator.
4. **Target membership check** — verify the file is added to the correct target(s): main app target, test target, or extension target, as appropriate. Do not add app-only code to a test target or vice versa.

Failing to register a file in `project.pbxproj` means Xcode will not compile it, even if it exists on disk.
