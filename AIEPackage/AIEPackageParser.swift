//
//  AIEPackageParser.swift
//  AIEditorKit
//
//  Created by ✐ ᵕ̈ ᴹᴼᴿᴺᴵᴺᴳ on 2026/4/30.
//

import Compression
import Foundation
import UIKit

enum AIEPackageParserError: Error, LocalizedError {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 通用包解析错误
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    case fileNotFound(String)

    case invalidFormat(String)

    case invalidPackage(String)

    case decompressionFailed(String)

    case missingRequiredField(String) // 可选

    case unsupportedVersion(String) // 可选

    case platformNotSupported(String) // 可选

    case validationFailed([String])

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            return "Package parser file not found: \(path)"
        case let .invalidFormat(message):
            return "Package parser invalid format: \(message)"
        case let .invalidPackage(message):
            return "Package parser invalid package: \(message)"
        case let .decompressionFailed(message):
            return "Package parser decompression failed: \(message)"
        case let .missingRequiredField(field):
            return "Package parser missing required field: \(field)"
        case let .unsupportedVersion(version):
            return "Package parser unsupported format version: \(version)"
        case let .platformNotSupported(platform):
            return "Package parser platform not supported: \(platform)"
        case let .validationFailed(errors):
            return "Package parser validation failed: \(errors.joined(separator: ", "))"
        }
    }
}

struct AIEPackageParseResult<T: Decodable> {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 解析结果
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    let package: T

    /// 二进制附件数据
    var attachment: Data?

    init(package: T, attachment: Data? = nil) {
        self.package = package
        self.attachment = attachment
    }

    /// 获取附件图片
    func attachmentImage() -> UIImage? {
        guard let data = attachment else { return nil }
        return UIImage(data: data)
    }
}

class AIEPackageParser<T: Decodable> {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 通用包解析器
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 通用包解析器
    /// 支持不同类型的包格式（特效包、模板包等）

    let format: AIEPackageFormat

    /// 验证回调（可选）
    var validationPackageHandler: ((T) -> [String]?)?

    init(format: AIEPackageFormat) {
        self.format = format
    }

    /// 从文件路径解析包
    func parse(from path: String, skipValidation: Bool = false) -> Result<AIEPackageParseResult<T>, AIEPackageParserError> {
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path))
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return self.parse(from: data, skipValidation: skipValidation)
        } catch {
            return .failure(.invalidFormat(error.localizedDescription))
        }
    }

    /// 从 Bundle 解析包
    func parse(from name: String, bundle: Bundle = .main, skipValidation: Bool = false) -> Result<AIEPackageParseResult<T>, AIEPackageParserError> {
        guard let path = bundle.path(forResource: name, ofType: format.extensionType) else {
            return .failure(.fileNotFound(name + "." + self.format.extensionType))
        }
        return self.parse(from: path, skipValidation: skipValidation)
    }

    /// 从 Data 解析包
    func parse(from data: Data, skipValidation: Bool = false) -> Result<AIEPackageParseResult<T>, AIEPackageParserError> {
        do {
            // 1. 解析文件头
            let header = try parseHeader(from: data)

            // 2. 定位并解压 manifest
            let manifest = try parseManifest(from: data, header: header)

            // 3. 解析 JSON
            let package = try deserializeToPackage(manifest)

            // 4. 解析附件数据
            let attachment = self.parseAttachment(from: data, header: header)

            // 5. 验证
            if !skipValidation {
                if let validation = validatePackage(package) {
                    return .failure(.validationFailed(validation))
                }
            }

            return .success(AIEPackageParseResult(package: package, attachment: attachment))
        } catch let error as AIEPackageParserError {
            return .failure(error)
        } catch {
            return .failure(.invalidFormat(error.localizedDescription))
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 私有方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private struct FileHeader {
        let isCompress: Bool

        let size: Int

        // 模板 manifest 起始位置
        let manifestOffset: Int

        // 模板 manifest 总长度
        let manifestLength: Int

        // 二进制附件起始位置
        let attachmentsOffset: Int

        // 二进制附件总长度
        let attachmentsLength: Int
    }

    /// 解析文件头
    private func parseHeader(from data: Data) throws -> FileHeader {
        guard data.count >= 12 else {
            throw AIEPackageParserError.invalidFormat("File too small parse header error")
        }

        // 检查魔数
        let magic = [UInt8](data[0 ..< 4])
        guard magic == self.format.magicBytes else {
            // 尝试作为纯 JSON 解析
            return FileHeader(isCompress: false, size: data.count, manifestOffset: 0, manifestLength: data.count, attachmentsOffset: 0, attachmentsLength: 0)
        }

        // 解析压缩标志
        let isCompress = data[4] == 0x01

        // 解析未压缩大小 (4 字节, 大端序)
        let size = Int(data[5]) << 24 | Int(data[6]) << 16 | Int(data[7]) << 8 | Int(data[8])

        // 解析 manifest 偏移量 (4 字节, 大端序)
        let manifestOffset = Int(data[9]) << 24 | Int(data[10]) << 16 | Int(data[11]) << 8 | Int(data[12])

        // 解析附件偏移量 (4 字节, 大端序)
        let attachmentsOffset = Int(data[13]) << 24 | Int(data[14]) << 16 | Int(data[15]) << 8 | Int(data[16])

        // manifest 长度
        let manifestLength = attachmentsOffset > 0 ? (attachmentsOffset - manifestOffset) : (data.count - manifestOffset)

        // 附件偏移量和长度
        let attachmentsLength = Int(data[17]) << 24 | Int(data[18]) << 16 | Int(data[19]) << 8 | Int(data[20])

        return FileHeader(isCompress: isCompress, size: size, manifestOffset: manifestOffset, manifestLength: manifestLength, attachmentsOffset: attachmentsOffset, attachmentsLength: attachmentsLength)
    }

    /// 提取文件体数据
    private func parseManifest(from data: Data, header: FileHeader) throws -> Data {
        let length = header.attachmentsOffset > 0 ? header.attachmentsOffset : data.count
        var manifest = data.subdata(in: header.manifestOffset ..< length)

        if header.isCompress {
            guard let decompressed = AIEFxCompression.decompress(manifest, capacity: header.size) else {
                throw AIEPackageParserError.decompressionFailed("File to decompress manifest error")
            }
            manifest = decompressed
        }

        return manifest
    }

    /// 解析附件数据
    private func parseAttachment(from data: Data, header: FileHeader) -> Data? {
        guard header.attachmentsOffset > 0 && header.attachmentsLength > 0 else {
            return nil
        }

        let length = min(header.attachmentsOffset + header.attachmentsLength, data.count)
        return data.subdata(in: header.attachmentsOffset ..< length)
    }

    /// 解析文件体为对象
    private func deserializeToPackage(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AIEPackageParserError.invalidPackage(error.localizedDescription)
        }
    }

    private func validatePackage(_ package: T) -> [String]? {
        // 调用自定义验证
        if let handler = validationPackageHandler {
            return handler(package)
        }
        return nil
    }
}
