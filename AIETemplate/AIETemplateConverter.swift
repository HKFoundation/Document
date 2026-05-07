//
//  AIETemplateConverter.swift
//  AIEditorKit
//
//  Created by ✐ ᵕ̈ ᴹᴼᴿᴺᴵᴺᴳ on 2026/4/15.
//

import Foundation

/// info.json 转换为 AIETemplatePluginProtocol 的解析器
final class AIETemplateConverter {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 错误类型
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    enum AIEConverterError: Error, LocalizedError {
        case invalidFormat

        case missingRequiredField(String)

        case parsingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Draft parser invalid format"
            case let .missingRequiredField(field):
                return "Draft parser missing required field: \(field)"
            case let .parsingFailed(message):
                return "Draft parser failed: \(message)"
            }
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 转换方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 将 info.json Data 转换为 AIETemplatePluginProtocol
    static func convert(name: String, data: Data) throws -> AIETemplatePluginProtocol {
        guard let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIEConverterError.invalidFormat
        }
        return try self.convert(name: name, dictionary: dictionary)
    }

    /// 将 info.json 字典转换为 AIETemplatePluginProtocol
    static func convert(name: String, dictionary: [String: Any]) throws -> AIETemplatePluginProtocol {
        // 模板名字
        var template = AIETemplatePluginProtocol(name: name)

        // 解析设置
        template.settings = self.parseSettings(from: dictionary)

        // 解析视频轨道
        template.videos = try self.parseVideoTracks(from: dictionary, materialList: &template.material)

        // 解析音频轨道
        template.audios = try self.parseAudioTracks(from: dictionary, materialList: &template.material)

        // 解析字幕轨道
        template.captions = self.parseCaptionTracks(from: dictionary)

        // 解析贴纸轨道
        template.stickers = self.parseStickerTracks(from: dictionary)

        // 解析全局特效
        template.effects = try self.parseTimelineEffects(from: dictionary)

        // 解析转场配置
        template.transitions = try self.parseTransitions(from: dictionary)

        // 解析滤镜和特效素材
        self.parseEffectMaterials(from: dictionary, materialList: &template.material)

        // 解析全局滤镜
        template.filters = self.parseTimelineFilters(from: dictionary)

        // 解析画中画轨道
        template.pips = try self.parsePipTracks(from: dictionary, materialList: &template.material)

        // 解析素材占位时长
        template.placeholder = try self.parsePlaceholderFromClip(from: dictionary)

        return template
    }

    /// 从文件路径转换并保存
    static func convert(name: String, inputFilePath: String, outputFilePath: String) throws {
        var url = URL(fileURLWithPath: inputFilePath)
        var data = try Data(contentsOf: url)

        let template = try convert(name: name, data: data)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        data = try encoder.encode(template)
        url = URL(fileURLWithPath: outputFilePath)
        try data.write(to: url)
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 配置信息解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseSettings(from dictionary: [String: Any]) -> AIETemplateSettings {
        var settings = AIETemplateSettings()

        settings.image_height = dictionary["imageHeight"] as? Int ?? 1080
        settings.image_width = dictionary["imageWidth"] as? Int ?? 1920
        settings.aspect_ratio_mode = dictionary["aspectRatioMode"] as? Int ?? 0
        settings.origin_aspect_ratio = dictionary["originAspectRatio"] as? Double ?? 1.7777778
        settings.preview_resolution = dictionary["previewResolution"] as? Int ?? 1080
        settings.video_fps_num = dictionary["videoFpsNum"] as? Int ?? 25
        settings.video_fps_den = dictionary["videoFpsDen"] as? Int ?? 1
        settings.is_muted = dictionary["isMute"] as? Bool ?? false

        return settings
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 视频轨道解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseVideoTracks(from dictionary: [String: Any], materialList: inout [AIETemplateMaterial]) throws -> [AIETemplateVideoTrack] {
        guard let clipDataArray = dictionary["clipDataArray"] as? [[String: Any]] else {
            return []
        }

        // 按 track_index 分组（只包含 track_index == 1 的主轨）
        var groups: [Int: [[String: Any]]] = [:]
        for clip in clipDataArray {
            let track_index = clip["trackIndex"] as? Int ?? 0
            // 只解析主轨 (track_index == 1)
            if track_index == 1 {
                if groups[track_index] == nil {
                    groups[track_index] = []
                }
                groups[track_index]?.append(clip)
            }
        }

        var videoTracks: [AIETemplateVideoTrack] = []

        for (track_index, clips) in groups.sorted(by: { $0.key < $1.key }) {
            var videoTrack = AIETemplateVideoTrack(track_index: track_index)
            videoTrack.clips = []

            for item in clips {
                let clip = try parseVideoClip(from: item, track_index: track_index, materialList: &materialList)
                videoTrack.clips.append(clip)
            }

            // 按 position 排序
            videoTrack.clips.sort { $0.position < $1.position }

            videoTracks.append(videoTrack)
        }

        return videoTracks
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 画中画轨道解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parsePipTracks(from dictionary: [String: Any], materialList: inout [AIETemplateMaterial]) throws -> [AIETemplateVideoTrack] {
        guard let pipClipDataArray = dictionary["pipClipDataArray"] as? [[String: Any]] else {
            return []
        }

        // 按 track_index 分组
        var groups: [Int: [[String: Any]]] = [:]
        for item in pipClipDataArray {
            let track_index = item["trackIndex"] as? Int ?? 2
            if groups[track_index] == nil {
                groups[track_index] = []
            }
            groups[track_index]?.append(item)
        }

        var pipTracks: [AIETemplateVideoTrack] = []

        for (track_index, clips) in groups.sorted(by: { $0.key < $1.key }) {
            var videoTrack = AIETemplateVideoTrack(track_index: track_index)
            videoTrack.clips = []

            for item in clips {
                let clip = try parseVideoClip(from: item, track_index: track_index, materialList: &materialList)
                videoTrack.clips.append(clip)
            }

            // 按 position 排序
            videoTrack.clips.sort { $0.position < $1.position }

            pipTracks.append(videoTrack)
        }

        return pipTracks
    }

    private static func parseVideoClip(from dictionary: [String: Any], track_index: Int, materialList: inout [AIETemplateMaterial]) throws -> AIETemplateVideoClip {
        let item_indicate = dictionary["itemIndicate"] as? String ?? UUID().uuidString
        let resource_id = dictionary["resourceId"] as? String ?? ""

        var clip = AIETemplateVideoClip(
            item_indicate: item_indicate,
            track_index: track_index,
            position: dictionary["inPoint"] as? Int64 ?? 0,
            trim_in: dictionary["trimIn"] as? Int64 ?? 0,
            trim_out: dictionary["trimOut"] as? Int64 ?? 0,
            resource_id: resource_id
        )

        // 解析片段索引
        clip.clip_index = dictionary["clipIndex"] as? Int ?? 0

        clip.is_muted = (dictionary["templateDraft"] as? [String: Any])?["sourceMuted"] as? Bool ?? false

        // 解析变速模型
        clip.speed = self.parseSpeedFromClip(from: dictionary)

        // 解析滤镜（从 videoRawFxArray 中提取）
        let trim_out = dictionary["trimOut"] as? Int64 ?? 0
        clip.filters = self.parseFiltersFromClip(from: dictionary, clip_id: item_indicate, clipTrimOut: trim_out)

        // 解析调节参数
        clip.adjusts = self.parseAdjustFromClip(from: dictionary)

        // 解析变换参数
        clip.transform = self.parseTransformFromClip(from: dictionary)

        // 解析蒙版参数
        clip.mask = self.parseMaskFromClip(from: dictionary)

        // 解析音量参数
        clip.volume = self.parseVolumeFromClip(from: dictionary)

        // 解析裁剪参数
        clip.crop = self.parseCropFromClip(from: dictionary)

        // 解析片段动画（入场动画、出场动画）
        clip.animation = self.parseAnimationFromClip(from: dictionary)

        // 解析混合模式
        clip.blend_mode = dictionary["blendMode"] as? Int ?? 0

        // 解析倒放标记
        clip.is_reversed = dictionary["hasReversed"] as? Bool ?? false

        // 添加素材
        let material = AIETemplateMaterial(
            package_id: resource_id,
            media_type: "video",
            description: item_indicate
        )
        materialList.append(material)

        return clip
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 音频轨道解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseAudioTracks(from dictionary: [String: Any], materialList: inout [AIETemplateMaterial]) throws -> [AIETemplateAudioTrack] {
        guard let audioDataArray = dictionary["audioDataArray"] as? [[String: Any]] else {
            return []
        }

        // 按 track_index 分组
        var groups: [Int: [[String: Any]]] = [:]
        for audio in audioDataArray {
            let track_index = audio["trackIndex"] as? Int ?? 0
            if groups[track_index] == nil {
                groups[track_index] = []
            }
            groups[track_index]?.append(audio)
        }

        var audioTracks: [AIETemplateAudioTrack] = []

        for (track_index, clips) in groups.sorted(by: { $0.key < $1.key }) {
            var audioTrack = AIETemplateAudioTrack(track_index: track_index)
            audioTrack.clips = []

            for item in clips {
                let clip = try parseAudioClip(from: item, track_index: track_index, materialList: &materialList)
                audioTrack.clips.append(clip)
            }

            audioTrack.clips.sort { $0.position < $1.position }
            audioTracks.append(audioTrack)
        }

        return audioTracks
    }

    private static func parseAudioClip(from dictionary: [String: Any], track_index: Int, materialList: inout [AIETemplateMaterial]) throws -> AIETemplateAudioClip {
        let item_indicate = dictionary["itemIndicate"] as? String ?? UUID().uuidString
        let resource_id = dictionary["resourceId"] as? String ?? ""

        var clip = AIETemplateAudioClip(
            item_indicate: item_indicate,
            track_index: track_index,
            position: dictionary["inPoint"] as? Int64 ?? 0,
            trim_in: dictionary["trimIn"] as? Int64 ?? 0,
            trim_out: dictionary["trimOut"] as? Int64 ?? 0,
            resource_id: resource_id
        )

        // 音频类型: 0=外部音频文件, 1=录音, 2=视频提取音频
        clip.audio_type = dictionary["audioType"] as? Int ?? 0

        // 音频文件名（用于内置音频的显示名称）
        clip.name = dictionary["fileName"] as? String

        clip.left_volume_gain = (dictionary["leftVolumeGain"] as? NSNumber)?.floatValue ?? 1.0
        clip.right_volume_gain = (dictionary["rightVolumeGain"] as? NSNumber)?.floatValue ?? 1.0
        clip.speed = (dictionary["speed"] as? NSNumber)?.floatValue ?? 1.0
        clip.keep_audio_pitch = dictionary["keepAudioPitch"] as? Bool ?? true
        clip.fade_in_duration = dictionary["fadeInDuration"] as? Int64 ?? 0
        clip.fade_out_duration = dictionary["fadeOutDuration"] as? Int64 ?? 0

        // 添加音频素材（仅对外部音频文件添加素材）
        if clip.is_audio_file {
            let material = AIETemplateMaterial(
                package_id: resource_id,
                media_type: "audio",
                description: clip.name ?? item_indicate
            )
            materialList.append(material)
        }

        return clip
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 字幕轨道解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseCaptionTracks(from dictionary: [String: Any]) -> [AIETemplateCaptionTrack] {
        guard let captionDataArray = dictionary["captionDataArray"] as? [[String: Any]],
              !captionDataArray.isEmpty else {
            return []
        }

        var captionTrack = AIETemplateCaptionTrack()
        captionTrack.captions = []

        for item in captionDataArray {
            let caption = self.parseCaption(from: item)
            captionTrack.captions.append(caption)
        }

        return [captionTrack]
    }

    private static func parseCaption(from dictionary: [String: Any]) -> AIETemplateCaption {
        let item_indicate = dictionary["itemIndicate"] as? String ?? UUID().uuidString

        let caption = AIETemplateCaption(
            item_indicate: item_indicate,
            text: dictionary["captionText"] as? String ?? dictionary["text"] as? String ?? "",
            in_point: dictionary["inPoint"] as? Int64 ?? 0,
            out_point: dictionary["outPoint"] as? Int64 ?? 0
        )

        return caption
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 贴纸轨道解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseStickerTracks(from dictionary: [String: Any]) -> [AIETemplateStickerTrack] {
        guard let stickerDataArray = dictionary["stickerDataArray"] as? [[String: Any]],
              !stickerDataArray.isEmpty else {
            return []
        }

        var stickerTrack = AIETemplateStickerTrack()
        stickerTrack.stickers = []

        for item in stickerDataArray {
            let sticker = self.parseSticker(from: item)
            stickerTrack.stickers.append(sticker)
        }

        return [stickerTrack]
    }

    private static func parseSticker(from dictionary: [String: Any]) -> AIETemplateSticker {
        let item_indicate = dictionary["itemIndicate"] as? String ?? UUID().uuidString

        var sticker = AIETemplateSticker(
            item_indicate: item_indicate,
            package_id: dictionary["animatedStickerPackageId"] as? String ?? dictionary["packageId"] as? String ?? "",
            in_point: dictionary["inPoint"] as? Int64 ?? 0,
            out_point: dictionary["outPoint"] as? Int64 ?? 0
        )

        // 解析位置信息
        if let positionInfo = dictionary["positionInfo"] as? [String: Any] {
            sticker.position_x = positionInfo["translateX"] as? Float ?? 50.0
            sticker.position_y = positionInfo["translateY"] as? Float ?? 50.0
            sticker.scale = positionInfo["scale"] as? Float ?? 1.0
            sticker.rotation = positionInfo["rotation"] as? Float ?? 0.0
        }

        // 解析动画时长
        sticker.in_animation_duration = dictionary["inAnimationDuration"] as? Int32 ?? 0
        sticker.out_animation_duration = dictionary["outAnimationDuration"] as? Int32 ?? 0
        sticker.period_animation_duration = dictionary["periodAnimationDuration"] as? Int32 ?? 0

        // 解析封面图片路径
        sticker.cover_image_path = dictionary["coverImagePath"] as? String

        // 解析关键帧
        if let dictionary = dictionary["keyframes"] as? [String: [[String: Any]]] {
            let keyframes = self.parseStickerKeyframes(from: dictionary)
            if !keyframes.isEmpty {
                sticker.is_animation = true
                sticker.keyframes = keyframes
            }
        }

        return sticker
    }

    /// 解析贴纸关键帧
    private static func parseStickerKeyframes(from dictionary: [String: [[String: Any]]]) -> [AIETemplateStickerKeyframe] {
        // 收集所有非负位置的关键帧时间点
        var keyframePositions: Set<Int64> = []

        // 解析每个参数的关键帧
        for (_, keyframes) in dictionary {
            for item in keyframes {
                if let position = item["pos"] as? Int64, position >= 0 {
                    keyframePositions.insert(position)
                }
            }
        }

        // 如果没有非负位置的关键帧，检查是否有 pos=-1 的静态值
        if keyframePositions.isEmpty {
            // 创建位置为0的关键帧，包含所有静态默认值
            var keyframe = AIETemplateStickerKeyframe(
                position: 0,
                translate_x: 0.0,
                translate_y: 0.0,
                rotation: 0.0,
                scale: 1.0
            )

            // 解析 pos=-1 的静态值
            if let transXArray = dictionary["Sticker TransX"],
               let item = transXArray.first,
               let pos = item["pos"] as? Int64, pos == -1 {
                keyframe.translate_x = (item["value"] as? NSNumber)?.floatValue ?? 0.0
                if let curveParam = item["curveParam"] as? [String: Any] {
                    keyframe.curve_type = (curveParam["curveType"] as? NSNumber)?.intValue ?? 1
                }
            }
            if let transYArray = dictionary["Sticker TransY"],
               let item = transYArray.first,
               let pos = item["pos"] as? Int64, pos == -1 {
                keyframe.translate_y = (item["value"] as? NSNumber)?.floatValue ?? 0.0
            }
            if let rotationArray = dictionary["Sticker RotZ"],
               let item = rotationArray.first,
               let pos = item["pos"] as? Int64, pos == -1 {
                keyframe.rotation = (item["value"] as? NSNumber)?.floatValue ?? 0.0
            }
            if let scaleArray = dictionary["Sticker Scale"],
               let item = scaleArray.first,
               let pos = item["pos"] as? Int64, pos == -1 {
                keyframe.scale = (item["value"] as? NSNumber)?.floatValue ?? 1.0
            }

            return [keyframe]
        }

        // 按时间顺序排列
        let sorted = keyframePositions.sorted()

        // 构建完整的关键帧数据
        var result: [AIETemplateStickerKeyframe] = []

        for position in sorted {
            var keyframe = AIETemplateStickerKeyframe(
                position: position,
                translate_x: 0.0,
                translate_y: 0.0,
                rotation: 0.0,
                scale: 1.0
            )

            // 解析 Sticker TransX
            if let transXArray = dictionary["Sticker TransX"] {
                for item in transXArray {
                    if let pos = item["pos"] as? Int64, pos == position {
                        keyframe.translate_x = (item["value"] as? NSNumber)?.floatValue ?? 0.0
                        if let curveParam = item["curveParam"] as? [String: Any] {
                            keyframe.curve_type = (curveParam["curveType"] as? NSNumber)?.intValue ?? 1
                        }
                    }
                }
            }

            // 解析 Sticker TransY
            if let transYArray = dictionary["Sticker TransY"] {
                for item in transYArray {
                    if let pos = item["pos"] as? Int64, pos == position {
                        keyframe.translate_y = (item["value"] as? NSNumber)?.floatValue ?? 0.0
                    }
                }
            }

            // 解析 Sticker Rotation
            if let rotationArray = dictionary["Sticker RotZ"] {
                for item in rotationArray {
                    if let pos = item["pos"] as? Int64, pos == position {
                        keyframe.rotation = (item["value"] as? NSNumber)?.floatValue ?? 0.0
                    }
                }
            }

            // 解析 Sticker Scale
            if let scaleArray = dictionary["Sticker Scale"] {
                for item in scaleArray {
                    if let pos = item["pos"] as? Int64, pos == position {
                        keyframe.scale = (item["value"] as? NSNumber)?.floatValue ?? 1.0
                    }
                }
            }

            result.append(keyframe)
        }

        return result
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 特效解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseTimelineEffects(from dictionary: [String: Any]) throws -> [AIETemplateEffect] {
        guard let effectDataArray = dictionary["effectDataArray"] as? [[String: Any]] else {
            return []
        }

        var effects: [AIETemplateEffect] = []

        for item in effectDataArray {
            let effect = AIETemplateEffect(
                item_indicate: item["itemIndicate"] as? String ?? UUID().uuidString,
                package_id: item["packageId"] as? String ?? "",
                name: item["effectName"] as? String ?? item["effectNameEn"] as? String,
                in_point: item["inPoint"] as? Int64 ?? 0,
                out_point: item["outPoint"] as? Int64 ?? 0,
                video_track_index: item["videoTrackIndex"] as? Int ?? 0,
                clip_index: item["clipIndex"] as? Int ?? -1,
                track_index: item["trackIndex"] as? Int ?? 0
            )
            effects.append(effect)
        }

        return effects
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 转场解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseTransitions(from dictionary: [String: Any]) throws -> [String: AIETemplateTransition] {
        guard let model = dictionary["transitionDataDic"] as? [String: [String: Any]] else {
            return [:]
        }

        var transitions: [String: AIETemplateTransition] = [:]

        for (key, value) in model {
            let transition = AIETemplateTransition(
                prev: key,
                next: "",
                package_id: value["desc"] as? String ?? "",
                transition: nil,
                video_transition_duration: value["videoTransitionDuration"] as? Int64 ?? 1000000,
                duration_scale_factor: value["videoTransitionDurationScaleFactor"] as? Float ?? 1.0
            )
            transitions[key] = transition
        }

        // next 字段解析：从 clipDataArray 中获取相邻片段
        if let clipDataArray = dictionary["clipDataArray"] as? [[String: Any]] {
            for (index, clip) in clipDataArray.enumerated() {
                let clipId = clip["itemIndicate"] as? String ?? ""
                if var transition = transitions[clipId], index + 1 < clipDataArray.count {
                    let next = clipDataArray[index + 1]
                    transition.next = next["itemIndicate"] as? String ?? ""
                    transitions[clipId] = transition
                }
            }
        }

        return transitions
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 滤镜解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 解析时间线滤镜（Timeline 级别滤镜，独立于片段）
    private static func parseTimelineFilters(from dictionary: [String: Any]) -> [AIETemplateFilter] {
        var filters: [AIETemplateFilter] = []

        guard let filterDataArray = dictionary["filterDataArray"] as? [[String: Any]],
              !filterDataArray.isEmpty else {
            return filters
        }

        let duration = dictionary["timelineDuration"] as? Int64 ?? 0

        for item in filterDataArray {
            guard let package_id = item["packageId"] as? String,
                  !package_id.isEmpty else {
                continue
            }

            let filter = AIETemplateFilter(
                item_indicate: item["itemIndicate"] as? String ?? UUID().uuidString,
                package_id: package_id,
                name: item["filterName"] as? String ?? item["filterNameEn"] as? String,
                in_point: item["inPoint"] as? Int64 ?? 0,
                out_point: item["outPoint"] as? Int64 ?? duration,
                intensity: item["intensity"] as? Float ?? 1.0
            )
            filters.append(filter)
        }

        return filters
    }

    /// 解析片段滤镜（绑定到特定片段的滤镜，从 videoRawFxArray 中提取）
    private static func parseFiltersFromClip(from dictionary: [String: Any], clip_id: String, clipTrimOut: Int64) -> [AIETemplateFilter] {
        var filters: [AIETemplateFilter] = []

        // 从 videoRawFxArray 中提取滤镜
        if let videoRawFxArray = dictionary["videoRawFxArray"] as? [[String: Any]] {
            for fxItem in videoRawFxArray {
                // 通过 attachmentsSet.videoClipFxTypeTag 判断是否为滤镜
                let attachmentsSet = fxItem["attachmentsSet"] as? [String: Any]
                let fxTypeTag = attachmentsSet?["videoClipFxTypeTag"] as? String

                // videoFxType == 1 表示滤镜类型
                let videoFxType = fxItem["videoFxType"] as? Int

                if fxTypeTag == "filter" || videoFxType == 1 {
                    guard let package_id = fxItem["packageId"] as? String,
                          !package_id.isEmpty else {
                        continue
                    }

                    let in_point = fxItem["inPoint"] as? Int64 ?? 0
                    var out_point = fxItem["outPoint"] as? Int64 ?? clipTrimOut

                    // 如果 outPoint 为 -1，表示应用到片段结束
                    if out_point == -1 {
                        out_point = clipTrimOut
                    }

                    // 从 fxParams 中提取 Filter Intensity
                    var intensity: Float = 1.0
                    if let fxParams = fxItem["fxParams"] as? [String: Any],
                       let filterIntensityArray = fxParams["Filter Intensity"] as? [[String: Any]],
                       let filterIntensity = filterIntensityArray.first,
                       let value = filterIntensity["value"] as? NSNumber {
                        intensity = value.floatValue
                    } else if let fxIntensity = fxItem["intensity"] as? NSNumber {
                        intensity = fxIntensity.floatValue
                    }

                    var filter = AIETemplateFilter(
                        item_indicate: "\(clip_id)",
                        package_id: package_id,
                        name: nil,
                        in_point: in_point,
                        out_point: out_point,
                        intensity: intensity
                    )
                    filter.index = fxItem["index"] as? Int ?? 0
                    filters.append(filter)
                }
            }
        }

        return filters
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 变换解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseTransformFromClip(from dictionary: [String: Any]) -> AIETemplateTransform? {
        guard let videoPropertyFxModel = dictionary["videoPropertyFxModel"] as? [String: Any],
              let fxParams = videoPropertyFxModel["fxParams"] as? [String: Any] else {
            return nil
        }

        var transform = AIETemplateTransform()

        // 收集所有关键帧时间点
        var keyframePositions: Set<Int64> = []

        // 解析 Scale X 关键帧
        let scaleXKeyframes = self.parseFloatKeyframes(from: fxParams["Scale X"] as? [[String: Any]])
        for kf in scaleXKeyframes {
            keyframePositions.insert(kf.position)
        }

        // 解析 Scale Y 关键帧
        let scaleYKeyframes = self.parseFloatKeyframes(from: fxParams["Scale Y"] as? [[String: Any]])
        for kf in scaleYKeyframes {
            keyframePositions.insert(kf.position)
        }

        // 解析 Trans X 关键帧
        let transXKeyframes = self.parseFloatKeyframes(from: fxParams["Trans X"] as? [[String: Any]])
        for kf in transXKeyframes {
            keyframePositions.insert(kf.position)
        }

        // 解析 Trans Y 关键帧
        let transYKeyframes = self.parseFloatKeyframes(from: fxParams["Trans Y"] as? [[String: Any]])
        for kf in transYKeyframes {
            keyframePositions.insert(kf.position)
        }

        // 解析 Rotation 关键帧
        let rotationKeyframes = self.parseFloatKeyframes(from: fxParams["Rotation"] as? [[String: Any]])
        for kf in rotationKeyframes {
            keyframePositions.insert(kf.position)
        }

        // 判断是否有动画（有关键帧且关键帧数 > 1）
        if keyframePositions.count > 1 {
            transform.is_animation = true

            // 按时间顺序排列关键帧位置
            let sorted = keyframePositions.sorted()

            // 为每个关键帧位置构建完整的关键帧数据
            for position in sorted {
                var keyframe = AIETemplateTransformKeyframe(
                    position: position,
                    translate_x: 0.0,
                    translate_y: 0.0,
                    scale_x: 1.0,
                    scale_y: 1.0,
                    rotation: 0.0,
                    opacity: 1.0
                )

                // 从各参数的第一个关键帧中获取曲线类型
                if let firstKf = scaleXKeyframes.first {
                    keyframe.curve_type = firstKf.curve_type
                }

                // 查找对应时间点的关键帧值
                if let scaleXKf = scaleXKeyframes.first(where: { $0.position == position }) {
                    keyframe.scale_x = scaleXKf.value
                }
                if let scaleYKf = scaleYKeyframes.first(where: { $0.position == position }) {
                    keyframe.scale_y = scaleYKf.value
                }
                if let transXKf = transXKeyframes.first(where: { $0.position == position }) {
                    keyframe.translate_x = transXKf.value
                }
                if let transYKf = transYKeyframes.first(where: { $0.position == position }) {
                    keyframe.translate_y = transYKf.value
                }
                if let rotationKf = rotationKeyframes.first(where: { $0.position == position }) {
                    keyframe.rotation = rotationKf.value
                }

                transform.keyframes.append(keyframe)
            }
        } else {
            // 无动画，使用第一个关键帧的值作为静态值
            if let scaleX = scaleXKeyframes.first {
                transform.scale_x = scaleX.value
            }
            if let scaleY = scaleYKeyframes.first {
                transform.scale_y = scaleY.value
            }
            if let transX = transXKeyframes.first {
                transform.translate_x = transX.value
            }
            if let transY = transYKeyframes.first {
                transform.translate_y = transY.value
            }
            if let rotation = rotationKeyframes.first {
                transform.rotation = rotation.value
            }
        }

        return transform
    }

    /// 解析浮点型关键帧数组
    private static func parseFloatKeyframes(from array: [[String: Any]]?) -> [(position: Int64, value: Float, curve_type: Int)] {
        guard let array = array else { return [] }

        var keyframes: [(position: Int64, value: Float, curve_type: Int)] = []
        for item in array {
            let position = (item["pos"] as? NSNumber)?.int64Value ?? 0
            let value = (item["value"] as? NSNumber)?.floatValue ?? 0.0
            var curve_type = 1

            if let curveParam = item["curveParam"] as? [String: Any] {
                curve_type = (curveParam["curveType"] as? NSNumber)?.intValue ?? 1
            }

            keyframes.append((position: position, value: value, curve_type: curve_type))
        }

        return keyframes.sorted { $0.position < $1.position }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 音量解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 解析片段音量参数
    private static func parseVolumeFromClip(from dictionary: [String: Any]) -> AIETemplateClipVolume? {
        // 解析音量
        let left_volume_gain = (dictionary["leftVolumeGain"] as? NSNumber)?.floatValue ?? 1.0
        let right_volume_gain = (dictionary["rightVolumeGain"] as? NSNumber)?.floatValue ?? 1.0

        // 解析淡入淡出时长
        let fade_in_duration = dictionary["fadeInDuration"] as? Int64 ?? 0
        let fade_out_duration = dictionary["fadeOutDuration"] as? Int64 ?? 0

        // 如果所有值都是默认值，则返回 nil
        if left_volume_gain == 1.0 && right_volume_gain == 1.0
            && fade_in_duration == 0 && fade_out_duration == 0 {
            return nil
        }

        var volume = AIETemplateClipVolume()
        volume.left_volume_gain = left_volume_gain
        volume.right_volume_gain = right_volume_gain
        volume.fade_in_duration = fade_in_duration
        volume.fade_out_duration = fade_out_duration

        return volume
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 变速解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseSpeedFromClip(from dictionary: [String: Any]) -> AIETemplateClipSpeed? {
        guard let model = dictionary["curveSpeedModel"] as? [String: Any] else {
            return nil
        }

        var speed = AIETemplateClipSpeed()
        speed.speed = (model["speed"] as? NSNumber)?.floatValue ?? 1.0
        speed.keep_audio_pitch = model["keepAudioPitch"] as? Bool ?? true
        speed.curve_speed_id = model["curveSpeedsId"] as? String

        // 解析曲线变速字符串
        if let curveString = model["curveString"] as? [String: String] {
            speed.curve_speed_string = curveString
        }

        return speed
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 片段动画解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 解析片段动画（入场动画、出场动画）
    /// 从 videoPropertyFxModel 的 fxParams 中提取 Package Id、Package Effect In/Out
    private static func parseAnimationFromClip(from dictionary: [String: Any]) -> AIETemplateClipAnimation? {
        guard let videoPropertyFxModel = dictionary["videoPropertyFxModel"] as? [String: Any],
              let fxParams = videoPropertyFxModel["fxParams"] as? [String: Any],
              let attachmentsSet = videoPropertyFxModel["attachmentsSet"] as? [String: Any] else {
            return nil
        }

        // 检查 AnimationTypeTag 标识
        // - 0: 无动画 (none)
        // - 1: 入场+出场动画 (enter)
        // - 2: 出场动画 (out) - 单独出场
        // - 3: 循环动画 (combination)
        guard let animationTypeTagString = attachmentsSet["AnimationTypeTag"] as? String,
              let animationType = Int(animationTypeTagString),
              animationType > 0 else {
            return nil
        }

        var animation = AIETemplateClipAnimation()
        animation.animation_type = animationType

        // 处理 AnimationTypeTag = 1 (入场) 或 2 (出场) 的情况
        if animationType == 1 || animationType == 2 {
            // 入场动画：从 Package Id 或 Post Package Id 提取
            let packageId = self.getFxStringValue(from: fxParams, key: "Package Id")
            let postPackageId = self.getFxStringValue(from: fxParams, key: "Post Package Id")

            // 如果 Post Package Id 有值，使用它（isInPostPackage = true）
            if !postPackageId.isEmpty {
                animation.in_package_id = postPackageId
            } else if !packageId.isEmpty {
                animation.in_package_id = packageId
            }

            // 入场动画时长
            if let effectOutArray = fxParams["Package Effect Out"] as? [[String: Any]],
               let effectOutItem = effectOutArray.first,
               let effectOutValue = effectOutItem["value"] as? NSNumber {
                animation.in_trim_out = effectOutValue.int64Value
            }

            // 出场动画：从 Package2 Id 或 Post Package2 Id 提取
            let package2Id = self.getFxStringValue(from: fxParams, key: "Package2 Id")
            let postPackage2Id = self.getFxStringValue(from: fxParams, key: "Post Package2 Id")

            if !postPackage2Id.isEmpty {
                animation.out_package_id = postPackage2Id
            } else if !package2Id.isEmpty {
                animation.out_package_id = package2Id
            }

            // 出场动画时长
            if let effect2InArray = fxParams["Package2 Effect In"] as? [[String: Any]],
               let effect2InItem = effect2InArray.first,
               let effect2InValue = effect2InItem["value"] as? NSNumber {
                animation.out_trim_in = effect2InValue.int64Value
            }

            if let effect2OutArray = fxParams["Package2 Effect Out"] as? [[String: Any]],
               let effect2OutItem = effect2OutArray.first,
               let effect2OutValue = effect2OutItem["value"] as? NSNumber {
                animation.out_trim_out = effect2OutValue.int64Value
            }
        }

        // 处理 AnimationTypeTag = 3 (combination) 的情况
        else if animationType == 3 {
            // 循环动画：从 Post Package Id 或 Package Id 提取
            let postPackageId = self.getFxStringValue(from: fxParams, key: "Post Package Id")
            let packageId = self.getFxStringValue(from: fxParams, key: "Package Id")

            if !postPackageId.isEmpty {
                animation.period_package_id = postPackageId
            } else if !packageId.isEmpty {
                animation.period_package_id = packageId
            }

            // 循环动画时长
            if let effectOutArray = fxParams["Package Effect Out"] as? [[String: Any]],
               let effectOutItem = effectOutArray.first,
               let effectOutValue = effectOutItem["value"] as? NSNumber {
                animation.period_trim_out = effectOutValue.int64Value
            }
        }

        return animation.is_valid ? animation : nil
    }

    /// 从 fxParams 获取字符串值
    private static func getFxStringValue(from fxParams: [String: Any], key: String) -> String {
        if let array = fxParams[key] as? [[String: Any]],
           let item = array.first,
           let value = item["value"] as? String {
            return value
        }
        return ""
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 蒙版解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 解析蒙版参数
    private static func parseMaskFromClip(from dictionary: [String: Any]) -> AIETemplateClipMask? {
        guard let videoPropertyFxModel = dictionary["videoPropertyFxModel"] as? [String: Any],
              let fxParams = videoPropertyFxModel["fxParams"] as? [String: Any],
              let attachmentsSet = videoPropertyFxModel["attachmentsSet"] as? [String: Any] else {
            return nil
        }

        // 检查是否有蒙版类型（蒙版必须有 MSTemplate-MaskType）
        guard let mask_type = attachmentsSet["MSTemplate-MaskType"] as? String,
              !mask_type.isEmpty else {
            return nil
        }

        var mask = AIETemplateClipMask()
        mask.mask_type = mask_type

        // 解析反向蒙版
        if let inverseArray = fxParams["Mask Inverse Region"] as? [[String: Any]],
           let inverseItem = inverseArray.first {
            mask.inverse = inverseItem["value"] as? Bool ?? false
        }

        // 解析蒙版区域关键帧
        let regionKeyframes = self.parseMaskRegionKeyframes(from: fxParams["Mask Region Info"] as? [[String: Any]])

        // 解析羽化宽度关键帧
        let featherKeyframes = self.parseMaskFeatherKeyframes(from: fxParams["Mask Feather Width"] as? [[String: Any]])

        // 判断是否有动画
        if regionKeyframes.count > 1 || featherKeyframes.count > 1 {
            mask.is_animation = true
            mask.region_info_keyframes = regionKeyframes
            mask.feather_width_keyframes = featherKeyframes
        } else {
            // 无动画，使用第一个关键帧的值作为静态值
            if let firstFeather = featherKeyframes.first {
                mask.feather_width = firstFeather.feather_width
            }
            // 优先使用 region_info_keyframes 中的值（position=0 的默认关键帧）
            if let firstRegion = regionKeyframes.first {
                mask.region_info = firstRegion.region_info
            }
        }

        return mask
    }

    /// 解析蒙版区域关键帧
    private static func parseMaskRegionKeyframes(from array: [[String: Any]]?) -> [AIETemplateMaskRegionKeyframe] {
        guard let array = array else { return [] }

        var keyframes: [AIETemplateMaskRegionKeyframe] = []
        for item in array {
            let position = (item["pos"] as? NSNumber)?.int64Value ?? 0
            // 处理有效的关键帧：pos >= 0 或 pos == -1（默认值）
            guard position >= 0 || position == -1 else { continue }

            if let region_info = item["value"] as? String {
                // 如果 position 是 -1，转换为 0（表示在片段开始时使用）
                let effectivePosition: Int64 = position == -1 ? 0 : position
                let keyframe = AIETemplateMaskRegionKeyframe(position: effectivePosition, region_info: region_info)
                keyframes.append(keyframe)
            }
        }

        return keyframes.sorted { $0.position < $1.position }
    }

    /// 解析蒙版羽化宽度关键帧
    private static func parseMaskFeatherKeyframes(from array: [[String: Any]]?) -> [AIETemplateMaskFeatherKeyframe] {
        guard let array = array else { return [] }

        var keyframes: [AIETemplateMaskFeatherKeyframe] = []
        for item in array {
            let position = (item["pos"] as? NSNumber)?.int64Value ?? 0
            // 处理有效的关键帧：pos >= 0 或 pos == -1（默认值）
            guard position >= 0 || position == -1 else { continue }

            let value = (item["value"] as? NSNumber)?.floatValue ?? 0
            var curve_type = 1

            if let curveParam = item["curveParam"] as? [String: Any] {
                curve_type = (curveParam["curveType"] as? NSNumber)?.intValue ?? 1
            }

            // 如果 position 是 -1，转换为 0（表示在片段开始时使用）
            let effectivePosition: Int64 = position == -1 ? 0 : position
            let keyframe = AIETemplateMaskFeatherKeyframe(position: effectivePosition, feather_width: value, curve_type: curve_type)
            keyframes.append(keyframe)
        }

        return keyframes.sorted { $0.position < $1.position }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 调节解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 解析调节参数（从 videoRawFxArray 中提取 adjust 类型的效果）
    private static func parseAdjustFromClip(from dictionary: [String: Any]) -> AIETemplateClipAdjusts? {
        guard let videoRawFxArray = dictionary["videoRawFxArray"] as? [[String: Any]],
              !videoRawFxArray.isEmpty else {
            return nil
        }

        var adjusts = AIETemplateClipAdjusts()

        for fxItem in videoRawFxArray {
            // 通过 attachmentsSet.videoClipFxTypeTag 判断是否为调节
            let attachmentsSet = fxItem["attachmentsSet"] as? [String: Any]
            let fxTypeTag = attachmentsSet?["videoClipFxTypeTag"] as? String

            guard fxTypeTag == "adjust" else { continue }

            guard let type = fxItem["builtinName"] as? String else { continue }

            var adjustItem = AIETemplateClipAdjustItem(type: type)
            adjustItem.index = fxItem["index"] as? Int ?? 0

            // 解析 fxParams 中的参数
            if let fxParams = fxItem["fxParams"] as? [String: Any] {
                // BasicImageAdjust
                if let brightnessArray = fxParams["Brightness"] as? [[String: Any]],
                   let brightness = brightnessArray.first {
                    adjustItem.brightness = (brightness["value"] as? NSNumber)?.floatValue ?? 0.0
                }
                if let contrastArray = fxParams["Contrast"] as? [[String: Any]],
                   let contrast = contrastArray.first {
                    adjustItem.contrast = (contrast["value"] as? NSNumber)?.floatValue ?? 1.0
                }
                if let saturationArray = fxParams["Saturation"] as? [[String: Any]],
                   let saturation = saturationArray.first {
                    adjustItem.saturation = (saturation["value"] as? NSNumber)?.floatValue ?? 1.0
                }
                if let exposureArray = fxParams["Exposure"] as? [[String: Any]],
                   let exposure = exposureArray.first {
                    adjustItem.exposure = (exposure["value"] as? NSNumber)?.floatValue ?? 0.0
                }
                if let highlightArray = fxParams["Highlight"] as? [[String: Any]],
                   let highlight = highlightArray.first {
                    adjustItem.highlight = (highlight["value"] as? NSNumber)?.floatValue ?? 0.0
                }
                if let shadowArray = fxParams["Shadow"] as? [[String: Any]],
                   let shadow = shadowArray.first {
                    adjustItem.shadow = (shadow["value"] as? NSNumber)?.floatValue ?? 0.0
                }

                // Fade (褪色)
                if let fadeArray = fxParams["Blackpoint"] as? [[String: Any]],
                   let fade = fadeArray.first {
                    adjustItem.fade = (fade["value"] as? NSNumber)?.floatValue ?? 0.0
                }

                // Tint
                if let temperatureArray = fxParams["Temperature"] as? [[String: Any]],
                   let temperature = temperatureArray.first {
                    adjustItem.temperature = (temperature["value"] as? NSNumber)?.floatValue ?? 0.0
                }
                if let tintArray = fxParams["Tint"] as? [[String: Any]],
                   let tint = tintArray.first {
                    adjustItem.tint = (tint["value"] as? NSNumber)?.floatValue ?? 0.0
                }

                // Vignette
                if let degreeArray = fxParams["Degree"] as? [[String: Any]],
                   let degree = degreeArray.first {
                    adjustItem.vignette_intensity = (degree["value"] as? NSNumber)?.floatValue ?? 0.0
                }

                // Sharpen
                if let amountArray = fxParams["Amount"] as? [[String: Any]],
                   let amount = amountArray.first {
                    adjustItem.sharpen_amount = (amount["value"] as? NSNumber)?.floatValue ?? 0.0
                }
            }

            adjusts.items.append(adjustItem)
        }

        return adjusts.items.isEmpty ? nil : adjusts
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 裁剪解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 解析片段裁剪参数
    private static func parseCropFromClip(from dictionary: [String: Any]) -> AIETemplateClipCrop? {
        guard let videoRawFxArray = dictionary["videoRawFxArray"] as? [[String: Any]] else {
            return nil
        }

        var crop: AIETemplateClipCrop?

        for fx in videoRawFxArray {
            guard let type = fx["builtinName"] as? String else { continue }

            // 获取 attachmentsSet
            let attachmentsSet = fx["attachmentsSet"] as? [String: Any] ?? [:]

            if type == "Transform 2D" {
                // 裁剪时的变换
                if attachmentsSet["videoClipFxTypeTag"] as? String == "cropperTrans" {
                    if crop == nil {
                        crop = AIETemplateClipCrop()
                    }

                    // 解析变换参数
                    if let fxParams = fx["fxParams"] as? [String: Any] {
                        if let scaleXArray = fxParams["Scale X"] as? [[String: Any]],
                           let scaleX = scaleXArray.first {
                            crop?.scale_x = (scaleX["value"] as? NSNumber)?.floatValue ?? 1.0
                        }
                        if let scaleYArray = fxParams["Scale Y"] as? [[String: Any]],
                           let scaleY = scaleYArray.first {
                            crop?.scale_y = (scaleY["value"] as? NSNumber)?.floatValue ?? 1.0
                        }
                        if let transXArray = fxParams["Trans X"] as? [[String: Any]],
                           let transX = transXArray.first {
                            crop?.translate_x = (transX["value"] as? NSNumber)?.floatValue ?? 0.0
                        }
                        if let transYArray = fxParams["Trans Y"] as? [[String: Any]],
                           let transY = transYArray.first {
                            crop?.translate_y = (transY["value"] as? NSNumber)?.floatValue ?? 0.0
                        }
                        if let rotationArray = fxParams["Rotation"] as? [[String: Any]],
                           let rotation = rotationArray.first {
                            crop?.rotation = (rotation["value"] as? NSNumber)?.floatValue ?? 0.0
                        }
                    }
                }
            } else if type == "Crop" {
                // 裁剪边界框
                if attachmentsSet["videoClipFxTypeTag"] as? String == "cropperMask" {
                    if crop == nil {
                        crop = AIETemplateClipCrop()
                    }

                    // 解析边界框参数
                    if let fxParams = fx["fxParams"] as? [String: Any] {
                        if let aspect_ratio_mode = attachmentsSet["CropAspectRatioMode"] as? String {
                            crop?.aspect_ratio_mode = aspect_ratio_mode
                        }

                        if let boundingLeftArray = fxParams["Bounding Left"] as? [[String: Any]],
                           let bounding_left = boundingLeftArray.first {
                            crop?.bounding_left = (bounding_left["value"] as? NSNumber)?.floatValue ?? -1.0
                        }
                        if let boundingRightArray = fxParams["Bounding Right"] as? [[String: Any]],
                           let bounding_right = boundingRightArray.first {
                            crop?.bounding_right = (bounding_right["value"] as? NSNumber)?.floatValue ?? 1.0
                        }
                        if let boundingTopArray = fxParams["Bounding Top"] as? [[String: Any]],
                           let bounding_top = boundingTopArray.first {
                            crop?.bounding_top = (bounding_top["value"] as? NSNumber)?.floatValue ?? 1.0
                        }
                        if let boundingBottomArray = fxParams["Bounding Bottom"] as? [[String: Any]],
                           let bounding_bottom = boundingBottomArray.first {
                            crop?.bounding_bottom = (bounding_bottom["value"] as? NSNumber)?.floatValue ?? -1.0
                        }
                    }
                }
            }
        }

        return crop
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 素材解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    private static func parseEffectMaterials(from dictionary: [String: Any], materialList: inout [AIETemplateMaterial]) {
        // 从滤镜中提取素材
        if let filterDataArray = dictionary["filterDataArray"] as? [[String: Any]] {
            for filter in filterDataArray {
                if let package_id = filter["packageId"] as? String, !package_id.isEmpty {
                    let material = AIETemplateMaterial(
                        package_id: package_id,
                        media_type: "filter",
                        description: filter["filterName"] as? String ?? filter["filterNameEn"] as? String
                    )
                    materialList.append(material)
                }
            }
        }

        // 从特效中提取素材
        if let effectDataArray = dictionary["effectDataArray"] as? [[String: Any]] {
            for effect in effectDataArray {
                if let package_id = effect["packageId"] as? String, !package_id.isEmpty {
                    let material = AIETemplateMaterial(
                        package_id: package_id,
                        media_type: "effect",
                        description: effect["effectName"] as? String ?? effect["effectNameEn"] as? String
                    )
                    materialList.append(material)
                }
            }
        }

        // 从片段动画中提取素材（入场动画、出场动画）
        self.parseAnimationMaterials(from: dictionary, materialList: &materialList)
    }

    /// 从片段动画中提取素材（入场动画、出场动画、循环动画）
    private static func parseAnimationMaterials(from dictionary: [String: Any], materialList: inout [AIETemplateMaterial]) {
        guard let clipDataArray = dictionary["clipDataArray"] as? [[String: Any]] else { return }

        for clip in clipDataArray {
            guard let videoPropertyFxModel = clip["videoPropertyFxModel"] as? [String: Any],
                  let attachmentsSet = videoPropertyFxModel["attachmentsSet"] as? [String: Any] else {
                continue
            }

            // 检查是否为片段动画（AnimationTypeTag == "2" 或 "3"）
            let animationTypeTag = attachmentsSet["AnimationTypeTag"] as? String
            guard animationTypeTag == "2" || animationTypeTag == "3" else { continue }

            guard let fxParams = videoPropertyFxModel["fxParams"] as? [String: Any] else { continue }

            // 提取入场动画素材
            if let packageIdArray = fxParams["Package Id"] as? [[String: Any]],
               let packageIdItem = packageIdArray.first,
               let package_id = packageIdItem["value"] as? String,
               !package_id.isEmpty {
                let material = AIETemplateMaterial(
                    package_id: package_id,
                    media_type: "animation",
                    description: "clipInAnimation"
                )
                materialList.append(material)
            }

            // 提取出场动画素材
            if let package2IdArray = fxParams["Package2 Id"] as? [[String: Any]],
               let package2IdItem = package2IdArray.first,
               let package2Id = package2IdItem["value"] as? String,
               !package2Id.isEmpty {
                let material = AIETemplateMaterial(
                    package_id: package2Id,
                    media_type: "animation",
                    description: "clipOutAnimation"
                )
                materialList.append(material)
            }

            // 提取循环动画素材（仅在循环动画模式下）
            if animationTypeTag == "3" {
                if let postPackageIdArray = fxParams["Post Package Id"] as? [[String: Any]],
                   let postPackageIdItem = postPackageIdArray.first,
                   let postPackageId = postPackageIdItem["value"] as? String,
                   !postPackageId.isEmpty {
                    let material = AIETemplateMaterial(
                        package_id: postPackageId,
                        media_type: "animation",
                        description: "clipPeriodAnimation"
                    )
                    materialList.append(material)
                }
            }
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 素材占位时长解析
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 解析素材占位时长
    /// - Parameter dictionary: 模板数据字典
    /// - Returns: 素材占位信息数组，包含轨道类型和时长
    private static func parsePlaceholderFromClip(from dictionary: [String: Any]) throws -> [AIETemplatePlaceholder] {
        // 素材时长字典（key: mediaFilePath, value: 时长）
        var mediaFiles: [String: Int64] = [:]

        // 素材顺序
        var mediaFilesOrder: [String] = []

        // 轨道类型数组（0=PIP, 1=主轨），与 mediaFilesOrder 一一对应
        var segmentTrackType: [Int] = []

        // 遍历主轨素材 (clipDataArray)
        if let clipDataArray = dictionary["clipDataArray"] as? [[String: Any]] {
            for item in clipDataArray {
                guard let mediaFilePath = item["mediaFilePath"] as? String else { continue }

                let trimIn = item["trimIn"] as? Int64 ?? 0
                let trimOut = item["trimOut"] as? Int64 ?? 0
                let interval = trimOut - trimIn

                if mediaFiles[mediaFilePath] == nil {
                    // 新文件，添加到集合和轨道类型
                    mediaFiles[mediaFilePath] = interval
                    mediaFilesOrder.append(mediaFilePath)
                    segmentTrackType.append(1) // 主轨
                } else {
                    // 已存在的文件，更新时长（保留最大值）
                    let old: Int64 = mediaFiles[mediaFilePath]!
                    if interval > old {
                        mediaFiles[mediaFilePath] = interval
                    }
                }
            }
        }

        // 遍历画中画素材 (pipClipDataArray)
        if let pipClipDataArray = dictionary["pipClipDataArray"] as? [[String: Any]] {
            // 按 trackIndex 和 editInPoint 排序
            let sortPipArray = pipClipDataArray.sorted { lhs, rhs in
                let lhsTrackIndex = lhs["trackIndex"] as? Int ?? 0
                let rhsTrackIndex = rhs["trackIndex"] as? Int ?? 0

                if lhsTrackIndex == rhsTrackIndex {
                    // 如果轨道相同，按开始时间排序
                    let lhsInPoint = (lhs["inPoint"] as? NSNumber)?.int64Value ?? 0
                    let rhsInPoint = (rhs["inPoint"] as? NSNumber)?.int64Value ?? 0
                    return lhsInPoint < rhsInPoint
                } else {
                    return lhsTrackIndex < rhsTrackIndex
                }
            }

            for item in sortPipArray {
                guard let mediaFilePath = item["mediaFilePath"] as? String else { continue }

                let trimIn = item["trimIn"] as? Int64 ?? 0
                let trimOut = item["trimOut"] as? Int64 ?? 0
                let interval = trimOut - trimIn

                if mediaFiles[mediaFilePath] == nil {
                    // 新文件，添加到集合和轨道类型
                    mediaFiles[mediaFilePath] = interval
                    mediaFilesOrder.append(mediaFilePath)
                    segmentTrackType.append(0) // PIP
                } else {
                    // 已存在的文件，更新时长（保留最大值）
                    let old: Int64 = mediaFiles[mediaFilePath]!
                    if interval > old {
                        mediaFiles[mediaFilePath] = interval
                    }
                }
            }
        }

        // 计算时长并构建占位信息数组
        // baseTime: 时间基准值（微秒），默认 1000000 (1秒)
        let baseTime: Int64 = 1000000

        var placeholder: [AIETemplatePlaceholder] = []
        for (index, key) in mediaFilesOrder.enumerated() {
            guard let value = mediaFiles[key] else { continue }

            // 将微秒转换为秒，保留一位小数
            let seconds = (CGFloat(value) / CGFloat(baseTime) * 10).rounded() / 10

            // 获取轨道类型（默认1为主轨）
            let trackType = index < segmentTrackType.count ? segmentTrackType[index] : 1

            let item = AIETemplatePlaceholder(
                track_type: trackType,
                seconds: seconds
            )
            placeholder.append(item)
        }

        return placeholder
    }
}
