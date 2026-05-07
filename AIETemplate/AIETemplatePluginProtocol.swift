//
//  AIETemplatePluginProtocol.swift
//  AIEditorKit
//
//  Created by ✐ ᵕ̈ ᴹᴼᴿᴺᴵᴺᴳ on 2026/4/14.
//

import Foundation

//  跨平台模板数据模型 - 可被 iOS 和 Android 共同解析
//  设计原则：
//  1. 使用相对时间而非绝对时间
//  2. 使用包 ID 引用素材，不包含绝对路径
//  3. 保留所有剪辑操作步骤
//  4. 兼容双端 SDK 的数据结构

struct AIETemplatePluginProtocol: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 跨平台模板根对象
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 模板版本号
    var version: String = "1.0.0"

    /// 模板名称
    var name: String

    /// 模板描述
    var description: String?

    /// 创建时间（微秒时间戳）
    var created_at: Int64

    /// 模板基本信息
    var settings: AIETemplateSettings

    /// 视频轨道列表
    var videos: [AIETemplateVideoTrack]

    /// 画中画轨道列表
    var pips: [AIETemplateVideoTrack]

    /// 音频轨道列表
    var audios: [AIETemplateAudioTrack]

    /// 字幕轨道列表
    var captions: [AIETemplateCaptionTrack]

    /// 贴纸轨道列表
    var stickers: [AIETemplateStickerTrack]

    /// 全局滤镜
    var filters: [AIETemplateFilter]

    /// 全局特效
    var effects: [AIETemplateEffect]

    /// 转场配置（key 为 clip 的唯一标识）
    var transitions: [String: AIETemplateTransition]

    /// 素材映射表（模板内使用的所有素材文件）
    var material: [AIETemplateMaterial]
    
    /// 素材占位时长与轨道类型
    var placeholder: [AIETemplatePlaceholder]

    init(name: String) {
        self.name = name
        self.created_at = Int64(Date().timeIntervalSince1970 * 1000)
        self.settings = AIETemplateSettings()
        self.videos = []
        self.audios = []
        self.pips = []
        self.captions = []
        self.stickers = []
        self.filters = []
        self.effects = []
        self.transitions = [:]
        self.material = []
        self.placeholder = []
    }
}

struct AIETemplateSettings: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板设置
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 比例模式: 0=原始, 1=9:16, 2=16:9, 3=3:4, 4=1:1, 5=4:3
    var aspect_ratio_mode: Int = 0

    /// 原始比例
    var origin_aspect_ratio: Double = 1.7777778

    /// 预览分辨率高度
    var preview_resolution: Int = 1080

    /// 视频帧率分子
    var video_fps_num: Int = 25

    /// 视频帧率分母
    var video_fps_den: Int = 1

    /// 视频宽度
    var image_width: Int = 1920

    /// 视频高度
    var image_height: Int = 1080

    /// 是否静音
    var is_muted: Bool = false
}

struct AIETemplateVideoTrack: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板视频轨道
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 轨道索引
    var track_index: Int

    /// 片段列表
    var clips: [AIETemplateVideoClip]

    init(track_index: Int, clips: [AIETemplateVideoClip] = []) {
        self.track_index = track_index
        self.clips = clips
    }
}

struct AIETemplateVideoClip: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板视频片段
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 片段唯一标识（用于关联转场等）
    var item_indicate: String

    /// 轨道索引
    var track_index: Int

    /// 片段索引
    var clip_index: Int = 0

    /// 在轨道上的相对开始时间
    var position: Int64

    /// 相对裁剪入点
    var trim_in: Int64

    /// 相对裁剪出点
    var trim_out: Int64

    /// 资源占位符ID（关联 resourceId）
    var resource_id: String

    /// 是否静音
    var is_muted: Bool = false

    /// 滤镜列表
    var filters: [AIETemplateFilter] = []

    /// 特效列表
    var effects: [AIETemplateEffect] = []

    /// 变换参数
    var transform: AIETemplateTransform?

    /// 变速模型
    var speed: AIETemplateClipSpeed?

    /// 音量参数
    var volume: AIETemplateClipVolume?

    /// 蒙版参数
    var mask: AIETemplateClipMask?

    /// 调节参数
    var adjusts: AIETemplateClipAdjusts?

    /// 裁剪参数
    var crop: AIETemplateClipCrop?

    /// 片段动画（入场动画、出场动画）
    var animation: AIETemplateClipAnimation?

    /// 混合模式
    var blend_mode: Int = 0

    /// 是否倒放（标记字段，提示素材应为倒放文件）
    var is_reversed: Bool = false

    init(item_indicate: String, track_index: Int, position: Int64, trim_in: Int64, trim_out: Int64, resource_id: String) {
        self.item_indicate = item_indicate
        self.track_index = track_index
        self.position = position
        self.trim_in = trim_in
        self.trim_out = trim_out
        self.resource_id = resource_id
    }
}

