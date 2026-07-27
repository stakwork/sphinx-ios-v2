// ErrorReport.swift
// SphinxErrorReporter

import Foundation

/// A single stack frame — exactly 4 possible keys matching Hive contract.
public struct Frame: Codable, Equatable {
    public let filename: String
    public let function: String?
    public let lineno: Int?
    public let inApp: Bool?

    public init(filename: String, function: String? = nil, lineno: Int? = nil, inApp: Bool? = nil) {
        self.filename = filename
        self.function = function
        self.lineno = lineno
        self.inApp = inApp
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case function = "function"
        case lineno
        case inApp
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(filename, forKey: .filename)
        try container.encodeIfPresent(function, forKey: .function)
        try container.encodeIfPresent(lineno, forKey: .lineno)
        try container.encodeIfPresent(inApp, forKey: .inApp)
    }
}

/// Matches the Hive `POST /api/webhook/errors` JSON payload exactly (camelCase).
/// `frames` and `fingerprint` are omitted from the output when nil (Hive ignores absent optional fields).
public struct ErrorReport: Codable {
    // MARK: - Required
    public let exceptionType: String
    public let message: String

    // MARK: - Optional
    public let stackTrace: String?
    public let frames: [Frame]?
    public let environment: String?
    public let release: String?
    public let commitSha: String?
    public let repository: String?
    public let requestContext: [String: AnyCodable]?
    public let metadata: [String: AnyCodable]?
    /// Omitted by default; only included when explicitly set.
    public let fingerprint: String?

    public init(
        exceptionType: String,
        message: String,
        stackTrace: String? = nil,
        frames: [Frame]? = nil,
        environment: String? = nil,
        release: String? = nil,
        commitSha: String? = nil,
        repository: String? = nil,
        requestContext: [String: Any]? = nil,
        metadata: [String: Any]? = nil,
        fingerprint: String? = nil
    ) {
        self.exceptionType = exceptionType
        self.message = message
        self.stackTrace = stackTrace
        self.frames = frames
        self.environment = environment
        self.release = release
        self.commitSha = commitSha
        self.repository = repository
        self.requestContext = requestContext.map { $0.mapValues { AnyCodable($0) } }
        self.metadata = metadata.map { $0.mapValues { AnyCodable($0) } }
        self.fingerprint = fingerprint
    }

    enum CodingKeys: String, CodingKey {
        case exceptionType, message, stackTrace, frames
        case environment, release, commitSha, repository
        case requestContext, metadata, fingerprint
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(exceptionType, forKey: .exceptionType)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(stackTrace, forKey: .stackTrace)
        try container.encodeIfPresent(frames, forKey: .frames)
        try container.encodeIfPresent(environment, forKey: .environment)
        try container.encodeIfPresent(release, forKey: .release)
        try container.encodeIfPresent(commitSha, forKey: .commitSha)
        try container.encodeIfPresent(repository, forKey: .repository)
        try container.encodeIfPresent(requestContext, forKey: .requestContext)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(fingerprint, forKey: .fingerprint)
    }
}
