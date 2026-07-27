// Config.swift
// SphinxErrorReporter

import Foundation

/// Configuration for the SphinxErrorReporter SDK.
/// All values are injected — the SDK never reads from UserDefaults, app singletons, or Info.plist.
public struct SphinxErrorReporterConfig {
    /// Base URL of the Hive instance (e.g. `https://hive.sphinx.chat/api`). The SDK will POST to `<hiveBaseURL>/webhook/errors`.
    public let hiveBaseURL: URL
    /// Hive ingest API key (`hive_...`). Sent as `Authorization: Bearer` and as `x-api-key`.
    public let ingestKey: String
    /// Default repository (org/name, e.g. `stakwork/sphinx-ios-v2`). Used when no per-capture override is given.
    public let mainRepo: String
    /// Optional deployment environment label (e.g. `"production"`, `"staging"`).
    public let environment: String?
    /// Optional release version string. Used server-side for source-link resolution when `commitSha` is absent.
    public let release: String?
    /// Optional git commit SHA. Takes precedence over `release` for server-side source linking.
    public let commitSha: String?
    /// When `true`, the SDK logs lifecycle boundaries to stdout. Off by default. Never logs payload contents.
    public let debug: Bool

    public init(
        hiveBaseURL: URL,
        ingestKey: String,
        mainRepo: String,
        environment: String? = nil,
        release: String? = nil,
        commitSha: String? = nil,
        debug: Bool = false
    ) {
        self.hiveBaseURL = hiveBaseURL
        self.ingestKey = ingestKey
        self.mainRepo = mainRepo
        self.environment = environment
        self.release = release
        self.commitSha = commitSha
        self.debug = debug
    }
}

// Module-level alias so internal files and tests can still write `Config`.
public typealias Config = SphinxErrorReporterConfig