struct AIETemplateClipSpeed: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 变速模型
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 变速值
    var speed: Float = 1.0

    /// 是否保持音高
    var keep_audio_pitch: Bool = true

    /// 曲线变速标识
    var curve_speed_id: String?

    /// 曲线变速字符串（格式：点对序列）
    var curve_speed_string: [String: String]?
}

struct AIETemplateClipVolume: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 音量配置
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 左声道音量增益 (0.0 - 2.0，默认 1.0)
    var left_volume_gain: Float = 1.0

    /// 右声道音量增益 (0.0 - 2.0，默认 1.0)
    var right_volume_gain: Float = 1.0

    /// 入场淡入时长
    var fade_in_duration: Int64 = 0

    /// 出场淡出时长
    var fade_out_duration: Int64 = 0
}

struct AIETemplateClipAnimation: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 片段动画配置
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 动画类型标识
    /// - 2: 入场/出场分离模式（Package Id 为入场，Package2 Id 为出场）
    /// - 3: 循环动画模式（Post Package Id 为循环动画，Package Id/Effect In-Out 为入场，Package2 Id/Effect In-Out 为出场）
    var animation_type: Int = 2

    /// 入场动画包 ID
    var in_package_id: String?

    /// 入场动画开始时间
    var in_trim_in: Int64 = 0

    /// 入场动画结束时间
    var in_trim_out: Int64 = 0

    /// 出场动画包 ID
    var out_package_id: String?

    /// 出场动画开始时间
    var out_trim_in: Int64 = 0

    /// 出场动画结束时间
    var out_trim_out: Int64 = 0

    /// 循环动画包 ID（仅在循环动画模式下使用，存储在 Post Package Id 字段）
    var period_package_id: String?

    /// 循环动画开始时间
    var period_trim_in: Int64 = 0

    /// 循环动画结束时间
    var period_trim_out: Int64 = 0

    /// 是否有循环动画（当有循环动画时，入场/出场动画可能不生效）
    var is_period: Bool {
        return self.period_package_id != nil && !(self.period_package_id?.isEmpty ?? true)
    }

    /// 是否有效（至少有一个动画或有动画类型配置）
    var is_valid: Bool {
        let package = (self.in_package_id != nil && !self.in_package_id!.isEmpty) ||
            (self.out_package_id != nil && !self.out_package_id!.isEmpty) ||
            (self.period_package_id != nil && !self.period_package_id!.isEmpty)

        // 如果动画类型是 入场/出场/循环，即使没有包 ID，只要有时长配置也认为是有效的
        let duration = self.animation_type > 0 && (
            self.in_trim_out > 0 ||
                self.out_trim_in > 0 ||
                self.out_trim_out > 0 ||
                self.period_trim_out > 0
        )

        return package || duration
    }

    init() {}
}

struct AIETemplateClipMask: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 蒙版配置（支持关键帧动画）
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 蒙版类型（如 "MSTemplate-MaskType-Rect"）
    var mask_type: String?

    /// 是否反向蒙版
    var inverse: Bool = false

    /// 是否有动画（有关键帧）
    var is_animation: Bool = false

    /// 蒙版区域关键帧列表（JSON字符串数组）
    var region_info_keyframes: [AIETemplateMaskRegionKeyframe] = []

    /// 羽化宽度关键帧列表
    var feather_width_keyframes: [AIETemplateMaskFeatherKeyframe] = []

    /// 羽化宽度
    var feather_width: Float = 0

    /// 蒙版区域信息（JSON字符串）
    var region_info: String?
}

