# 折叠屏适配评估

评估日期：2026-10-26。

<!-- 保留评估时的证据，并明确后续实现已修复缺陷，防止把历史结果当现状。 -->
更新：Android/iOS 已实现；以下缺陷表为实现前记录。对应探针已迁移至 `test/responsive_regression_test.dart` 并通过。使用方式见根 README 与 `example/FOLDABLE.md`，1.7.0 已增加 OHOS 桥接和无签名 HAP 构建验证，尚无折叠真机验收；见 [OHOS 支持说明](../ohos-support.md)。

范围：当前 responsive_framework 1.5.1 源码、Flutter 3.47.0 本地组件验证、官方平台资料及 berkaycatak/foldable main 分支。未执行三平台真机验收，未修改生产代码。

## 结论

建议继续使用本项目作为响应式布局基础，增加轻量的折叠区域布局能力，并在平台适配层接入数据。仅添加手机/平板断点无法完成折叠屏适配；也无需重写现有库。

| 平台 | 当前可以复用 | 需要补齐 | 判断 |
| --- | --- | --- | --- |
| iPhone Duo | 窗口宽度断点、行列切换、网格 | foldable 数据接入、局部区域坐标、相机遮挡及系统保留区域处理、宿主工具链验证 | 可行，中等工作量 |
| Android 折叠屏 | 上述能力；Flutter 的 displayFeatures 可作为数据源 | 折痕/铰链分区、半展开布局、浮层落点、折叠过程状态保持 | 可行，中等工作量 |
| 鸿蒙原生折叠屏 | 纯 Dart 布局逻辑可优先复用 | 所用 Flutter OH 分支编译验证、折叠/显示模式事件、折痕区域桥接及单位转换 | 有条件可行，不确定性最高 |

这里的鸿蒙原生指需要 OH 工具链和 HAP 的目标；在可运行 APK 的设备上走 Android 路径属于另一种验证范围。

## 当前代码证据

1. `lib/src/responsive_breakpoints.dart:108` 读取 MediaQuery 窗口宽高，`:237` 监听窗口 metrics，具备内外屏切换后重新计算断点的基础。但只输出尺寸、方向、断点，没有姿态或区域数据。
2. `lib/src/responsive_row_column.dart` 与 `lib/src/responsive_grid.dart` 可复用来组织双栏内容，当前没有按实际折痕位置划分可用区域的能力。
3. `lib/src/responsive_scaled_box.dart:53` 改写 size、padding、viewInsets，却保留原始 displayFeatures；缩放后的内容与折痕不在同一坐标系。
4. `lib/src/max_width_box.dart:24` 缩窄 MediaQuery 后没有平移、裁剪 displayFeatures。居中容器里的区域坐标属于待补测风险，不能直接沿用全窗口矩形。
5. `lib/src/utils/responsive_utils.dart` 的平台枚举没有 OHOS。其 TargetPlatform 转换使用穷尽 switch；如果选用的 OH SDK 增加枚举值，需核对编译及映射。未在 OH SDK 上实编译，因此不判定为已确认编译失败。
6. `test/` 原先只有测试辅助函数，没有实际测试用例；`example/` 子模块当前未检出，无法据此证明完整宿主应用兼容。

## foldable 是否适合接入

适合用作 iPhone Duo 数据源，不能直接当三平台统一实现。已查看 pubspec、Dart provider、builder、bridge、channel 和 iOS podspec。

- 当前 main 的 pubspec 标为 1.0.5，仅注册 iOS。非 iOS 缺少插件时返回 unsupported，因此不能把它的 isFoldable=false 当作 Android/鸿蒙不存在折叠能力。
- 能提供姿态、角度、size class 和保留区域。布局以可用空间和姿态为主，角度用于局部效果，避免全页面随角度高频重建。
- `DisplayFeatureBridgeMode.none` 是默认值。按页面直接消费区域即可；如选择 full，Flutter 的弹窗、sheet 等会启用子屏约束，必须同时检查 anchorPoint 和落点。
- `FoldAwareBuilder` 对区域做原点平移，不能据此假定它支持 ResponsiveScaledBox 的任意缩放。第一阶段优先避免对折叠页面整体缩放。
- 本项目声明 Dart ≥3.0、Flutter ≥3.7；foldable 声明 Dart ≥3.5、Flutter ≥3.24。其实际 podspec 最低 iOS 为 15.0，部分描述仍写 iOS 13，应以配置和编译结果为准。

建议在应用层或单独的可选集成包依赖 foldable，核心 responsive_framework 保持纯 Dart 布局职责，避免所有使用者被迫升级最低版本。

