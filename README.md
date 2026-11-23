# Moodium Swift · Vision Pro

目标：完整复刻 Unity Vision Pro 版现有 XR 体验，采用原生 visionOS 实现。手机版不作为任何迁移来源。

当前阶段：已建立原生 visionOS 工程、开发用空间入口和 Unity 旅程状态机；尚未迁入视觉资源。开发入口不是最终产品 UI。

打开 `Moodium.xcodeproj`。完整计划见 `docs/开发计划.md`。状态机检查：`swiftc Moodium/Core/WorldJourney.swift Tests/JourneyChecks.swift -o /tmp/moodium-journey-checks && /tmp/moodium-journey-checks`。

## 已确认基线

当前 EditorBuildSettings.asset 启用的场景为 `../Moodium/Assets/ARTnGAME/Meshing 1.unity`。这与旧交接文档中的 Samples 路径不同，后续应以当前场景为准。

直接场景引用记录见 `docs/unity-scene-direct-references.json`。该记录不包含递归 Prefab 依赖、Resources 动态加载和运行时生成对象，不能作为完整资源打包清单。

## 完整复刻范围

开场与空间选择、双世界、感官袋与无袋分支、识别与校准、心情签到、全部捏捏模式、软体反馈、Moodi 救援、奖励生长、探索、泡泡入口与嵌套世界、点云与扰动、许愿书写与风铃、记录、设置、教学、音频及返回流程。

## 执行顺序

1. 追溯实际场景和 Prefab，记录每个模块的挂载、序列化参数及运行时生成方式。
2. 建立 Unity 视觉与交互基线：空间尺寸、位置、材质、灯光、动画时序、手势、声音和退出条件。
3. 建立原生工程及资源转换管线，直接从 Unity 原始素材导出并核对。
4. 按模块实现并对照验收；暂未实现、存在差异、已真机验收分别记录。
5. 完整流程、性能与参赛打包验证。

不将低成本替代效果认定为完成。当前未进行原生构建或真机视觉验收。


## 获取项目资源

模型、视频和语音使用 Git LFS。克隆后运行 `git lfs install` 和 `git lfs pull`。`BuildAssets/` 为可重新生成的转换中间文件，不提交。

当前实现与验证边界见 [当前进度](docs/当前进度.md)。资源转换工具需要相邻的 Unity `Moodium` 源工程；运行 App 使用仓库内随附资源。
