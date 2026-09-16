// CrashDump.swift
// SphinxErrorReporter
//
// Binary dump written by the C signal trampoline, parsed on the next launch
// in full process context (Foundation is legal here).

import Foundation

/// On-disk layout produced by CrashSignalTrampoline (little-endian, packed).
///
/// Offset  Size  Field
/// 0       8     magic "SPHXDUMP"
/// 8       4     version (UInt32)
/// 12      4     signal (Int32)
/// 16      8     pc (UInt64)
/// 24      4     addressCount (UInt32)
/// 28      4     imageIndex (UInt32, 0xFFFFFFFF = unknown)
/// 32      64    imageName (C string)
/// 96      37    imageUUID (C string)
/// 133     8     loadAddress (UInt64)
/// 141     8     imageSize (UInt64)
/// 149           total
struct CrashDump: Equatable {
    static let magic = Data("SPHXDUMP".utf8)
    static let version: UInt32 = 1
    static let maxBytes = 65_536
    static let maxAddresses = 8
    static let encodedSize = 149
    static let fileName = "crash.dump"
    static let storageSubdirectory = "com.sphinx.error-reporter"

    let signal: Int32
    let pc: UInt64
    let addressCount: UInt32
    let imageName: String
    let imageUUID: String
    let loadAddress: UInt64
    let imageSize: UInt64

    /// Application Support dump path — app sandbox, not the app group.
    static func fileURL() -> URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        let dir = base.appendingPathComponent(storageSubdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    /// Encodes a dump for tests / fixtures. Matches the C packed layout.
    static func encode(
        signal: Int32,
        pc: UInt64,
        addressCount: UInt32 = 1,
        imageName: String = "",
        imageUUID: String = "",
        loadAddress: UInt64 = 0,
        imageSize: UInt64 = 0,
        version: UInt32 = CrashDump.version
    ) -> Data {
        var data = Data(count: encodedSize)
        data.replaceSubrange(0..<8, with: magic)
        writeUInt32(&data, 8, version)
        writeUInt32(&data, 12, UInt32(bitPattern: signal))
        writeUInt64(&data, 16, pc)
        writeUInt32(&data, 24, addressCount)
        writeUInt32(&data, 28, 0xFFFF_FFFF)
        writeCString(&data, offset: 32, length: 64, imageName)
        writeCString(&data, offset: 96, length: 37, imageUUID)
        writeUInt64(&data, 133, loadAddress)
        writeUInt64(&data, 141, imageSize)
        return data
    }

    /// Strict parser. Returns nil on any truncation, size, magic, version, or
    /// address-count violation. Never throws.
    static func parse(_ data: Data) -> CrashDump? {
        guard data.count <= maxBytes, data.count >= encodedSize else { return nil }
        guard data.prefix(8) == magic else { return nil }

        let version = readUInt32(data, 8)
        guard version == Self.version else { return nil }

        let addressCount = readUInt32(data, 24)
        guard addressCount >= 1, addressCount <= maxAddresses else { return nil }

        let signal = Int32(bitPattern: readUInt32(data, 12))
        let pc = readUInt64(data, 16)
        let imageName = readCString(data, offset: 32, length: 64)
        let imageUUID = readCString(data, offset: 96, length: 37)
        let loadAddress = readUInt64(data, 133)
        let imageSize = readUInt64(data, 141)

        return CrashDump(
            signal: signal,
            pc: pc,
            addressCount: addressCount,
            imageName: imageName,
            imageUUID: imageUUID,
            loadAddress: loadAddress,
            imageSize: imageSize
        )
    }

    static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGILL:  return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE:  return "SIGFPE"
        case SIGBUS:  return "SIGBUS"
        case SIGTRAP: return "SIGTRAP"
        default:      return "SIG\(sig)"
        }
    }

    /// Builds a Hive `ErrorReport` in process context from a parsed dump.
    static func makeReport(_ dump: CrashDump, config: Config, appModuleName: String) -> ErrorReport {
        let context = RawCrashContext.fromInterruptedPC(
            pc: UInt(dump.pc),
            imageName: dump.imageName,
            imageUUID: dump.imageUUID,
            loadAddress: UInt(dump.loadAddress),
            imageSize: UInt(dump.imageSize)
        )
        let frameBuilder = FrameBuilder(appModuleName: appModuleName, mainRepo: config.mainRepo)
        let frames = frameBuilder.build(
            fromAddresses: [UInt(dump.pc)],
            images: context.binaryImages
        )
        let sigName = signalName(dump.signal)
        var stackTrace = "Fatal signal \(sigName) (\(dump.signal))\n"
        stackTrace += context.asReadableStackTrace()

        return ErrorReport(
            exceptionType: "Signal/\(sigName)",
            message: "Fatal signal \(sigName) (\(dump.signal))",
            stackTrace: stackTrace,
            frames: frames,
            environment: config.environment,
            release: config.release,
            commitSha: config.commitSha,
            repository: config.mainRepo,
            metadata: context.asMetadata()
        )
    }
}

// MARK: - Unaligned little-endian readers

private func writeUInt32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
    var le = value.littleEndian
    withUnsafeBytes(of: &le) { bytes in
        data.replaceSubrange(offset..<(offset + 4), with: bytes)
    }
}

private func writeUInt64(_ data: inout Data, _ offset: Int, _ value: UInt64) {
    var le = value.littleEndian
    withUnsafeBytes(of: &le) { bytes in
        data.replaceSubrange(offset..<(offset + 8), with: bytes)
    }
}

private func writeCString(_ data: inout Data, offset: Int, length: Int, _ string: String) {
    var bytes = Array(string.utf8.prefix(length - 1))
    bytes.append(0)
    while bytes.count < length { bytes.append(0) }
    data.replaceSubrange(offset..<(offset + length), with: bytes)
}

private func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
    var value: UInt32 = 0
    _ = withUnsafeMutableBytes(of: &value) { dest in
        data.copyBytes(to: dest, from: offset..<(offset + 4))
    }
    return UInt32(littleEndian: value)
}

private func readUInt64(_ data: Data, _ offset: Int) -> UInt64 {
    var value: UInt64 = 0
    _ = withUnsafeMutableBytes(of: &value) { dest in
        data.copyBytes(to: dest, from: offset..<(offset + 8))
    }
    return UInt64(littleEndian: value)
}

private func readCString(_ data: Data, offset: Int, length: Int) -> String {
    let slice = data[offset..<(offset + length)]
    let bytes = Array(slice.prefix { $0 != 0 })
    return String(bytes: bytes, encoding: .utf8) ?? ""
}