struct AIETemplateMaskRegionKeyframe: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 蒙版区域关键帧
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 时间位置（相对于片段入点）
    var position: Int64

    /// 蒙版区域信息（JSON字符串）
    var region_info: String
}

struct AIETemplateMaskFeatherKeyframe: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 蒙版羽化宽度关键帧
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 时间位置（相对于片段入点）
    var position: Int64

    /// 羽化宽度值
    var feather_width: Float

    /// 曲线类型（1=线性, 2=贝塞尔等）
    var curve_type: Int = 1
}

struct AIETemplateClipAdjusts: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 调节参数列表
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 调节效果列表
    var items: [AIETemplateClipAdjustItem] = []
}

struct AIETemplateClipAdjustItem: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 单个调节效果
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 原始索引（用于保持效果顺序）
    var index: Int = 0

    /// 调节类型
    var type: String

    /// 亮度 (-1.0 - 1.0)
    var brightness: Float = 0.0

    /// 对比度 (-1.0 - 1.0)
    var contrast: Float = 0.0

    /// 饱和度 (-1.0 - 1.0)
    var saturation: Float = 0.0

    /// 曝光 (0.0 - 1.0)
    var exposure: Float = 0.0

    /// 高光 (-1.0 - 1.0)
    var highlight: Float = 0.0

    /// 阴影 (-1.0 - 1.0)
    var shadow: Float = 0.0

    /// 褪色 (0.0 - 1.0)
    var fade: Float = 0.0

    /// 色温 (-1.0 - 1.0)
    var temperature: Float = 0.0

    /// 色调 (-1.0 - 1.0)
    var tint: Float = 0.0

    /// 晕影强度 (0.0 - 1.0)
    var vignette_intensity: Float = 0.0

    /// 锐化强度 (0.0 - 1.0)
    var sharpen_amount: Float = 0.0
}

struct AIETemplateClipCrop: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 裁剪配置
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    // ===== Transform 2D (裁剪时的变换) =====

    /// 裁剪旋转角度
    var rotation: Float = 0.0

    /// 裁剪缩放 X
    var scale_x: Float = 1.0

    /// 裁剪缩放 Y
    var scale_y: Float = 1.0

    /// 裁剪位移 X
    var translate_x: Float = 0.0

    /// 裁剪位移 Y
    var translate_y: Float = 0.0

    // ===== Crop (裁剪边界框) =====

    /// 裁剪比例模式（如 "3" 表示 1:1）
    var aspect_ratio_mode: String?

    /// 边界左
    var bounding_left: Float = -1.0

    /// 边界右
    var bounding_right: Float = 1.0

    /// 边界上
    var bounding_top: Float = 1.0

    /// 边界下
    var bounding_bottom: Float = -1.0
}

struct AIETemplateAudioTrack: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板音频轨道
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 轨道索引
    var track_index: Int

    /// 片段列表
    var clips: [AIETemplateAudioClip]

    init(track_index: Int, clips: [AIETemplateAudioClip] = []) {
        self.track_index = track_index
        self.clips = clips
    }
}

struct AIETemplateAudioClip: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板音频片段
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 片段唯一标识
    var item_indicate: String

    /// 轨道索引
    var track_index: Int

    /// 在轨道上的相对开始时间
    var position: Int64

    /// 相对裁剪入点
    var trim_in: Int64

    /// 相对裁剪出点
    var trim_out: Int64

    /// 资源占位符 ID
    var resource_id: String

    /// 音频类型: 0=外部音频文件, 1=录音, 2=视频提取音频
    var audio_type: Int = 0

    /// 音频文件名（用于内置音频的显示名称）
    var name: String?

    /// 左声道音量（0.0 - 2.0）
    var left_volume_gain: Float = 1.0

    /// 右声道音量（0.0 - 2.0）
    var right_volume_gain: Float = 1.0

    /// 速度（1.0 = 正常速度）
    var speed: Float = 1.0

    /// 是否保持音高
    var keep_audio_pitch: Bool = true

    /// 淡入时长
    var fade_in_duration: Int64 = 0

    /// 淡出时长
    var fade_out_duration: Int64 = 0

    /// 是否为外部音频文件（需要从沙盒读取）
    var is_audio_file: Bool {
        return self.audio_type == 0 && !self.resource_id.isEmpty
    }

    /// 是否为录音
    var is_record: Bool {
        return self.audio_type == 1
    }

    /// 是否为视频提取音频
    var is_extract: Bool {
        return self.audio_type == 2
    }

    init(item_indicate: String, track_index: Int, position: Int64, trim_in: Int64, trim_out: Int64, resource_id: String) {
        self.item_indicate = item_indicate
        self.track_index = track_index
        self.position = position
        self.trim_in = trim_in
        self.trim_out = trim_out
        self.resource_id = resource_id
    }
}

