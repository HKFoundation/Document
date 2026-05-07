//
//  AIETemplateProjectBuilder.swift
//  AIEditorKit
//
//  Created by ✐ ᵕ̈ ᴹᴼᴿᴺᴵᴺᴳ on 2026/4/15.
//

import Foundation
import NvMeicam
import NvStreamingSdkCore
import NvVideoEditor

enum AIEProjectBuilderError: LocalizedError {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 剪辑工程构建错误类型
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    case createProjectFailed

    case getTimelineFailed

    case missingMaterial(resourceId: String)

    case invalidTemplate(String)

    var errorDescription: String? {
        switch self {
        case .createProjectFailed:
            return "Project builder create project failed"
        case .getTimelineFailed:
            return "Project builder get timeline failed"
        case let .missingMaterial(resourceId):
            return "Project builder missing material: \(resourceId)"
        case let .invalidTemplate(message):
            return "Project builder invalid template data: \(message)"
        }
    }
}

struct AIEProjectInfo {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 工程信息
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    let project_id: String

    let name: String

    init(project_id: String, name: String) {
        self.project_id = project_id
        self.name = name
    }
}

/// 模板工程构建器：从 AIETemplatePluginProtocol 构建可编辑的剪辑工程
class AIETemplateProjectBuilder: NSObject {
    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 公开方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 快速构建：直接从 Converted.json 文件路径构建
    /// - Parameters:
    ///   - path: 模板 JSON 文件路径
    ///   - projectId: 模板工程文件夹
    ///   - aspectRatioMode: 目标比例模式（默认使用模板原始比例）
    ///   - completion: 完成回调
    @discardableResult
    static func buildProject(file path: String,
                             attachment: Data?,
                             projectId: String,
                             aspectRatioMode: NvEditAspectRatioMode? = nil,
                             completion: @escaping (Result<AIEProjectInfo, Error>) -> Void) -> Bool {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let template = try JSONDecoder().decode(AIETemplatePluginProtocol.self, from: data)
            return self.buildProject(
                from: template,
                attachment: attachment,
                projectId: projectId,
                aspectRatioMode: aspectRatioMode,
                completion: completion
            )
        } catch {
            completion(.failure(error))
            return false
        }
    }

    /// 从模板构建新工程
    /// - Parameters:
    ///   - template: AIETemplatePluginProtocol 模板数据（Converted.json 解析结果）
    ///   - attachment: 当前模板封面图，作为附件打包到文件中
    ///   - projectId: 模板工程文件夹
    ///   - aspectRatioMode: 目标比例模式（默认使用模板原始比例）
    ///   - completion: 完成回调，返回工程信息或错误
    @discardableResult
    static func buildProject(from template: AIETemplatePluginProtocol,
                             attachment: Data?,
                             projectId: String,
                             aspectRatioMode: NvEditAspectRatioMode? = nil,
                             completion: @escaping (Result<AIEProjectInfo, Error>) -> Void) -> Bool {
        // 1. 创建 NvTimelineModel
        let model = NvTimelineModel()
        model.projectId = projectId

        self.buildProcess(from: template,
                          attachment: attachment,
                          model: model,
                          aspectRatioMode: aspectRatioMode,
                          completion: completion)

        return true
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 私有方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 处理构建逻辑（素材注册完成后）
    /// - Parameters:
    ///   - template: 模板数据
    ///   - attachment: 当前模板封面图，作为附件打包到文件中
    ///   - model: Timeline 模型
    ///   - aspectRatioMode: 目标比例模式（默认使用模板原始比例）
    ///   - completion: 完成回调
    private static func buildProcess(from template: AIETemplatePluginProtocol,
                                     attachment: Data?,
                                     model: NvTimelineModel,
                                     aspectRatioMode: NvEditAspectRatioMode? = nil,
                                     completion: @escaping (Result<AIEProjectInfo, Error>) -> Void) {
        // 应用模板设置（分辨率、宽高比等）到 timelineModel
        self.applyTemplateSettings(template.settings, to: model, aspectRatioMode: aspectRatioMode)

        // 应用视频轨道（包含主轨 tracks 和画中画 clips）
        self.applyVideoTracks(template.videos, pipTracks: template.pips, to: model)

        // 应用音频轨道到 timelineModel.audioDataArray
        self.applyAudioTracks(template.audios, to: model)

        // 应用贴纸轨道
        self.applyStickerTracks(template.stickers, to: model)

        // 应用全局滤镜
        self.applyTimelineFilters(template.filters, to: model)

        // 应用全局特效
        self.applyTimelineEffects(template.effects, to: model)

        // 应用转场
        self.applyTransitions(template.transitions, to: model)

        self.buildProcess(from: template, attachment: attachment, model: model, completion: completion)
    }

    // Timeline 模型后处理
    private static func buildProcess(from template: AIETemplatePluginProtocol,
                                     attachment: Data?,
                                     model: NvTimelineModel,
                                     completion: @escaping (Result<AIEProjectInfo, Error>) -> Void) {
        DispatchQueue.main.async {
            // 保存 timeline 数据到 info.json
            NvProjectManager.storeTimelineData(model: model, waitUntilFinished: true) { flag in
                if flag {
                    // 计算项目总时长：遍历所有轨道，找到最长的结束时间
                    var duration: Int64 = 0

                    // 主轨视频片段
                    for clip in model.clipDataArray {
                        let microsecond = clip.outPoint - clip.inPoint
                        duration = max(duration, clip.inPoint + microsecond)
                    }

                    // 画中画片段
                    for clip in model.pipClipDataArray {
                        let microsecond = clip.outPoint - clip.inPoint
                        duration = max(duration, clip.inPoint + microsecond)
                    }

                    // 音频片段
                    for clip in model.audioDataArray {
                        let microsecond = clip.outPoint - clip.inPoint
                        duration = max(duration, clip.inPoint + microsecond)
                    }

                    // 更新封面图
                    self.configCopyCoverImage(from: attachment, model: model)

                    // 生成 project.json 文件
                    _ = NvProjectManager.updateProjectInfoFile(
                        projectId: model.projectId,
                        duration: duration,
                        projectType: 1,
                        segmentDurations: template.placeholder.map { $0.seconds },
                        segmentTrackType: template.placeholder.map { $0.track_type }
                    )

                    // 返回工程信息
                    let projectInfo = AIEProjectInfo(project_id: model.projectId, name: template.name)

                    completion(.success(projectInfo))
                }
            }
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 私有方法
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 将模板封面图拷贝到草稿文件夹中
    private static func configCopyCoverImage(from attachment: Data?,
                                             model: NvTimelineModel,) {
        let inputFilePath = NvProjectManager.projectPath() + "\(model.projectId)/cover.jpeg"

        let url = URL(fileURLWithPath: inputFilePath)

        do {
            try attachment?.write(to: url)
        } catch {
        }
    }

    /// 调整 timeline 尺寸（在 timeline 创建后调用）
    private static func configTimelinePreview(timeline: NvsTimeline,
                                              model: NvTimelineModel,
                                              configration: NvEditConfig) {
        let size = NvSdkUtils.calculateTimelineSize(
            editMode: model.aspectRatioMode,
            originAspectRatio: model.originAspectRatio,
            previewResolution: configration.previewConfig.previewResolution
        )

        NvTimelineDataManager.changePreviewSize(
            cTimeline: timeline,
            timelineModel: model,
            targetRes: CGSize(width: size.width, height: size.height)
        )
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用工程设置
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用模板设置
    private static func applyTemplateSettings(_ settings: AIETemplateSettings,
                                              to model: NvTimelineModel,
                                              aspectRatioMode: NvEditAspectRatioMode? = nil) {
        // 设置宽高比模式：如果提供了目标比例则使用目标比例，否则使用模板原始比例
        if let aspectRatioMode = aspectRatioMode {
            model.aspectRatioMode = aspectRatioMode
            model.originAspectRatio = Float(self.aspectRatioValue(for: aspectRatioMode))
        } else {
            model.aspectRatioMode = NvEditAspectRatioMode(rawValue: settings.aspect_ratio_mode) ?? .NvEditAspectRatioOriginal
            model.originAspectRatio = Float(settings.origin_aspect_ratio)
        }

        // 设置预览分辨率
        model.previewResolution = Int32(settings.preview_resolution)
    }

    /// 根据比例模式获取对应的比例值
    private static func aspectRatioValue(for mode: NvEditAspectRatioMode) -> Double {
        switch mode {
        case .NvEditAspectRatioOriginal:
            return 16.0 / 9.0
        case .NvEditAspectRatio9v16:
            return 9.0 / 16.0
        case .NvEditAspectRatio3v4:
            return 3.0 / 4.0
        case .NvEditAspectRatio1v1:
            return 1.0 / 1.0
        case .NvEditAspectRatio4v3:
            return 4.0 / 3.0
        case .NvEditAspectRatio16v9:
            return 16.0 / 9.0
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 添加音频片段
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用音频轨道
    /// - Parameters:
    ///   - tracks: 模板音频轨道列表
    ///   - model: Timeline 模型
    private static func applyAudioTracks(_ tracks: [AIETemplateAudioTrack], to model: NvTimelineModel) {
        for track in tracks {
            for item in track.clips {
                let clip = NvAudioClipModel()

                // 设置基本信息
                clip.itemIndicate = item.item_indicate
                clip.trackIndex = item.track_index

                // 时间参数
                clip.inPoint = item.position
                clip.outPoint = item.position + (item.trim_out - item.trim_in)
                clip.trimIn = item.trim_in
                clip.trimOut = item.trim_out
                clip.duration = item.trim_out - item.trim_in

                // 音频类型: 0=外部音频文件, 1=录音, 2=视频提取音频
                clip.audioType = NvAudioType(rawValue: item.audio_type) ?? .audio

                // 音频文件名
                clip.fileName = item.name ?? ""

                // 音量参数
                clip.leftVolumeGain = item.left_volume_gain
                clip.rightVolumeGain = item.right_volume_gain

                // 淡入淡出
                clip.fadeInDuration = item.fade_in_duration
                clip.fadeOutDuration = item.fade_out_duration

                // 速度参数
                clip.speed = Double(item.speed)
                clip.keepAudioPitch = item.keep_audio_pitch

                // 直接使用 resource_id
                clip.resourceId = item.resource_id

                model.audioDataArray.append(clip)
            }
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 添加视频片段
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用视频轨道（填充 clipDataArray/pipClipDataArray 到 timelineModel，timeline 由 openProject 创建）
    /// - Parameters:
    ///   - tracks: 模板视频轨道列表（仅包含主轨 track_index == 1）
    ///   - pipTracks: 画中画轨道列表（从 pipClipDataArray 解析）
    ///   - model: Timeline 模型
    private static func applyVideoTracks(_ tracks: [AIETemplateVideoTrack],
                                         pipTracks: [AIETemplateVideoTrack],
                                         to model: NvTimelineModel) {
        // 处理主轨片段
        self.applyClipModels(tracks: tracks, to: &model.clipDataArray)

        // 处理画中画片段
        self.applyClipModels(tracks: pipTracks, to: &model.pipClipDataArray)
    }

    /// 应用片段模型（主轨和画中画共用逻辑）
    private static func applyClipModels(tracks: [AIETemplateVideoTrack], to clipArray: inout [NvVideoClipModel]) {
        for track in tracks {
            for item in track.clips {
                // 创建 NvVideoClipModel
                let clip = NvVideoClipModel()

                // 直接使用 resource_id
                clip.resourceId = item.resource_id
                
                // 使用 resource_id 作为 mediaFilePath，确保素材替换时能正确匹配
                clip.mediaFilePath = item.resource_id

                clip.trackIndex = item.track_index

                // 设置 clipIndex 为模板中的 clip_index，确保唯一标识片段位置
                clip.clipIndex = item.clip_index

                // timeline 上的位置：直接使用 item.position（模板中的相对时间）
                clip.inPoint = item.position
                clip.outPoint = item.position + (item.trim_out - item.trim_in)

                // 素材内部裁剪
                clip.trimIn = item.trim_in
                clip.trimOut = item.trim_out

                // 设置 itemIndicate 用于后续查找
                clip.itemIndicate = item.item_indicate

                // 收集所有滤镜和调节效果，按原始 index 排序后合并
                var clipFxArray: [MeicamFx] = []
                clipFxArray.append(contentsOf: self.applyClipFilters(item.filters, item: item, clip: clip))
                clipFxArray.append(contentsOf: self.applyClipAdjusts(item.adjusts, clip: clip))
                clipFxArray.sort { $0.index < $1.index }
                clip.videoRawFxArray.append(contentsOf: clipFxArray)

                // 应用变速（常规变速和曲线变速）
                self.applyClipSpeed(item.speed, clip: clip)

                // 应用蒙版
                self.applyClipMask(item.mask, clip: clip)

                // 应用音量
                self.applyClipVolume(item.volume, clip: clip)

                // 应用变换（旋转、位移、缩放）
                self.applyClipTransform(item.transform, clip: clip)

                // 应用裁剪
                self.applyClipCrop(item.crop, clip: clip)

                // 应用片段动画（入场动画、出场动画）
                self.applyClipAnimation(item.animation, clip: clip)

                // 应用混合模式
                clip.blendMode = item.blend_mode

                // 应用倒放标记
                clip.hasReversed = item.is_reversed

                // 倒放时需要交换 trimIn 和 trimOut 的相对关系
                // 假设原视频时长为 total，倒放后的处理：
                // 原 trimIn -> 倒放后相当于 total - trimOut
                // 原 trimOut -> 倒放后相当于 total - trimIn
                // 由于 total 在构建时未知，这里只设置标记
                // 由 SDK 在播放时处理倒放逻辑

                clipArray.append(clip)
            }
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用滤镜
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用时间线滤镜（Timeline 级别滤镜，独立于片段）
    private static func applyTimelineFilters(_ filters: [AIETemplateFilter],
                                             to model: NvTimelineModel) {
        for item in filters {
            let filter = NvFilterModel()
            filter.packageId = item.package_id
            filter.filterName = item.name ?? ""
            filter.filterNameEn = item.name ?? ""
            filter.inPoint = item.in_point
            filter.outPoint = item.out_point
            filter.itemIndicate = item.item_indicate
            filter.isBuiltinFx = false
            filter.intensity = item.intensity

            model.filterDataArray.append(filter)
        }
    }

    /// 添加片段滤镜模型（填充 clip.videoRawFxArray）
    /// - Parameters:
    ///   - filters: 模板滤镜列表
    ///   - item: 模板视频片段
    ///   - clip: NvVideoClipModel
    private static func applyClipFilters(_ filters: [AIETemplateFilter],
                                         item: AIETemplateVideoClip,
                                         clip: NvVideoClipModel) -> [MeicamFx] {
        var fxArray: [MeicamFx] = []

        for filter in filters {
            let model = MeicamFx()
            model.fxSourceType = .videoFx
            model.addingMethod = .raw
            model.videoFxType = .package
            model.packageId = filter.package_id
            model.inPoint = filter.in_point

            // outPoint = -1 表示不指定 duration，滤镜持续整个 clip
            model.outPoint = filter.out_point > 0 ? filter.out_point : -1

            // 使用相对时间（clip 内部时间）
            model.absoluteTimeUsed = false
            model.intensity = filter.intensity
            model.index = UInt32(filter.index)
            model.attachmentsSet["videoClipFxTypeTag"] = "filter"

            fxArray.append(model)
        }

        return fxArray
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用特效
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用特效（Timeline 级别特效 + 主轨特效 + 片段特效）
    /// - videoTrackIndex < mainTrackIndex(1): Timeline 级别特效（全局特效）
    /// - videoTrackIndex == mainTrackIndex(1): 主轨特效
    /// - videoTrackIndex > mainTrackIndex(1): 片段特效
    private static func applyTimelineEffects(_ effects: [AIETemplateEffect],
                                             to model: NvTimelineModel) {
        for item in effects {
            let effect = NvEffectModel()
            effect.isBuiltinFx = false
            effect.effectName = item.name ?? ""
            effect.effectNameEn = item.name ?? ""
            effect.packageId = item.package_id
            effect.outPoint = item.out_point
            effect.itemIndicate = item.item_indicate
            effect.trackCompensateZValue = model.trackCompensateZValue

            // 开始时间：只有 in_point > 0 时才赋值
            if item.in_point > 0 {
                effect.inPoint = item.in_point
            }

            // 纵向轨道位置：只有 track_index >= 1 时才赋值
            if item.track_index >= 1 {
                effect.trackIndex = item.track_index
            }

            // 主轨特效：设置 videoTrackIndex 和 clip_index
            if item.video_track_index == mainTrackIndex {
                effect.videoTrackIndex = item.video_track_index
                effect.clipIndex = item.clip_index >= 0 ? item.clip_index : 0
            }

            model.effectDataArray.append(effect)
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用转场
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用转场到 timeline model
    /// - transitions: key 为前一个片段的 item_indicate
    private static func applyTransitions(_ transitions: [String: AIETemplateTransition],
                                         to model: NvTimelineModel) {
        for (_, item) in transitions {
            guard !item.package_id.isEmpty else { continue }

            let transition = NvTransitionDataModel()
            transition.transitionType = .package
            transition.desc = item.package_id
            transition.videoTransitionDurationScaleFactor = item.video_transition_duration_scale_factor
            transition.videoTransitionDuration = item.video_transition_duration

            model.transitionDataDic[item.prev] = transition
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用贴纸
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用贴纸轨道到 timeline model
    /// - Parameters:
    ///   - tracks: 模板贴纸轨道列表
    ///   - model: Timeline 模型
    private static func applyStickerTracks(_ tracks: [AIETemplateStickerTrack],
                                           to model: NvTimelineModel) {
        for track in tracks {
            for item in track.stickers {
                let sticker = NvStickerModel()
                sticker.itemIndicate = item.item_indicate
                sticker.animatedStickerPackageId = item.package_id
                sticker.inPoint = item.in_point
                sticker.outPoint = item.out_point
                sticker.coverImagePath = item.cover_image_path ?? ""
                sticker.inAnimationDuration = item.in_animation_duration
                sticker.outAnimationDuration = item.out_animation_duration
                sticker.periodAnimationDuration = item.period_animation_duration

                // 应用关键帧
                if item.is_animation && !item.keyframes.isEmpty {
                    self.applyStickerKeyframes(item.keyframes, to: sticker)
                }

                model.stickerDataArray.append(sticker)
            }
        }
    }

    /// 应用贴纸关键帧
    private static func applyStickerKeyframes(_ keyframes: [AIETemplateStickerKeyframe],
                                              to sticker: NvStickerModel) {
        var transXParams: [MeicamFxParam] = []
        var transYParams: [MeicamFxParam] = []
        var rotationParams: [MeicamFxParam] = []
        var scaleParams: [MeicamFxParam] = []

        for keyframe in keyframes {
            // Sticker TransX
            let transXParam = MeicamFxParam(key: "Sticker TransX", type: .float, value: Double(keyframe.translate_x), pos: keyframe.position)
            transXParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            transXParams.append(transXParam)

            // Sticker TransY
            let transYParam = MeicamFxParam(key: "Sticker TransY", type: .float, value: Double(keyframe.translate_y), pos: keyframe.position)
            transYParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            transYParams.append(transYParam)

            // Sticker Rotation
            let rotationParam = MeicamFxParam(key: "Sticker RotZ", type: .float, value: Double(keyframe.rotation), pos: keyframe.position)
            rotationParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            rotationParams.append(rotationParam)

            // Sticker Scale
            let scaleParam = MeicamFxParam(key: "Sticker Scale", type: .float, value: Double(keyframe.scale), pos: keyframe.position)
            scaleParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            scaleParams.append(scaleParam)
        }

        // 设置到 keyframes 字典
        sticker.keyframes["Sticker TransX"] = transXParams.sorted { $0.pos < $1.pos }
        sticker.keyframes["Sticker TransY"] = transYParams.sorted { $0.pos < $1.pos }
        sticker.keyframes["Sticker RotZ"] = rotationParams.sorted { $0.pos < $1.pos }
        sticker.keyframes["Sticker Scale"] = scaleParams.sorted { $0.pos < $1.pos }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用变速
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用变速到片段（构建阶段）
    /// - Parameters:
    ///   - speed: 模板变速模型
    ///   - clip: NvVideoClipModel
    private static func applyClipSpeed(_ speed: AIETemplateClipSpeed?,
                                       clip: NvVideoClipModel) {
        guard let speed = speed else { return }

        // 检查是否为曲线变速（curveSpeedsId != "none"）
        if let curveId = speed.curve_speed_id, curveId != "none", let curveString = speed.curve_speed_string {
            // 曲线变速
            clip.curveSpeedModel.curveSpeedsId = curveId
            clip.curveSpeedModel.curveString = curveString
            clip.curveSpeedModel.keepAudioPitch = speed.keep_audio_pitch
        } else {
            // 常规变速
            clip.curveSpeedModel.curveSpeedsId = "none"
            clip.curveSpeedModel.speed = Double(speed.speed)
            clip.curveSpeedModel.keepAudioPitch = speed.keep_audio_pitch
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用音量
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用片段音量
    /// - Parameters:
    ///   - volume: 模板音量模型
    ///   - clip: NvVideoClipModel
    private static func applyClipVolume(_ volume: AIETemplateClipVolume?, clip: NvVideoClipModel) {
        guard let volume = volume else { return }

        // 设置音量
        clip.leftVolumeGain = volume.left_volume_gain
        clip.rightVolumeGain = volume.right_volume_gain

        // 设置淡入淡出时长
        clip.fadeInDuration = volume.fade_in_duration
        clip.fadeOutDuration = volume.fade_out_duration
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用片段动画
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用片段动画（入场动画、出场动画、循环动画）
    /// - Parameters:
    ///   - animation: 模板片段动画模型
    ///   - clip: NvVideoClipModel
    private static func applyClipAnimation(_ animation: AIETemplateClipAnimation?,
                                           clip: NvVideoClipModel) {
        guard let animation = animation, animation.is_valid else { return }

        // 设置 AnimationTypeTag（1 = 入场+出场动画，2 = 出场动画，3 = 循环动画）
        clip.videoPropertyFxModel.attachmentsSet["AnimationTypeTag"] = "\(animation.animation_type)"

        // 入场动画：从 Package Id 或 Post Package Id 提取
        if let in_package_id = animation.in_package_id, !in_package_id.isEmpty {
            let packageIdParam = MeicamFxParam(key: "Package Id", type: .string, value: in_package_id)
            clip.videoPropertyFxModel.fxParams["Package Id"] = [packageIdParam]
        }

        // 入场动画时长 - 即使没有 Package Id 也需要设置（用于 AnimationTypeTag = 1 时）
        if animation.in_trim_out > 0 {
            let effectInParam = MeicamFxParam(key: "Package Effect In", type: .float, value: Double(animation.in_trim_in))
            clip.videoPropertyFxModel.fxParams["Package Effect In"] = [effectInParam]

            let effectOutParam = MeicamFxParam(key: "Package Effect Out", type: .float, value: Double(animation.in_trim_out))
            clip.videoPropertyFxModel.fxParams["Package Effect Out"] = [effectOutParam]
        }

        // 出场动画：从 Package2 Id 或 Post Package2 Id 提取
        if let out_package_id = animation.out_package_id, !out_package_id.isEmpty {
            let package2IdParam = MeicamFxParam(key: "Package2 Id", type: .string, value: out_package_id)
            clip.videoPropertyFxModel.fxParams["Package2 Id"] = [package2IdParam]
        }

        // 出场动画时长 - 即使没有 Package2 Id 也需要设置（用于 AnimationTypeTag = 1 时）
        if animation.out_trim_in > 0 || animation.out_trim_out > 0 {
            let effect2InParam = MeicamFxParam(key: "Package2 Effect In", type: .float, value: Double(animation.out_trim_in))
            clip.videoPropertyFxModel.fxParams["Package2 Effect In"] = [effect2InParam]

            let effect2OutParam = MeicamFxParam(key: "Package2 Effect Out", type: .float, value: Double(animation.out_trim_out))
            clip.videoPropertyFxModel.fxParams["Package2 Effect Out"] = [effect2OutParam]
        }

        // 循环动画（仅在循环动画模式下，即 AnimationTypeTag = 3）
        if animation.animation_type == 3 {
            if let period_package_id = animation.period_package_id, !period_package_id.isEmpty {
                let postPackageIdParam = MeicamFxParam(key: "Post Package Id", type: .string, value: period_package_id)
                clip.videoPropertyFxModel.fxParams["Post Package Id"] = [postPackageIdParam]

                // 循环动画时长
                if animation.period_trim_out > 0 {
                    let effectOutParam = MeicamFxParam(key: "Package Effect Out", type: .float, value: Double(animation.period_trim_out))
                    clip.videoPropertyFxModel.fxParams["Package Effect Out"] = [effectOutParam]
                }
            }
        }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用蒙版
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用蒙版到片段
    /// - Parameters:
    ///   - mask: 模板蒙版模型
    ///   - clip: NvVideoClipModel
    private static func applyClipMask(_ mask: AIETemplateClipMask?,
                                      clip: NvVideoClipModel) {
        guard let mask = mask, let mask_type = mask.mask_type, !mask_type.isEmpty else {
            return
        }

        // 设置蒙版类型
        clip.videoPropertyFxModel.attachmentsSet["MSTemplate-MaskType"] = mask_type

        // 设置蒙版坐标系统（NDC 坐标）
        let coordSystemParam = MeicamFxParam(key: "Mask Coordinate System", type: .string, value: "ndc")
        clip.videoPropertyFxModel.fxParams["Mask Coordinate System"] = [coordSystemParam]

        // 设置反向蒙版
        let inverseParam = MeicamFxParam(key: "Mask Inverse Region", type: .boolean, value: mask.inverse)
        clip.videoPropertyFxModel.fxParams["Mask Inverse Region"] = [inverseParam]

        // 检查是否有蒙版动画（关键帧）
        if mask.is_animation {
            // 应用蒙版关键帧动画
            self.applyClipMaskKeyframes(mask, to: clip)
        } else {
            // 设置羽化宽度
            let featherParam = MeicamFxParam(key: "Mask Feather Width", type: .float, value: Double(mask.feather_width))
            clip.videoPropertyFxModel.fxParams["Mask Feather Width"] = [featherParam]

            // 设置蒙版区域信息
            if let region_info = mask.region_info {
                let regionParam = MeicamFxParam(key: "Mask Region Info", type: .arbData, value: region_info as AnyObject)
                clip.videoPropertyFxModel.fxParams["Mask Region Info"] = [regionParam]
            } else {
                // 如果没有 region_info，创建一个默认的蒙版区域（防止蒙版不生效）
                let region_info = "{\"regionInfoArray\":[{\"points\":[{\"x\":-1,\"y\":1},{\"x\":1,\"y\":1},{\"x\":1,\"y\":-1},{\"x\":-1,\"y\":-1}],\"transform2d\":{\"anchor\":{\"x\":0,\"y\":0},\"rotation\":0,\"translation\":{\"x\":0,\"y\":0},\"scale\":{\"x\":1,\"y\":1}},\"type\":0,\"ellipse2d\":{\"theta\":0,\"b\":0,\"a\":0,\"center\":{\"x\":0,\"y\":0}},\"mirror\":{\"center\":{\"x\":0,\"y\":0},\"distance\":0,\"theta\":0}}]}"
                let regionParam = MeicamFxParam(key: "Mask Region Info", type: .arbData, value: region_info as AnyObject)
                clip.videoPropertyFxModel.fxParams["Mask Region Info"] = [regionParam]
            }
        }
    }

    /// 应用蒙版关键帧动画
    private static func applyClipMaskKeyframes(_ mask: AIETemplateClipMask, to clip: NvVideoClipModel) {
        // 收集所有关键帧时间点
        var keyframePositions: Set<Int64> = []
        for kf in mask.region_info_keyframes {
            keyframePositions.insert(kf.position)
        }
        for kf in mask.feather_width_keyframes {
            keyframePositions.insert(kf.position)
        }

        // 应用蒙版区域关键帧
        var regionParams: [MeicamFxParam] = []
        for kf in mask.region_info_keyframes {
            let param = MeicamFxParam(key: "Mask Region Info", type: .arbData, value: kf.region_info as AnyObject, pos: kf.position)
            regionParams.append(param)
        }
        clip.videoPropertyFxModel.fxParams["Mask Region Info"] = regionParams.sorted { $0.pos < $1.pos }

        // 应用羽化宽度关键帧
        var featherParams: [MeicamFxParam] = []
        for kf in mask.feather_width_keyframes {
            let param = MeicamFxParam(key: "Mask Feather Width", type: .float, value: Double(kf.feather_width), pos: kf.position)
            param.curveParam = self.configCurveParam(curve_type: kf.curve_type)
            featherParams.append(param)
        }
        clip.videoPropertyFxModel.fxParams["Mask Feather Width"] = featherParams.sorted { $0.pos < $1.pos }
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用变换（旋转、位移、缩放、透明度）
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用片段变换（旋转、位移、缩放、透明度）
    /// - Parameters:
    ///   - transform: 模板变换模型
    ///   - clip: NvVideoClipModel
    private static func applyClipTransform(_ transform: AIETemplateTransform?, clip: NvVideoClipModel) {
        guard let transform = transform else { return }

        // 检查是否有动画（关键帧）
        if transform.is_animation && !transform.keyframes.isEmpty {
            // 应用关键帧动画
            self.applyTransformKeyframes(transform.keyframes, to: clip)
        } else {
            // 应用静态值（非动画）
            // 缩放 X
            if transform.scale_x != 1.0 {
                let param = MeicamFxParam(key: "Scale X", type: .float, value: Double(transform.scale_x))
                clip.videoPropertyFxModel.fxParams["Scale X"] = [param]
            }

            // 缩放 Y
            if transform.scale_y != 1.0 {
                let param = MeicamFxParam(key: "Scale Y", type: .float, value: Double(transform.scale_y))
                clip.videoPropertyFxModel.fxParams["Scale Y"] = [param]
            }

            // 位移 X
            if transform.translate_x != 0.0 {
                let param = MeicamFxParam(key: "Trans X", type: .float, value: Double(transform.translate_x))
                clip.videoPropertyFxModel.fxParams["Trans X"] = [param]
            }

            // 位移 Y
            if transform.translate_y != 0.0 {
                let param = MeicamFxParam(key: "Trans Y", type: .float, value: Double(transform.translate_y))
                clip.videoPropertyFxModel.fxParams["Trans Y"] = [param]
            }

            // 旋转
            if transform.rotation != 0.0 {
                let param = MeicamFxParam(key: "Rotation", type: .float, value: Double(transform.rotation))
                clip.videoPropertyFxModel.fxParams["Rotation"] = [param]
            }

            // 透明度
            if transform.opacity != 1.0 {
                let param = MeicamFxParam(key: "Opacity", type: .float, value: Double(transform.opacity))
                clip.videoPropertyFxModel.fxParams["Opacity"] = [param]
            }
        }
    }

    /// 应用变换关键帧动画
    private static func applyTransformKeyframes(_ keyframes: [AIETemplateTransformKeyframe], to clip: NvVideoClipModel) {
        // 为每个关键帧参数创建关键帧数组
        var scaleXParams: [MeicamFxParam] = []
        var scaleYParams: [MeicamFxParam] = []
        var transXParams: [MeicamFxParam] = []
        var transYParams: [MeicamFxParam] = []
        var rotationParams: [MeicamFxParam] = []
        var opacityParams: [MeicamFxParam] = []

        for keyframe in keyframes {
            // Scale X
            let scaleXParam = MeicamFxParam(key: "Scale X", type: .float, value: Double(keyframe.scale_x), pos: keyframe.position)
            scaleXParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            scaleXParams.append(scaleXParam)

            // Scale Y
            let scaleYParam = MeicamFxParam(key: "Scale Y", type: .float, value: Double(keyframe.scale_y), pos: keyframe.position)
            scaleYParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            scaleYParams.append(scaleYParam)

            // Trans X
            let transXParam = MeicamFxParam(key: "Trans X", type: .float, value: Double(keyframe.translate_x), pos: keyframe.position)
            transXParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            transXParams.append(transXParam)

            // Trans Y
            let transYParam = MeicamFxParam(key: "Trans Y", type: .float, value: Double(keyframe.translate_y), pos: keyframe.position)
            transYParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            transYParams.append(transYParam)

            // Rotation
            let rotationParam = MeicamFxParam(key: "Rotation", type: .float, value: Double(keyframe.rotation), pos: keyframe.position)
            rotationParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            rotationParams.append(rotationParam)

            // Opacity
            let opacityParam = MeicamFxParam(key: "Opacity", type: .float, value: Double(keyframe.opacity), pos: keyframe.position)
            opacityParam.curveParam = self.configCurveParam(curve_type: keyframe.curve_type)
            opacityParams.append(opacityParam)
        }

        // 设置到 fxParams（按 position 排序）
        clip.videoPropertyFxModel.fxParams["Scale X"] = scaleXParams.sorted { $0.pos < $1.pos }
        clip.videoPropertyFxModel.fxParams["Scale Y"] = scaleYParams.sorted { $0.pos < $1.pos }
        clip.videoPropertyFxModel.fxParams["Trans X"] = transXParams.sorted { $0.pos < $1.pos }
        clip.videoPropertyFxModel.fxParams["Trans Y"] = transYParams.sorted { $0.pos < $1.pos }
        clip.videoPropertyFxModel.fxParams["Rotation"] = rotationParams.sorted { $0.pos < $1.pos }
        clip.videoPropertyFxModel.fxParams["Opacity"] = opacityParams.sorted { $0.pos < $1.pos }
    }

    /// 新增曲线参数
    private static func configCurveParam(curve_type: Int) -> MeicamFxCurveParam {
        let curveParam = MeicamFxCurveParam()
        curveParam.curveType = curve_type
        return curveParam
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用调节
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用调节效果到片段
    /// - Parameters:
    ///   - adjusts: 模板调节模型
    ///   - clip: NvVideoClipModel
    /// - Returns: 创建的 MeicamFx 数组
    private static func applyClipAdjusts(_ adjusts: AIETemplateClipAdjusts?,
                                         clip: NvVideoClipModel) -> [MeicamFx] {
        guard let adjusts = adjusts, !adjusts.items.isEmpty else { return [] }

        var fxArray: [MeicamFx] = []

        for item in adjusts.items {
            // 创建 MeicamFx 模型
            let fx = MeicamFx()
            fx.builtinName = item.type
            fx.fxSourceType = .videoFx
            fx.addingMethod = .raw
            fx.videoFxType = .builtin // 调节是内置特效
            fx.inPoint = 0
            fx.outPoint = -1 // -1 表示持续整个片段

            // 设置 attachmentsSet
            fx.attachmentsSet["videoClipFxTypeTag"] = "adjust"
            fx.attachmentsSet["videoClipFxIndicateTag"] = item.type

            // 根据调节类型设置 fxParams
            switch item.type {
            case "BasicImageAdjust":
                self.addAdjustParam(fx: fx, key: "Brightness", value: item.brightness)
                self.addAdjustParam(fx: fx, key: "Contrast", value: item.contrast)
                self.addAdjustParam(fx: fx, key: "Saturation", value: item.saturation)
                self.addAdjustParam(fx: fx, key: "Exposure", value: item.exposure)
                self.addAdjustParam(fx: fx, key: "Highlight", value: item.highlight)
                self.addAdjustParam(fx: fx, key: "Shadow", value: item.shadow)
                self.addAdjustParam(fx: fx, key: "Blackpoint", value: item.fade)
            case "Tint":
                self.addAdjustParam(fx: fx, key: "Temperature", value: item.temperature)
                self.addAdjustParam(fx: fx, key: "Tint", value: item.tint)
            case "Vignette":
                self.addAdjustParam(fx: fx, key: "Degree", value: item.vignette_intensity)
            case "Sharpen":
                self.addAdjustParam(fx: fx, key: "Amount", value: item.sharpen_amount)
            default:
                break
            }

            // 添加通用区域参数
            self.addAdjustParam(fx: fx, key: "Filter Intensity", value: 1.0)
            self.addAdjustBoolParam(fx: fx, key: "Enable Region", value: false)
            self.addAdjustBoolParam(fx: fx, key: "Enable Progress Mode", value: false)
            self.addAdjustParam(fx: fx, key: "Region Feather Width", value: Float(5.0))

            fx.index = UInt32(item.index)
            fxArray.append(fx)
        }

        return fxArray
    }

    /// 添加调节参数辅助方法
    private static func addAdjustParam(fx: MeicamFx, key: String, value: Float) {
        let param = MeicamFxParam(key: key, type: .float, value: Double(value))
        fx.fxParams[key] = [param]
    }

    /// 添加调节布尔参数辅助方法
    private static func addAdjustBoolParam(fx: MeicamFx, key: String, value: Bool) {
        let param = MeicamFxParam(key: key, type: .boolean, value: value)
        fx.fxParams[key] = [param]
    }

    /* ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*
     * // MARK: 应用裁剪
     * ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄＊ ┄┅┄┅┄┅┄┅┄*/

    /// 应用片段裁剪（Transform 2D + Crop）
    /// - Parameters:
    ///   - crop: 模板裁剪模型
    ///   - clip: NvVideoClipModel
    private static func applyClipCrop(_ crop: AIETemplateClipCrop?, clip: NvVideoClipModel) {
        guard let crop = crop else { return }

        var index: UInt32 = UInt32(clip.videoRawFxArray.count)

        // 1. 创建 Transform 2D 特效
        let transformFx = MeicamFx()
        transformFx.builtinName = "Transform 2D"
        transformFx.fxSourceType = .videoFx
        transformFx.addingMethod = .raw
        transformFx.videoFxType = .builtin
        transformFx.inPoint = 0
        transformFx.outPoint = -1
        transformFx.index = index
        transformFx.attachmentsSet["videoClipFxTypeTag"] = "cropperTrans"

        // 设置 Transform 2D 参数
        if crop.rotation != 0.0 {
            let param = MeicamFxParam(key: "Rotation", type: .float, value: Double(crop.rotation))
            transformFx.fxParams["Rotation"] = [param]
        }
        if crop.scale_x != 1.0 {
            let param = MeicamFxParam(key: "Scale X", type: .float, value: Double(crop.scale_x))
            transformFx.fxParams["Scale X"] = [param]
        }
        if crop.scale_y != 1.0 {
            let param = MeicamFxParam(key: "Scale Y", type: .float, value: Double(crop.scale_y))
            transformFx.fxParams["Scale Y"] = [param]
        }
        if crop.translate_x != 0.0 {
            let param = MeicamFxParam(key: "Trans X", type: .float, value: Double(crop.translate_x))
            transformFx.fxParams["Trans X"] = [param]
        }
        if crop.translate_y != 0.0 {
            let param = MeicamFxParam(key: "Trans Y", type: .float, value: Double(crop.translate_y))
            transformFx.fxParams["Trans Y"] = [param]
        }

        // 添加 Force Identical Position 和 Is Normalized Coord
        let forceIdenticalParam = MeicamFxParam(key: "Force Identical Position", type: .boolean, value: true)
        transformFx.fxParams["Force Identical Position"] = [forceIdenticalParam]
        let normalizedParam = MeicamFxParam(key: "Is Normalized Coord", type: .boolean, value: true)
        transformFx.fxParams["Is Normalized Coord"] = [normalizedParam]

        clip.videoRawFxArray.append(transformFx)
        index += 1

        // 2. 创建 Crop 特效
        let cropFx = MeicamFx()
        cropFx.builtinName = "Crop"
        cropFx.fxSourceType = .videoFx
        cropFx.addingMethod = .raw
        cropFx.videoFxType = .builtin
        cropFx.inPoint = 0
        cropFx.outPoint = -1
        cropFx.index = index
        cropFx.attachmentsSet["videoClipFxTypeTag"] = "cropperMask"

        // 设置裁剪比例模式
        if let aspect_ratio_mode = crop.aspect_ratio_mode {
            cropFx.attachmentsSet["CropAspectRatioMode"] = aspect_ratio_mode
        }

        // 设置边界框参数
        let leftParam = MeicamFxParam(key: "Bounding Left", type: .float, value: Double(crop.bounding_left))
        cropFx.fxParams["Bounding Left"] = [leftParam]

        let rightParam = MeicamFxParam(key: "Bounding Right", type: .float, value: Double(crop.bounding_right))
        cropFx.fxParams["Bounding Right"] = [rightParam]

        let topParam = MeicamFxParam(key: "Bounding Top", type: .float, value: Double(crop.bounding_top))
        cropFx.fxParams["Bounding Top"] = [topParam]

        let bottomParam = MeicamFxParam(key: "Bounding Bottom", type: .float, value: Double(crop.bounding_bottom))
        cropFx.fxParams["Bounding Bottom"] = [bottomParam]

        let coordTypeParam = MeicamFxParam(key: "Coordinate System Type", type: .menu, value: "NDC")
        cropFx.fxParams["Coordinate System Type"] = [coordTypeParam]

        clip.videoRawFxArray.append(cropFx)
    }
}
