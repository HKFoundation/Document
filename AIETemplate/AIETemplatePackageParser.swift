//
//  AIETemplatePackageParser.swift
//  AIEditorKit
//
//  Created by ✐ ᵕ̈ ᴹᴼᴿᴺᴵᴺᴳ on 2026/4/30.
//

import Foundation

/// 模板包解析结果
struct AIETemplatePackageParseResult {
    let template: AIETemplatePluginProtocol
    
    let attachment: Data?

    init(template: AIETemplatePluginProtocol, attachment: Data?) {
        self.template = template
        self.attachment = attachment
    }
}

/// 模板包解析器
/// 从 .xproj 文件解析还原为 AIETemplatePluginProtocol
class AIETemplatePackageParser {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板包解析器
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 通用解析器实例
    private let parser = AIEPackageParser<AIETemplatePluginProtocol>(format: AIETemplateFileFormat.default)

    init() {}

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 公共方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 从文件路径解析模板包
    func parse(from path: String, skipValidation: Bool = false) -> Result<AIETemplatePackageParseResult, AIEPackageParserError> {
        let result = self.parser.parse(from: path, skipValidation: skipValidation)

        switch result {
        case let .success(object):
            return .success(AIETemplatePackageParseResult(template: object.package, attachment: object.attachment))
        case let .failure(error):
            return .failure(error)
        }
    }

    /// 从 Bundle 解析模板包
    func parse(from name: String, bundle: Bundle = .main, skipValidation: Bool = false) -> Result<AIETemplatePackageParseResult, AIEPackageParserError> {
        let result = self.parser.parse(from: name, bundle: bundle, skipValidation: skipValidation)

        switch result {
        case let .success(object):
            return .success(AIETemplatePackageParseResult(template: object.package, attachment: object.attachment))
        case let .failure(error):
            return .failure(error)
        }
    }

    /// 从 Data 解析模板包
    func parse(from data: Data, skipValidation: Bool = false) -> Result<AIETemplatePackageParseResult, AIEPackageParserError> {
        let result = self.parser.parse(from: data, skipValidation: skipValidation)

        switch result {
        case let .success(object):
            return .success(AIETemplatePackageParseResult(template: object.package, attachment: object.attachment))
        case let .failure(error):
            return .failure(error)
        }
    }
}
