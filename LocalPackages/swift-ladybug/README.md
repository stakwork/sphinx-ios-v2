# swift-ladybug (vendored)

This is a vendored, source-mode copy of [swift-ladybug](https://github.com/LadybugDB/swift-ladybug),
pinned to upstream commit [`c071a7c`](https://github.com/LadybugDB/swift-ladybug/commit/c071a7ca931241651c4d1bbc19c8780401f58c3f).

## Why this is vendored instead of a remote package dependency

swift-ladybug has no prebuilt binary for iOS — only macOS/Linux/Windows archives
are published (tracked upstream in
[LadybugDB/swift-ladybug#14](https://github.com/LadybugDB/swift-ladybug/issues/14)).
The only way to build it for iOS is source mode, which requires generating a
`Sources/cxx-ladybug/` tree that upstream deliberately `.gitignore`s and only
ever produces via a local full clone + CMake build — a plain
`.package(url:)` checkout (a "package checkout", not a "full clone") can't
produce it. See upstream's own README: *"Source builds require the
submodules and only work from a full clone, not from a package checkout."*

So: this directory **is** that already-generated output, produced once and
committed directly into this repo as a local Swift package, exactly the way
[`SphinxErrorReporter`](../SphinxErrorReporter) already is. No prebuilt
binary, no runtime dylib, no codesigning — it compiles straight into the app
like any other local package target.

## What's here

- `Sources/cxx-ladybug/` — the generated C++ source tree (via
  `collect-ladybug-src.py`, see below)
- `Sources/Ladybug/` — the upstream Swift wrapper, unmodified
- `Package.swift` — upstream's generated manifest, with the prebuilt-mode
  branch removed (source mode is the only mode we use) and the
  `LBUG_ROOT_DIRECTORY` debug define pointed at this path instead of the
  scratch directory it was originally generated in

## Requirements for anyone consuming this

The app's `IPHONEOS_DEPLOYMENT_TARGET` must be **iOS 17.0+** — this package
declares that as its platform minimum, and real usage (not just an unused
import) fails to compile below it.

## Regenerating / bumping the upstream version

This is a snapshot, not a live dependency — bumping to a newer upstream
commit means redoing the generation by hand:

```sh
git clone https://github.com/LadybugDB/swift-ladybug.git /tmp/swift-ladybug-fullclone
cd /tmp/swift-ladybug-fullclone
git checkout <new upstream commit>
git submodule update --init Sources/LadybugCpp

# Must use a *native* arm64 toolchain end to end. On a machine with both an
# Apple Silicon and an Intel/Rosetta Homebrew install, an x86_64 `cmake`
# (likely at /usr/local/bin/cmake) runs under Rosetta and misreports the
# host as amd64 -- this silently pulls in an AVX2-only SIMD source file
# (simd_filter_avx2.cpp) that cannot compile on arm64 at all. Confirm:
file $(which cmake)   # must say "arm64", not "x86_64"
# If it's x86_64: brew install cmake ninja   (via the arm64 /opt/homebrew brew)

export PATH="/opt/homebrew/bin:$PATH"
export CMAKE_GENERATOR=Ninja
/usr/bin/python3 scripts/collect-ladybug-src/collect-ladybug-src.py
# Confirm it picked NEON, not AVX2:
grep "Query processor SIMD" <output above>   # must say "NEON filter kernels enabled"
```

Then:
1. Copy `Sources/cxx-ladybug/` and `Sources/Ladybug/` from the scratch clone
   over this directory's equivalents (replacing them entirely).
2. Copy the regenerated `Package.swift`, then reapply the same two edits
   described above (remove the prebuilt-mode ternary branch; fix the
   `LBUG_ROOT_DIRECTORY` define).
3. Sanity-build standalone first (`cd LocalPackages/swift-ladybug && swift
   build --product Ladybug -c release`) before touching the app project.
4. Rebuild and re-archive Sphinx itself to confirm nothing regressed.
