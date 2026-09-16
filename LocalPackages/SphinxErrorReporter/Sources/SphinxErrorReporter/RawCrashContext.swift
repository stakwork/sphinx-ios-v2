// RawCrashContext.swift
// SphinxErrorReporter
//
// Captures raw crash metadata for post-hoc server-side symbolication.
// Image capture (including real Mach-O sizes) runs at install / next-launch
// recovery time — never from the signal handler.

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

    struct BinaryImageInfo {
        let name: String
        let uuid: String
        let loadAddress: UInt
        let size: UInt
    }

    // MARK: - Factory

    /// Builds a `RawCrashContext` from a call stack. Not signal-safe (Foundation).
    static func capture(callStackReturnAddresses: [NSNumber], rawSymbols: [String]) -> RawCrashContext {
        let images = captureLoadedImages()
        let arch = captureArch()
        let osVersion = captureOSVersion()
        let rawTrace = rawSymbols.joined(separator: "\n")

        var rawFrames: [RawFrame] = []
        for (idx, addr) in callStackReturnAddresses.enumerated() {
            let address = UInt(truncatingIfNeeded: addr.uintValue)
            if let image = findImage(for: address, in: images) {
                rawFrames.append(RawFrame(
                    frameIndex: idx,
                    returnAddress: address,
                    binaryName: image.name,
                    binaryUUID: image.uuid,
                    loadAddress: image.loadAddress
                ))
            } else {
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

    /// Reconstructs context from the C trampoline dump (next launch, process context).
    static func fromInterruptedPC(
        pc: UInt,
        imageName: String,
        imageUUID: String,
        loadAddress: UInt,
        imageSize: UInt
    ) -> RawCrashContext {
        let resolvedName = imageName.isEmpty ? "unknown" : imageName
        let images: [BinaryImageInfo]
        if !imageName.isEmpty, imageSize > 0 {
            images = [
                BinaryImageInfo(
                    name: imageName,
                    uuid: imageUUID,
                    loadAddress: loadAddress,
                    size: imageSize
                )
            ]
        } else {
            images = []
        }
        let frame = RawFrame(
            frameIndex: 0,
            returnAddress: pc,
            binaryName: resolvedName,
            binaryUUID: imageUUID,
            loadAddress: loadAddress
        )
        return RawCrashContext(
            frames: [frame],
            binaryImages: images,
            arch: captureArch(),
            osVersion: captureOSVersion(),
            rawStackTrace: ""
        )
    }

    // MARK: - Serialization

    func asMetadata() -> [String: Any] {
        let framesData = frames.map { frame -> [String: Any] in
            var d: [String: Any] = [
                "frameIndex": frame.frameIndex,
                "returnAddress": "0x\(String(frame.returnAddress, radix: 16, uppercase: false))",
                "binaryName": Self.binaryBaseName(frame.binaryName),
                "loadAddress": "0x\(String(frame.loadAddress, radix: 16, uppercase: false))"
            ]
            if !frame.binaryUUID.isEmpty {
                d["binaryUUID"] = frame.binaryUUID
            }
            return d
        }

        let imagesData = binaryImages.map { img -> [String: Any] in
            [
                "name": Self.binaryBaseName(img.name),
                "uuid": img.uuid,
                "loadAddress": "0x\(String(img.loadAddress, radix: 16, uppercase: false))",
                "size": Int(img.size)
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

    func asReadableStackTrace() -> String {
        var lines: [String] = [
            "=== Raw Crash Context ===",
            "Arch: \(arch)",
            "OS: \(osVersion)",
            "Binary Images:"
        ]
        for img in binaryImages {
            lines.append("  \(Self.binaryBaseName(img.name)) (UUID: \(img.uuid)) @ 0x\(String(img.loadAddress, radix: 16)) size=\(img.size)")
        }
        lines.append("Frames:")
        for frame in frames {
            lines.append("  [\(frame.frameIndex)] 0x\(String(frame.returnAddress, radix: 16)) in \(Self.binaryBaseName(frame.binaryName)) (load: 0x\(String(frame.loadAddress, radix: 16)))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Image lookup

    /// Range-checked: `loadAddress <= address < loadAddress + size`.
    /// Size 0 never matches. Overlapping ranges prefer the highest loadAddress.
    static func findImage(for address: UInt, in images: [BinaryImageInfo]) -> BinaryImageInfo? {
        images
            .filter { image in
                image.size > 0
                    && image.loadAddress <= address
                    && address < image.loadAddress &+ image.size
            }
            .max(by: { $0.loadAddress < $1.loadAddress })
    }

    static func binaryBaseName(_ path: String) -> String {
        if let slash = path.lastIndex(of: "/") {
            return String(path[path.index(after: slash)...])
        }
        return path
    }

    // MARK: - Loaded images (install / recovery — not the signal handler)

    static func captureLoadedImages() -> [BinaryImageInfo] {
        var images: [BinaryImageInfo] = []
        #if canImport(MachO)
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let header = _dyld_get_image_header(i),
                  let rawName = _dyld_get_image_name(i) else { continue }
            let name = String(cString: rawName)
            let slide = _dyld_get_image_vmaddr_slide(i)
            let loadAddress = UInt(bitPattern: header)
            let uuid = extractUUID(header: header)
            let size = imageSpan(header: header, slide: slide, loadAddress: loadAddress)
            images.append(BinaryImageInfo(name: name, uuid: uuid, loadAddress: loadAddress, size: size))
        }
        #endif
        return images
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

    #if canImport(MachO)
    private static func extractUUID(header: UnsafePointer<mach_header>) -> String {
        var uuid = ""
        iterateLoadCommands(header: header) { cmdPtr, cmd in
            if cmd == LC_UUID {
                let uuidCmd = cmdPtr.assumingMemoryBound(to: uuid_command.self)
                let b = uuidCmd.pointee.uuid
                uuid = String(
                    format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                    b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7,
                    b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15
                )
                return false
            }
            return true
        }
        return uuid
    }

    private static func imageSpan(
        header: UnsafePointer<mach_header>,
        slide: Int,
        loadAddress: UInt
    ) -> UInt {
        var maxEnd = loadAddress
        iterateLoadCommands(header: header) { cmdPtr, cmd in
            if cmd == LC_SEGMENT_64 {
                let seg = cmdPtr.assumingMemoryBound(to: segment_command_64.self)
                if seg.pointee.vmsize > 0 {
                    let start = UInt(seg.pointee.vmaddr) &+ UInt(bitPattern: slide)
                    let end = start &+ UInt(seg.pointee.vmsize)
                    if end > maxEnd {
                        maxEnd = end
                    }
                }
            } else if cmd == LC_SEGMENT {
                let seg = cmdPtr.assumingMemoryBound(to: segment_command.self)
                if seg.pointee.vmsize > 0 {
                    let start = UInt(seg.pointee.vmaddr) &+ UInt(bitPattern: slide)
                    let end = start &+ UInt(seg.pointee.vmsize)
                    if end > maxEnd {
                        maxEnd = end
                    }
                }
            }
            return true
        }
        return maxEnd > loadAddress ? maxEnd - loadAddress : 0
    }

    /// Walks load commands. `body` returns false to stop.
    private static func iterateLoadCommands(
        header: UnsafePointer<mach_header>,
        body: (UnsafeRawPointer, UInt32) -> Bool
    ) {
        let is64 = header.pointee.magic == MH_MAGIC_64 || header.pointee.magic == MH_CIGAM_64
        let headerSize = is64 ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size
        let ncmds = header.pointee.ncmds
        var cmdPtr = UnsafeRawPointer(header).advanced(by: headerSize)
        for _ in 0..<ncmds {
            let cmd = cmdPtr.assumingMemoryBound(to: load_command.self)
            let cmdValue = cmd.pointee.cmd
            let cmdSize = Int(cmd.pointee.cmdsize)
            guard cmdSize > 0 else { break }
            if !body(cmdPtr, cmdValue) {
                break
            }
            cmdPtr = cmdPtr.advanced(by: cmdSize)
        }
    }
    #endif
}