struct AIETemplateCaptionTrack: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板字幕轨道
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 字幕列表
    var captions: [AIETemplateCaption]

    init(captions: [AIETemplateCaption] = []) {
        self.captions = captions
    }
}

struct AIETemplateCaption: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板字幕
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 字幕唯一标识
    var item_indicate: String

    /// 字幕文本
    var text: String

    /// 开始时间
    var in_point: Int64

    /// 结束时间
    var out_point: Int64

    /// 样式 ID（可引用预设样式）
    var style_id: String?

    /// 字幕样式参数
    var style: AIETemplateCaptionStyle?

    init(item_indicate: String, text: String, in_point: Int64, out_point: Int64) {
        self.item_indicate = item_indicate
        self.text = text
        self.in_point = in_point
        self.out_point = out_point
    }
}

struct AIETemplateCaptionStyle: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 字幕样式
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 字体名称
    var font: String?

    /// 字体大小
    var size: Float?

    /// 文字颜色（ARGB）
    var text_color: String?

    /// 背景颜色（ARGB）
    var background_color: String?

    /// 对齐方式: left, center, right
    var alignment: String = "center"

    /// 字幕位置 Y
    var position_y: Float = 80.0
}

struct AIETemplateStickerTrack: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板贴纸轨道
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 贴纸列表
    var stickers: [AIETemplateSticker]

    init(stickers: [AIETemplateSticker] = []) {
        self.stickers = stickers
    }
}

struct AIETemplateSticker: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板贴纸（支持关键帧动画）
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 贴纸唯一标识
    var item_indicate: String

    /// 贴纸资源包 ID
    var package_id: String

    /// 开始时间
    var in_point: Int64

    /// 结束时间
    var out_point: Int64

    /// 位置 X
    var position_x: Float = 50.0

    /// 位置 Y
    var position_y: Float = 50.0

    /// 缩放
    var scale: Float = 1.0

    /// 旋转角度
    var rotation: Float = 0.0

    /// 入场动画时长
    var in_animation_duration: Int32 = 0

    /// 出场动画时长
    var out_animation_duration: Int32 = 0

    /// 循环动画时长
    var period_animation_duration: Int32 = 0

    /// 是否有动画（有关键帧）
    var is_animation: Bool = false

    /// 贴纸关键帧列表
    var keyframes: [AIETemplateStickerKeyframe] = []

    /// 贴纸封面图片路径
    var cover_image_path: String?

    init(item_indicate: String, package_id: String, in_point: Int64, out_point: Int64) {
        self.item_indicate = item_indicate
        self.package_id = package_id
        self.in_point = in_point
        self.out_point = out_point
    }
}

struct AIETemplateStickerKeyframe: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 贴纸关键帧
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 时间位置（相对于贴纸入点）
    var position: Int64

    /// X 轴位移
    var translate_x: Float

    /// Y 轴位移
    var translate_y: Float

    /// 旋转角度
    var rotation: Float

    /// 缩放
    var scale: Float

    /// 曲线类型（1=线性, 2=贝塞尔等）
    var curve_type: Int = 1
}

struct AIETemplateFilter: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板滤镜
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 原始索引（用于保持效果顺序）
    var index: Int = 0

    /// 滤镜唯一标识
    var item_indicate: String

    /// 滤镜包 ID
    var package_id: String

    /// 滤镜名称
    var name: String?

    /// 开始时间
    var in_point: Int64

    /// 结束时间
    var out_point: Int64

    /// 强度（0.0 - 1.0）
    var intensity: Float = 1.0

    init(item_indicate: String, package_id: String, name: String?, in_point: Int64, out_point: Int64, intensity: Float = 1.0) {
        self.item_indicate = item_indicate
        self.package_id = package_id
        self.name = name
        self.in_point = in_point
        self.out_point = out_point
        self.intensity = intensity
    }
}

