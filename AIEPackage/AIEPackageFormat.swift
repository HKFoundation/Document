//
//  AIEPackageFormat.swift
//  AIEditorKit
//
//  Created by ✐ ᵕ̈ ᴹᴼᴿᴺᴵᴺᴳ on 2026/4/30.
//

import Compression
import Foundation

protocol AIEPackageFormat {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 通用包文件格式配置
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    // 文件扩展名 (不含点号)
    var extensionType: String { get }

    // 魔数 (4字节，用于快速识别文件类型 XBOT)
    var magicBytes: [UInt8] { get }

    // 当前文件版本号
    var version: String { get }
}

enum AIETemplateFileFormat: AIEPackageFormat {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板包文件格式
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    case `default`

    var extensionType: String { "xproj" }

    var magicBytes: [UInt8] { [0x58, 0x42, 0x4F, 0x54] }

    var version: String { "1.0" }
}

enum AIEFxFileFormat: AIEPackageFormat {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 特效包文件格式
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    case `default`

    var extensionType: String { "xfx" }

    var magicBytes: [UInt8] { [0x58, 0x42, 0x4F, 0x54] }

    var version: String { "1.0" }
}

enum AIEFxCompression {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 压缩 / 解压工具
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/
    /// 使用 LZFSE 压缩数据 (Apple 高效压缩算法)
    static func compress(_ data: Data) -> Data? {
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        defer { bytes.deallocate() }

        let count = data.withUnsafeBytes { sourcePtr -> Int in
            guard let sourceBaseAddress = sourcePtr.baseAddress else { return 0 }
            return compression_encode_buffer(
                bytes,
                data.count,
                sourceBaseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard count > 0 else { return nil }
        return Data(bytes: bytes, count: count)
    }

    /// 解压 LZFSE 数据
    static func decompress(_ data: Data, capacity: Int) -> Data? {
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { bytes.deallocate() }

        let count = data.withUnsafeBytes { sourcePtr -> Int in
            guard let sourceBaseAddress = sourcePtr.baseAddress else { return 0 }
            return compression_decode_buffer(
                bytes,
                capacity,
                sourceBaseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard count > 0 else { return nil }
        return Data(bytes: bytes, count: count)
    }
}
