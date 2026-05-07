//
//  AIETemplatePackageBuilder.swift
//  AIEditorKit
//
//  Created by ✐ ᵕ̈ ᴹᴼᴿᴺᴵᴺᴳ on 2026/4/30.
//

import Foundation

/// 模板包打包器
/// 将 AIETemplatePluginProtocol 打包成 .xproj 文件
class AIETemplatePackageBuilder {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板包打包器
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 通用打包器实例
    private let builder = AIEPackageBuilder<AIETemplatePluginProtocol>(format: AIETemplateFileFormat.default)

    init() {}

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 公共方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 将模板打包成文件
    func build(_ template: AIETemplatePluginProtocol, outputFilePath: String, config: AIEPackageBuilderConfig = AIEPackageBuilderConfig()) -> Result<String, AIEPackageBuilderError> {
        return self.builder.buildToFile(template, outputFilePath: outputFilePath, config: config)
    }

    /// 将模板打包成文件（使用默认路径）
    func build(
        _ template: AIETemplatePluginProtocol,
        name: String,
        config: AIEPackageBuilderConfig = AIEPackageBuilderConfig()
    ) -> Result<String, AIEPackageBuilderError> {
        return self.builder.buildToFile(template, name: name, config: config)
    }
}