struct AIETemplateEffect: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 模板特效
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 特效唯一标识
    var item_indicate: String

    /// 特效包 ID
    var package_id: String

    /// 特效名称
    var name: String?

    /// 开始时间
    var in_point: Int64

    /// 结束时间
    var out_point: Int64

    /// 视频轨道索引（决定特效类型）
    /// - video_track_index < main_track_index(1): Timeline 级别特效（全局特效）
    /// - video_track_index == main_track_index(1): 主轨特效
    var video_track_index: Int = 0

    /// 片段索引（用于主轨特效和片段特效）
    var clip_index: Int = -1

    /// 用于特效纵向轨道位置
    /// - 全局特效：只有在 track_index > 0 时才输出
    var track_index: Int = 0

    init(item_indicate: String, package_id: String, name: String?, in_point: Int64, out_point: Int64, video_track_index: Int = 0, clip_index: Int = -1, track_index: Int = 0) {
        self.item_indicate = item_indicate
        self.package_id = package_id
        self.name = name
        self.in_point = in_point
        self.out_point = out_point
        self.video_track_index = video_track_index
        self.clip_index = clip_index
        self.track_index = track_index
    }
}

struct AIETemplateTransform: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 变换参数（支持关键帧动画）
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 是否有动画（有关键帧）
    var is_animation: Bool = false

    /// 关键帧列表
    var keyframes: [AIETemplateTransformKeyframe] = []

    /// X 轴平移
    var translate_x: Float = 0.0

    /// Y 轴平移
    var translate_y: Float = 0.0

    /// X 缩放
    var scale_x: Float = 1.0

    /// Y 轴缩放
    var scale_y: Float = 1.0

    /// 旋转角度
    var rotation: Float = 0.0

    /// 透明度 (0.0 - 1.0)
    var opacity: Float = 1.0
}

struct AIETemplateTransformKeyframe: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 变换关键帧
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 时间位置（相对于片段入点）
    var position: Int64

    /// X 轴平移
    var translate_x: Float

    /// Y 轴平移
    var translate_y: Float

    /// 缩放 X
    var scale_x: Float

    /// 缩放 Y
    var scale_y: Float

    /// 旋转角度
    var rotation: Float

    /// 透明度
    var opacity: Float

    /// 曲线类型（1=线性, 2=贝塞尔等）
    var curve_type: Int = 1
}

struct AIETemplateTransition: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 转场配置
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 前一个片段 ID（也是 transitionDataDic 的 key）
    var prev: String

    /// 后一个片段 ID
    var next: String

    /// 转场包 ID（存储在原始数据的 desc 字段中）
    var package_id: String

    /// 转场名称
    var transition: String?

    /// 转场时长
    var video_transition_duration: Int64 = 1000000

    /// 转场时长缩放因子
    var video_transition_duration_scale_factor: Float = 1.0

    init(prev: String, next: String, package_id: String, transition: String?, video_transition_duration: Int64 = 1000000, duration_scale_factor: Float = 1.0) {
        self.prev = prev
        self.next = next
        self.package_id = package_id
        self.transition = transition
        self.video_transition_duration = video_transition_duration
        self.video_transition_duration_scale_factor = duration_scale_factor
    }
}

struct AIETemplateMaterial: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 素材占位符
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 占位符唯一 ID
    var package_id: String

    /// 素材类型: video, audio, image，filter，effect
    var media_type: String

    /// 描述
    var description: String?

    init(package_id: String, media_type: String, description: String? = nil) {
        self.package_id = package_id
        self.media_type = media_type
        self.description = description
    }
}

struct AIETemplatePlaceholder: Codable {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 素材占位时长与轨道类型
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 轨道类型: 0=PIP(画中画), 1=主轨
    var track_type: Int

    /// 素材时长（秒，保留一位小数）
    var seconds: CGFloat
}
