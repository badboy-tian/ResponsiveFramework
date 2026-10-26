# Android / iOS 实现与验证

<!-- 验证记录与历史评估分开，避免把已修复的问题继续当成阻塞项。 -->
2026-10-26，库版本 1.6.0。本篇保留 Android/iOS 实现记录；1.7.0 新增鸿蒙桥接的验证边界见 [OHOS 支持说明](ohos-support.md)。

## 已实现

- `ResponsiveFoldable`：在 MaterialApp.builder 内使用。Android 保留引擎区域数据；iOS 使用发布版 foldable 1.0.5 桥接有效保留区域。
- `ResponsiveTwoPane`：按真实折痕分左右或上下窗格；没有有效分割时按可用宽度切换。支持 RTL、紧凑窗口详情、局部 MediaQuery 和状态保持。
- 修复首帧初始化、局部 MediaQuery 更新、同尺寸断点配置/平台变化、缩放和最大宽度容器的折痕坐标。
- 隐藏窗格停止 ticker、焦点和语义交互，但继续保留 State。
- example 默认展示可编辑笔记，包含设备跟随及人工预览，使用本地 path 依赖；原博客保留在 `/list`。

## 公共接口补齐

<!-- 独立的最小尺寸覆盖列表与详情的不对称需求，保持接口数量可控。 -->
`ResponsiveFoldable` 增加姿态、可空能力、角度、角度流和未桥接窗口区域查询。
Android 窗口数据在入口保存，窗格局部裁剪不会丢失姿态；iOS 姿态/区域按 aspect 订阅。
`ResponsiveTwoPane` 增加 auto/single/dual 策略、独立的 minPrimarySize/minSecondarySize、
of/maybeOf 布局快照与 anchorPointFor 浮层定位。默认值继续保留原行为。
example 使用快照控制返回按钮，使用辅助方法定位弹窗。完整接口契约见根 README。

## 版本要求

<!-- 区分组件库兼容范围与示例宿主已升级的原生构建环境。 -->
库：Flutter ≥3.24，Dart ≥3.5；iOS 插件最低部署目标 15.0。
example：Flutter ≥3.47，Java 17，AGP 9.0.1，Gradle 9.1.0，内置 Kotlin，编译器版本声明 2.3.20。
本机验证环境为 Flutter 3.47.0 / Dart 3.13.0 / Xcode 27.1。
iPhone Duo 保留区域需要 iOS 27.1 SDK。未在最低支持版本 Flutter 3.24 上单独执行兼容测试。

## 验证证据

<!-- 组件测试覆盖可控边界，模拟器验证真实平台数据，两者不可相互替代。 -->
根目录：`flutter test --no-pub`，27 项通过；`flutter analyze --no-pub` 无问题。
example：`flutter test --no-pub`，1 项通过；`flutter analyze --no-pub` 无问题。
测试覆盖首帧、窗口/局部尺寸/配置/平台更新、iOS 通道与展开态清理、Android 数据透传、零宽折线、物理铰链、上下分区、RTL、局部坐标、越界区域与编辑状态保持。

原生构建：

```sh
cd example
flutter pub get
flutter build apk --debug --no-pub
flutter build ios --simulator --debug --no-pub
```

Android APK：`example/build/app/outputs/flutter-apk/app-debug.apk`。
iOS 模拟器包：`example/build/ios/iphonesimulator/Runner.app`。

iPhone Duo 模拟器（iOS 27.1）：安装并实际启动，通过 Device Hub 原生按钮验证闭合、展开、半展开以及旋转后的上下布局。半展开折痕位置出现对应留白，内容分布在两侧。

Pixel Fold 模拟器（API 34）：安装并启动 APK，使用系统 CLOSED / HALF_OPENED / OPENED 状态验证内外屏单栏/双栏切换；实际截屏确认外屏单栏、内屏左右双栏，运行期间未发现 Flutter 或 AndroidRuntime 错误。

## 使用边界

<!-- 明确坐标契约，避免把全窗口矩形直接用于有偏移的局部容器。 -->
TwoPane 应放在最近 MediaQuery 的原点处，SafeArea 放进每个窗格。嵌套在有偏移容器中时，传入已经转换到局部坐标的 displayFeatures。
浮层使用触发控件的全局 anchorPoint。full 桥接会启用 Flutter 的子屏浮层约束，可选择 cutoutsOnly 或 none。
数据缺失时退回普通窗口布局；相机遮挡区域可由页面读取局部 displayFeatures 做针对性布局，不会把局部相机孔强制当成整屏折痕。
当前组件最多放置两个窗格，多折痕时只消费前两个可用区域。

未执行真机验收。foldable 上游当前仍有旧应用生命周期 API 的启动提示，本机 UIScene 宿主已验证可以正常运行；后续升级 Flutter 时需要回归该插件。