来源：[插件清单](https://github.com/berkaycatak/foldable/blob/main/pubspec.yaml)、[Provider](https://github.com/berkaycatak/foldable/blob/main/lib/src/widgets/foldable_provider.dart)、[局部区域转换](https://github.com/berkaycatak/foldable/blob/main/lib/src/widgets/fold_aware_builder.dart)、[桥接策略](https://github.com/berkaycatak/foldable/blob/main/lib/src/bridge/display_feature_bridge.dart)、[iOS 配置](https://github.com/berkaycatak/foldable/blob/main/ios/foldable.podspec)。集成前应固定发布版本或 commit，不能依赖 main 永远保持一致。

## 三平台接入重点

### iPhone Duo

Apple 已提供正式适配资料。宿主使用的 SDK 会影响显示区域；按官方说明，iOS 27.1 SDK 可使用完整显示区域和新的布局能力。原生系统栏的自动变化不能推导为 Flutter 自绘 Material/Cupertino 导航也会自动完成同等适配。

接入 foldable 后，分别处理布局分区与相机遮挡；完全展开时不要仅因设备有折痕就强制分屏。内外屏、半展开、分屏窗口和系统保留区域均需要宿主验证。

来源：[Apple 适配步骤](https://developer.apple.com/iphone-duo/prepare/)、[自适应布局与保留区域](https://developer.apple.com/videos/play/tech-talks/111463/)。

### Android

先使用 Flutter 的 `MediaQuery.displayFeatures`，验证目标设备/引擎是否实际提供矩形和姿态。只有需要额外原生能力时才增加 WindowManager 桥接，不必先重复开发完整 Android 插件。

需区分连续屏折痕与双屏物理铰链；半展开也可能不改变窗口尺寸。水平折痕可形成上下布局，垂直折痕可形成左右布局；是否启用双栏还取决于各栏最小可用宽高。不能仅凭 foldable 标志、横竖屏或设备型号决定布局。

来源：[Flutter 大屏指导](https://docs.flutter.dev/ui/adaptive-responsive/large-screens)、[DisplayFeature](https://api.flutter.dev/flutter/dart-ui/DisplayFeature-class.html)、[Android FoldingFeature](https://developer.android.com/reference/androidx/window/layout/FoldingFeature)。

### 鸿蒙

先锁定目标 Flutter OH 分支和版本，确认构建、平台映射及 displayFeatures 数据完整性。若引擎已提供可靠区域数据，直接复用；缺失时通过 ArkTS 与 MethodChannel/EventChannel 接入。

候选接口包括 getCurrentFoldCreaseRegion、foldStatusChange、foldDisplayModeChange。物理折叠状态与显示模式变化存在先后关系，不能在前一个事件中假定后续窗口尺寸已经更新。平台层要把屏幕坐标转换成当前 FlutterView 的逻辑坐标，再传给布局；多窗口下仅做 px2vp 并不足以证明正确。

三折叠屏需要支持多个区域/折痕，不把数据结构限制为一条中心折线。姿态和角度缺失时保留 unknown，普通响应式布局继续工作。

来源：[OpenHarmony 屏幕 API](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/js-apis-display.md)。具体华为系统版本及 API 可用性仍以目标 SDK 和设备验证为准。

## 最小实施顺序

1. 修复已复现的断点刷新问题；补充窗口变化、局部 MediaQuery 和配置更新的回归验证。
2. 用真实约束计算单栏/双栏，补充区域平移、裁剪和折痕避让。首期折叠页面采用 reflow；如保留整体缩放，必须同时转换 displayFeatures 坐标并增加测试。
3. 平台输入保持可替换：iOS 用 foldable，Android 用 Flutter 数据，鸿蒙用已验证的引擎能力或桥接。核心只需表达有效分区、遮挡、可选姿态与能力状态，不需要建立庞大的设备型号库。
4. 用一个列表/详情示例验证三平台，再迁移业务页面。初始断点可试用 600/840 逻辑像素，最终按内容最小宽高调整；这不是机型判定标准。

窗口够宽可双栏，半展开且存在有效分区时按分区布局；每个分区内部再计算自身断点。分栏不能只留固定的中央间距，必须使用真实边界。表单、选中项、导航和滚动状态应放在布局切换之上。

粗估：熟悉 Flutter 的一名工程师，在工具链和测试设备齐备的前提下，核心修复/区域布局 3–5 人日、iOS 集成 1–3 人日、Android 验证 1–2 人日、鸿蒙接入 3–6 人日、三平台回归 2–4 人日；总计约 10–20 人日。该估算是组件库和一个代表页面的工程判断，不含业务全量改造、环境阻塞或商店发布。

## 验证结果与边界

环境：Flutter 3.47.0，Dart 3.13.0。组件探针共 4 项：1 项通过，3 项暴露现有缺陷。

| 场景 | 期望 | 实际 | 结论 |
| --- | --- | --- | --- |
| 物理窗口从 400×800 变为 900×800 | MOBILE → TABLET | 正确切换 | 通过 |
| 缓存同一子组件，仅上层 MediaQuery 从 400×800 变为 900×800 | screenWidth=900 | 仍为 400 | 缺少依赖变化后的尺寸重算 |
| 同尺寸替换断点配置 | MOBILE → TABLET | 仍为 MOBILE | setBreakpoints 只按尺寸判定缓存失效 |
| 800×600 缩放至 400×300 | 折痕 (390,0,20,600) → (195,0,10,300) | 折痕保持原坐标 | 缩放坐标不一致 |

实现前的四项探针现已作为 `test/responsive_regression_test.dart` 纳入正式回归，执行方式：

```sh
flutter test --no-pub test/responsive_regression_test.dart --reporter expanded
```

实现后的当前结果：四项均通过；另补充 iOS 通道桥接、Android 透传、区域布局及示例状态验证。

实现前 `flutter analyze --no-pub` 另发现现有 responsive_grid.dart:253 使用已弃用的 cacheExtent，返回 1 条 info；不是已通过全部静态检查。

后续验收至少覆盖：内外屏往返、尺寸不变的姿态切换、横纵折痕、三折多区域、分屏/自由窗口、键盘/大字体、RTL、相机区域、弹窗落点，以及切换后表单/滚动/导航保持。以上组件探针不能替代原生构建、插件运行和真机验证。
