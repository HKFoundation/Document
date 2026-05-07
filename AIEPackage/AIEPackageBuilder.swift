//
//  AIEPackageBuilder.swift
//  AIEditorKit
//
//  Created by ✐ ᵕ̈ ᴹᴼᴿᴺᴵᴺᴳ on 2026/4/30.
//

import Compression
import CoreGraphics
import Foundation

enum AIEPackageBuilderError: Error, LocalizedError {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 通用包打包错误
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    case invalidPackage(String)

    case serializationFailed(String)

    case compressionFailed(String)

    case fileWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidPackage(message):
            return "Package build invalid: \(message)"
        case let .serializationFailed(message):
            return "Package build serialization failed: \(message)"
        case let .compressionFailed(message):
            return "Package build compression failed: \(message)"
        case let .fileWriteFailed(message):
            return "Package build file write failed: \(message)"
        }
    }
}

struct AIEPackageBuilderConfig {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 打包配置
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    // 是否压缩
    var isCompress: Bool = true

    // 压缩级别 (0-9)
    var compressionLevel: Int32 = 6

    // 输出目录
    var outputDirectory: String?

    // 附件数据（目前只有封面图）
    var attachment: Data?

    init() {}
}

class AIEPackageBuilder<T: Encodable> {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 通用包打包器
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 通用包打包器
    /// 支持不同类型的包格式（特效包、模板包等）

    // 打包格式
    let format: AIEPackageFormat

    init(format: AIEPackageFormat) {
        self.format = format
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 公共方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 将包对象序列化为文件
    func buildToFile(_ package: T, outputFilePath: String, config: AIEPackageBuilderConfig = AIEPackageBuilderConfig()) -> Result<String, AIEPackageBuilderError> {
        let result = self.build(package, config: config)

        switch result {
        case let .success(data):
            do {
                let url = URL(fileURLWithPath: outputFilePath)
                let directory = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: url)
                return .success(outputFilePath)
            } catch {
                return .failure(.fileWriteFailed(error.localizedDescription))
            }
        case let .failure(error):
            return .failure(error)
        }
    }

    /// 将包对象序列化为文件 (使用默认路径)
    func buildToFile(_ package: T, name: String, config: AIEPackageBuilderConfig = AIEPackageBuilderConfig()) -> Result<String, AIEPackageBuilderError> {
        let outputFilePath = NSHomeDirectory() + "/Documents/AIEditorKit/Original/" + "\(name).\(self.format.extensionType)"
        return self.buildToFile(package, outputFilePath: outputFilePath, config: config)
    }

    /// 生成预览图
    func generatePreview(for package: T, size: CGSize = CGSize(width: 256, height: 256)) -> Data? {
        return nil
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 私有方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 将特效包序列化为 Data 类型
    private func build(_ package: T, config: AIEPackageBuilderConfig) -> Result<Data, AIEPackageBuilderError> {
        do {
            // 1. 序列化
            let manifest = try serializeToData(package)

            // 2. 压缩 (可选)
            var data = manifest
            var isCompress = false

            if config.isCompress && manifest.count > 256 {
                if let compressed = AIEFxCompression.compress(manifest) {
                    data = compressed
                    isCompress = true
                }
            }

            // 3. 添加文件头
            let file = self.buildFileHeader(
                data: data,
                isCompress: isCompress,
                size: manifest.count,
                attachment: config.attachment
            )

            return .success(file)
        } catch let error as AIEPackageBuilderError {
            return .failure(error)
        } catch {
            return .failure(.serializationFailed(error.localizedDescription))
        }
    }

    private func serializeToData(_ package: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(package)
        } catch {
            throw AIEPackageBuilderError.serializationFailed(error.localizedDescription)
        }
    }

    /// 构建文件头
    /// 格式: [魔数 4][压缩 1][大小 4][manifest偏移 4][附件偏移 4][附件长度 4][manifest data][attachment data]
    private func buildFileHeader(data: Data, isCompress: Bool, size: Int, attachment: Data?) -> Data {
        var header = Data()

        // 添加魔数
        header.append(contentsOf: self.format.magicBytes)

        // 添加压缩标志
        header.append(isCompress ? 0x01 : 0x00)

        // 添加原始大小 (4 字节, 大端序)
        header.append(UInt8((size >> 24) & 0xFF))
        header.append(UInt8((size >> 16) & 0xFF))
        header.append(UInt8((size >> 8) & 0xFF))
        header.append(UInt8(size & 0xFF))

        // 添加 manifest 偏移量 (4 字节, 大端序, 固定为 21)
        let manifestOffset = 21
        header.append(UInt8((manifestOffset >> 24) & 0xFF))
        header.append(UInt8((manifestOffset >> 16) & 0xFF))
        header.append(UInt8((manifestOffset >> 8) & 0xFF))
        header.append(UInt8(manifestOffset & 0xFF))

        // 添加附件偏移量 (4 字节, 大端序)
        let attachmentsOffset = attachment != nil ? (manifestOffset + data.count) : 0
        header.append(UInt8((attachmentsOffset >> 24) & 0xFF))
        header.append(UInt8((attachmentsOffset >> 16) & 0xFF))
        header.append(UInt8((attachmentsOffset >> 8) & 0xFF))
        header.append(UInt8(attachmentsOffset & 0xFF))

        // 添加附件长度 (4 字节, 大端序)
        let attachmentsLength = attachment?.count ?? 0
        header.append(UInt8((attachmentsLength >> 24) & 0xFF))
        header.append(UInt8((attachmentsLength >> 16) & 0xFF))
        header.append(UInt8((attachmentsLength >> 8) & 0xFF))
        header.append(UInt8(attachmentsLength & 0xFF))

        // 添加 manifest 数据
        header.append(data)

        // 添加附件数据
        if let attachment = attachment {
            header.append(attachment)
        }

        return header
    }
}
