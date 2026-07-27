// RawCrashContext.swift
// SphinxErrorReporter
//
// Captures raw crash metadata for post-hoc server-side symbolication.
// Mandatory when debug symbols are stripped (release builds).
// Uses only signal-handler-safe operations where required.

import Foundation

#if canImport(MachO)
import MachO
#endif

/// Raw per-frame address alongside the owning binary image's UUID + load address.
struct RawFrame {
    let frameIndex: Int
    let returnAddress: UInt
    let binaryName: String
    let binaryUUID: String   // MANDATORY — server-side symbolication is impossible without UUID
    let loadAddress: UInt
}

/// Full crash context captured at crash time for release-build symbolication.
struct RawCrashContext {
    let frames: [RawFrame]
    let binaryImages: [BinaryImageInfo]
    let arch: String
    let osVersion: String
    let rawStackTrace: String

    // MARK: - Binary Image capture

    struct BinaryImageInfo {
        let name: String
        let uuid: String
        let loadAddress: UInt
        let size: UInt
    }

    // MARK: - Factory

    /// Builds a `RawCrashContext` from the current call stack.
    /// Safe to call from a signal handler (no heap alloc for path buffer — handled in CrashHandler).
    static func capture(callStackReturnAddresses: [NSNumber], rawSymbols: [String]) -> RawCrashContext {
        let images = captureLoadedImages()
        let arch = captureArch()
        let osVersion = captureOSVersion()
        let rawTrace = rawSymbols.joined(separator: "\n")

        var rawFrames: [RawFrame] = []
        for (idx, addr) in callStackReturnAddresses.enumerated() {
            let address = UInt(truncatingIfNeeded: addr.uintValue)
            // Find the owning binary image for this address
            if let image = findImage(for: address, in: images) {
                rawFrames.append(RawFrame(
                    frameIndex: idx,
                    returnAddress: address,
                    binaryName: image.name,
                    binaryUUID: image.uuid,
                    loadAddress: image.loadAddress
                ))
            } else {
                // Unknown binary — still record address
                rawFrames.append(RawFrame(
                    frameIndex: idx,
                    returnAddress: address,
                    binaryName: "unknown",
                    binaryUUID: "",
                    loadAddress: 0
                ))
            }
        }

        return RawCrashContext(
            frames: rawFrames,
            binaryImages: images,
            arch: arch,
            osVersion: osVersion,
            rawStackTrace: rawTrace
        )
    }

    // MARK: - Serialization

    /// Produces a JSON-serializable `[String: Any]` for `ErrorReport.metadata`.
    func asMetadata() -> [String: Any] {
        let framesData = frames.map { frame -> [String: Any] in
            var d: [String: Any] = [
                "frameIndex": frame.frameIndex,
                "returnAddress": "0x\(String(frame.returnAddress, radix: 16, uppercase: false))",
                "binaryName": frame.binaryName,
                "loadAddress": "0x\(String(frame.loadAddress, radix: 16, uppercase: false))"
            ]
            if !frame.binaryUUID.isEmpty {
                d["binaryUUID"] = frame.binaryUUID
            }
            return d
        }

        let imagesData = binaryImages.map { img -> [String: Any] in
            [
                "name": img.name,
                "uuid": img.uuid,
                "loadAddress": "0x\(String(img.loadAddress, radix: 16, uppercase: false))",
                "size": img.size
            ]
        }

        return [
            "rawCrash": [
                "arch": arch,
                "osVersion": osVersion,
                "frames": framesData,
                "binaryImages": imagesData
            ]
        ]
    }

    /// Produces a human-readable stack trace string (appended to `stackTrace`).
    func asReadableStackTrace() -> String {
        var lines: [String] = [
            "=== Raw Crash Context ===",
            "Arch: \(arch)",
            "OS: \(osVersion)",
            "Binary Images:"
        ]
        for img in binaryImages {
            lines.append("  \(img.name) (UUID: \(img.uuid)) @ 0x\(String(img.loadAddress, radix: 16))")
        }
        lines.append("Frames:")
        for frame in frames {
            lines.append("  [\(frame.frameIndex)] 0x\(String(frame.returnAddress, radix: 16)) in \(frame.binaryName) (load: 0x\(String(frame.loadAddress, radix: 16)))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private static func captureArch() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #elseif arch(arm)
        return "arm"
        #else
        return "unknown"
        #endif
    }

    private static func captureOSVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private static func captureLoadedImages() -> [BinaryImageInfo] {
        var images: [BinaryImageInfo] = []
        #if canImport(MachO)
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let header = _dyld_get_image_header(i),
                  let rawName = _dyld_get_image_name(i) else { continue }
            let name = String(cString: rawName)
            let slide = _dyld_get_image_vmaddr_slide(i)
            let loadAddress = UInt(bitPattern: header) 

            // Extract UUID from LC_UUID load command
            var uuid = ""
            var cmd: UnsafePointer<load_command>? = UnsafeRawPointer(header)
                .advanced(by: MemoryLayout<mach_header_64>.size)
                .assumingMemoryBound(to: load_command.self)

            for _ in 0..<header.pointee.ncmds {
                guard let current = cmd else { break }
                if current.pointee.cmd == LC_UUID {
                    let uuidCmd = UnsafeRawPointer(current).assumingMemoryBound(to: uuid_command.self)
                    let b = uuidCmd.pointee.uuid
                    uuid = String(format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                                  b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7,
                                  b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15)
                    break
                }
                let nextOffset = Int(current.pointee.cmdsize)
                guard nextOffset > 0 else { break }
                cmd = UnsafeRawPointer(current).advanced(by: nextOffset).assumingMemoryBound(to: load_command.self)
            }
            _ = slide // used implicitly via loadAddress calculation above
            images.append(BinaryImageInfo(name: name, uuid: uuid, loadAddress: loadAddress, size: 0))
        }
        #endif
        return images
    }

    /// Finds the binary image that contains a given return address.
    private static func findImage(for address: UInt, in images: [BinaryImageInfo]) -> BinaryImageInfo? {
        // Sort by load address descending and find the first image with loadAddress <= address
        return images
            .filter { $0.loadAddress <= address }
            .max(by: { $0.loadAddress < $1.loadAddress })
    }
}
