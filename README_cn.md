![Responsive Framework](packages/Responsive%20Cover.png)

# Responsive Framework

<!-- 与英文版互相链接，中文文档以当前公开 API 为准，旧版内容单独标识。 -->
[English](README.md) | [简体中文](README_cn.md)

[![Pub 版本](https://img.shields.io/pub/v/responsive_framework.svg?style=flat-square)](https://pub.dev/packages/responsive_framework) [![GitHub issues](https://img.shields.io/github/issues/Codelessly/ResponsiveFramework.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework/issues) [![许可证](https://img.shields.io/badge/License-MIT-orange.svg?style=flat-square)](LICENSE)

Responsive Framework 提供断点、条件值、行列切换、网格和缩放组件，帮助 Flutter 应用适配手机、平板、桌面与网页窗口。1.6.0 新增 Android 折叠屏和 iPhone Duo 的区域接入与双窗格布局，1.7.0 增加 OHOS 原生折叠数据桥接。

![响应式演示](packages/Responsive%20Demo.gif)

## 演示

| 项目 | 在线演示 | 源码 |
| --- | --- | --- |
| Minimal Website | [博客与作品集模板](https://gallery.codelessly.com/flutterwebsites/minimal/?utm_medium=link&utm_campaign=demo) | [FlutterMinimalWebsite](https://github.com/Codelessly/FlutterMinimalWebsite) |
| Flutter Website | [使用 Flutter 重现 flutter.dev](https://gallery.codelessly.com/flutterwebsites/flutterwebsite/?utm_medium=link&utm_campaign=demo) | [FlutterWebsite](https://github.com/Codelessly/FlutterWebsite) |
| Pub.dev Website | [使用 Flutter 重现 pub.dev](https://gallery.codelessly.com/flutterwebsites/pub/?utm_medium=link&utm_campaign=demo) | [FlutterPubWebsite](https://github.com/Codelessly/FlutterPubWebsite) |

当前工作区的折叠屏示例位于 [example](example)，启动方法见下文。这些上游在线演示不代表本分支新增的折叠屏功能。

## 环境要求

| 范围 | 要求 |
| --- | --- |
| 组件库 | Flutter ≥3.24，Dart ≥3.5 |
| iOS 插件最低部署版本 | iOS 15.0 |
| iPhone Duo 保留区域 | 使用 iOS 27.1 SDK 构建 |
| 当前 example 宿主 | Flutter ≥3.47，Android 使用 Java 17、AGP 9.0.1、Gradle 9.1.0 和内置 Kotlin |

标准 Flutter 使用 3.47 验证，OH 分支使用 3.35.8 验证，尚未单独在最低支持版本 Flutter 3.24 上执行兼容测试。鸿蒙原生接入已编译验证，尚未完成折叠真机验收。

## 快速开始

### 添加依赖

本工作区版本为 1.7.0。若要运行或验证本分支的新功能，先使用本地路径依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  responsive_framework:
    path: ../ResponsiveFramework
```

将 `path` 改为项目的实际相对路径。[example/pubspec.yaml](example/pubspec.yaml) 使用 `path: ../` 引用当前组件库。使用 pub.dev 时，请选择已经发布的对应版本。

### 设置响应式断点

在 `MaterialApp.builder` 或 `CupertinoApp.builder` 中包装 `ResponsiveBreakpoints`。断点名称由业务自行定义。

```dart
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints.builder(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
        child: child!,
      ),
      home: const Scaffold(body: Center(child: Text('Hello'))),
    );
  }
}
```

在后代组件中查询断点：

```dart
final breakpoints = ResponsiveBreakpoints.of(context);

// 名称对应的是业务配置的布局范围，不用于确认真实设备类型。
breakpoints.isMobile;
breakpoints.isPhone;
breakpoints.isTablet;
breakpoints.isDesktop;

breakpoints.equals(DESKTOP);
breakpoints.largerThan(MOBILE);
breakpoints.smallerThan(TABLET);
breakpoints.between(MOBILE, TABLET);
```

断点使用逻辑像素，边界按 `start <= width <= end` 匹配。上面沿用英文版的整数区间示例；自由窗口可能出现小数宽度，生产配置应避免区间空隙。相邻范围共用边界时，排序后先匹配的范围生效。

### 自定义条件

可以添加业务断点，例如导航栏展开条件：

```dart
final expandNavigation =
    ResponsiveBreakpoints.of(context).screenWidth >= 900;
```

也可以配置自定义断点名称，再使用 `equals`、`largerThan` 等方法查询。重叠区间会影响实际匹配顺序，配置时应结合内容宽度验证。

## Android 折叠屏与 iPhone Duo

### 接入窗口数据

Android 使用 Flutter 引擎提供的 `MediaQuery.displayFeatures`；iOS 使用 [foldable](https://github.com/berkaycatak/foldable) 桥接姿态与保留区域。

将 `ResponsiveFoldable` 放在 `MaterialApp.builder` 中，此处已有当前窗口的 `MediaQuery` 和 `FlutterView`：

```dart
MaterialApp(
  builder: (context, child) => ResponsiveFoldable(child: child!),
  home: ResponsiveTwoPane(
    primary: ListScreen(),
    secondary: DetailScreen(),
  ),
)
```

`ListScreen`、`DetailScreen` 是业务组件占位，需替换成实际页面；可直接运行的完整实现见 [折叠屏示例](example/lib/pages/page_foldable.dart)。

`ResponsiveTwoPane` 根据有效折痕或物理铰链划分左右、上下窗格。没有有效分割区域时，默认在宽度达到 840 逻辑像素后使用左右双栏，OHOS 上为 600。

切换布局时两侧组件保留 State，每侧获得自己的局部 `MediaQuery` 尺寸、边距和区域坐标。应在每个窗格内部放置 `SafeArea`。

### 查询姿态、能力与区域

在 `ResponsiveFoldable` 下方，包括两个窗格内部，可以使用以下接口：

| API | 返回值与用途 |
| --- | --- |
| `ResponsiveFoldable.postureOf(context)` | 返回 `ResponsiveFoldPosture.unknown`、`.closed`、`.halfOpened` 或 `.flat`。姿态用于折叠相关行为，普通布局仍以可用空间为依据。 |
| `ResponsiveFoldable.isFoldableOf(context)` | 返回 `bool?`。检测到铰链为 `true`，原生明确报告无铰链才为 `false`，无法确定为 `null`。Android 区域列表为空不能证明设备不可折叠。 |
| `ResponsiveFoldable.angleOf(context)` | 返回 iOS/OHOS 首折轴的最新角度，单位为度；不可用时为 `null`，不根据姿态合成角度。 |
| `ResponsiveFoldable.anglesOf(context)` | 按平台折轴顺序返回只读角度列表；OHOS 可有多个角度，iOS 至多一个，未知时为空列表。 |
| `ResponsiveFoldable.hingeAngleStream` | iOS/OHOS 首折轴的连续角度流，用于局部效果。其他平台返回空流；手动订阅时需在销毁阶段取消。 |
| `ResponsiveFoldable.displayFeaturesOf(context)` | 返回有效的窗口级折叠和相机区域；即使 iOS 的 `bridgeMode` 为 `.none`，仍可读取原生区域。 |

iOS 姿态、区域消费者按对应 aspect 订阅，单独改变角度不会让它们重建。Android 入口保留窗口数据，局部窗格裁掉分割折痕后仍可查询设备姿态。没有包装器时，引擎查询退回当前 `MediaQuery`，能力未知仍返回 `null`。

窗口级矩形使用 `ResponsiveFoldable` 入口的坐标。在窗格内部，应使用 `MediaQuery.of(context).displayFeatures` 获取**局部坐标**。窗口矩形传入有偏移或缩放的子树前，必须先转换。

### 单独控制页面布局与浮层桥接

在 iOS 上，可以让页面使用折叠区域，同时保留 Material 弹窗和底部浮层原有的全局行为：

```dart
MaterialApp(
  builder: (context, child) => ResponsiveFoldable(
    bridgeMode: DisplayFeatureBridgeMode.none,
    child: child!,
  ),
  home: Builder(builder: (context) {
    return ResponsiveTwoPane(
      displayFeatures: ResponsiveFoldable.displayFeaturesOf(context),
      minPrimarySize: const Size(240, 200),
      minSecondarySize: const Size(360, 240),
      primary: ListScreen(),
      secondary: DetailScreen(),
    );
  }),
)
```

桥接通过显式添加 `ResponsiveFoldable` 启用：

| `bridgeMode` | iOS 行为 |
| --- | --- |
| `DisplayFeatureBridgeMode.full`（默认） | 写入有效折叠与相机区域；Flutter 弹窗和 sheet 会受到子屏约束，应设置合适的 `anchorPoint`。 |
| `DisplayFeatureBridgeMode.cutoutsOnly` | 只桥接相机遮挡区域。 |
| `DisplayFeatureBridgeMode.none` | 不写入 `MediaQuery.displayFeatures`，可通过查询接口单独读取区域。 |

`bridgeMode` 配置 iOS/OHOS。Android 始终保留引擎数据，包括 Flutter 既有的弹窗子屏行为。不要嵌套多个桥接 Provider，也不要重复注入同一条折痕。

### 控制单栏与双栏策略

| 属性 | 默认值 | 行为 |
| --- | --- | --- |
| `mode` | `ResponsiveTwoPaneMode.auto` | `auto` 跟随有效分区或宽度断点；`single` 仅显示一侧；`dual` 跳过宽度断点请求双栏。 |
| `breakpoint` | `null`，即 `ResponsiveTwoPane.defaultBreakpoint` | 普通宽屏进入左右双栏的逻辑像素宽度。默认 840（Material expanded）；OHOS 为 600，与 `Navigation` 自 600vp 起分栏一致，Mate X 展开态约 711vp。 |
| `minPrimarySize`、`minSecondarySize` | 均为 `Size.zero` | 两侧独立的最小外框尺寸。任一候选窗格太小时退回单窗格，`dual` 模式也遵守此约束。 |
| `primaryFraction` | `0.4` | 普通双栏扣除间距后，主窗格占可用宽度的比例。真实折痕按其位置划分。 |
| `spacing` | `24` | 普通双栏间距；存在物理分割时使用实际折叠或铰链边界。 |
| `showSecondary` | `false` | 仅显示一个窗格时，是否选择详情侧。 |
| `displayFeatures` | `null` | 可注入当前布局坐标系中的区域，用于自定义接入、测试或预览；显式传入空列表可关闭折痕分区。 |

物理铰链避让始终生效：强制单栏或最小尺寸回退后，选中的窗格仍留在自己的物理区域，不会跨过铰链。

隐藏窗格保留 State，但不参与绘制、语义交互和焦点交互，ticker 也会停用。隐藏不等于销毁，数据订阅和业务任务仍需由组件所有者管理。

### 读取实际布局结果

在 `primary` 或 `secondary` 内调用 `ResponsiveTwoPane.of(context)`，可得到不可变的 `ResponsiveTwoPaneLayout`。没有祖先布局时，`maybeOf(context)` 返回 `null`，`of(context)` 会抛出说明性错误。

| 字段 | 含义 |
| --- | --- |
| `isDual` | 当前是否同时显示两个窗格。 |
| `axis` | 双栏方向；单窗格时为 `null`。 |
| `isPrimaryVisible`、`isSecondaryVisible` | 两侧在当前布局中的可见状态。 |
| `primaryBounds`、`secondaryBounds` | 相对于 TwoPane 原点的窗格矩形。 |
| `hasDisplayFeatureDivision` | 是否存在有效的物理区域分割，与当前是否启用双栏分开表达。 |
| `availableRegions` | 只读区域列表，表示普通双栏与间距划分前的物理可用区域。当前组件最多渲染两个窗格。 |

例如，双栏时隐藏返回列表按钮：

```dart
Builder(builder: (context) {
  final layout = ResponsiveTwoPane.of(context);
  return layout.isDual
      ? const SizedBox.shrink()
      : BackButton(onPressed: onBack);
})
```

### 定位弹窗和底部浮层

使用触发控件的上下文计算窗口坐标：

```dart
Builder(builder: (buttonContext) => IconButton(
  icon: const Icon(Icons.info_outline),
  onPressed: () => showDialog<void>(
    context: buttonContext,
    anchorPoint: ResponsiveTwoPane.anchorPointFor(buttonContext),
    builder: (context) => const AlertDialog(title: Text('详情')),
  ),
))
```

`anchorPointFor` 应在控件已完成布局后调用，通常放在按钮回调中。它将控件中心转换为窗口坐标，不能直接用局部窗格的矩形中心替代。若使用自定义嵌套 Navigator，应转换到对应 Navigator 的坐标系。

### 局部布局约定

与 Flutter 的 `DisplayFeatureSubScreen` 类似，TwoPane 应位于最近 `MediaQuery` 的原点。放入有偏移的容器时，需通过 `displayFeatures` 传入转换后的局部矩形。父约束的宽高必须有界，例如放入 `Expanded` 或明确尺寸的 `SizedBox`。

## 鸿蒙 / OHOS（1.7.0 起）

<!-- Flutter 示例与 OHOS 原生宿主按插件标准结构共存于 example/。 -->
`ohos/` 为原生 ArkTS 插件，Flutter OH 根据 pubspec 自动注册。UI 层继续使用 `ResponsiveFoldable` 与 `ResponsiveTwoPane`，无需另写一套鸿蒙布局。

使用带 OHOS 支持的 Flutter SDK，在统一示例目录中运行：

```sh
cd example
/你的路径/flutter-ohos/bin/flutter pub get
/你的路径/flutter-ohos/bin/flutter test
/你的路径/flutter-ohos/bin/flutter build hap --debug --no-codesign
```

已使用 Flutter OH 3.35.8 和 DevEco SDK（API 26）编译验证，原生接口最低要求 API 12。Flutter 示例位于 `example/`，其鸿蒙原生宿主位于 `example/ohos/`。

插件监听折叠状态、显示模式、折轴角度、屏幕与窗口变化。原生矩形使用屏幕物理像素：先减去可绘制窗口原点，再除以实际 FlutterView DPR。屏幕 ID 或视图尺寸不匹配时，仅保留姿态和能力，不发布未经确认的折痕。

`full` 模式将折痕补入 `MediaQuery`；`none` / `cutoutsOnly` 保留已有引擎数据，仍可通过 `displayFeaturesOf` 单独读取插件区域。原生角度事件到来前不填充估算角度。多折痕和多角度数据会保留，但 TwoPane 仍最多渲染两个窗格；三折叠的逐折轴激活语义需要设备验收。

当前已构建无签名 HAP，**尚未在鸿蒙折叠设备上运行**。仍需验证内外屏、旋转、悬浮窗口和不同固件的坐标返回。若 FlutterView 嵌入有偏移或不同尺寸的原生容器，需要宿主另行接入视图几何。

构建排查和官方资料见 [鸿蒙支持说明](docs/ohos-support.md)。

## 运行与验证 example

启动：

```sh
cd example
flutter pub get
flutter run
```

默认页面使用本地笔记，可切换跟随设备、左右折叠、上下折叠和完全展开。选择“跟随设备”时读取 Android/iOS 的实际数据。编辑内容和选中项会在布局切换中保留；笔记仅保存在当前进程内存中，重启后恢复示例内容。原博客页面保留在 `/list`。

```sh
# 在组件库根目录验证公共接口。
flutter test
flutter analyze

# 在 example 目录验证示例与原生构建。
cd example
flutter test
flutter analyze
flutter build apk --debug
flutter build ios --simulator --debug
```

进一步说明见 [example/FOLDABLE.md](example/FOLDABLE.md) 和 [实现与验证记录](docs/android-ios-implementation.md)。

## 其他响应式组件

| 组件 | 用途 |
| --- | --- |
| [ResponsiveValue](lib/src/responsive_value.dart) | 根据断点与条件选择值。 |
| [ResponsiveVisibility](lib/src/responsive_value.dart) | 根据响应式条件控制可见性。 |
| [ResponsiveConstraints](lib/src/responsive_value.dart) | 根据条件设置布局约束。 |
| [ResponsiveRowColumn](lib/src/responsive_row_column.dart) | 切换行列布局，配置顺序、间距和弹性。 |
| [ResponsiveGridView](lib/src/responsive_grid.dart) | 响应式网格。 |
| [ResponsiveScaledBox](lib/src/responsive_scaled_box.dart) | 对内容进行等比缩放，并同步转换区域坐标。 |
| [MaxWidthBox](lib/src/max_width_box.dart) | 限制最大宽度，并处理局部窗口与折痕坐标。 |

## 旧版说明：0.2.0 及更早版本

<!-- 旧 API 仅解释历史设计，防止读者直接复制到当前版本导致编译失败。 -->
以下为历史设计概念。`ResponsiveWrapper` 已废弃并移除；`ResponsiveBreakpoint.autoScale` 等旧接口不适用于当前版本。迁移方式见 [0.2.0 → 1.0.0 迁移指南](migration_0.2.0_to_1.0.0.md)，完整旧版示例保留在 [英文 README](README.md#legacy-readme-v020-and-below)。

### 要解决的问题

为不同屏幕反复编写布局容易造成重复工作，固定尺寸也可能让界面在大窗口中显得过小。

![窗口切换演示](packages/Bad%20Viewport%20Selector%20Animated.gif)

### 缩放与重排

Flutter 通常通过约束变化重新布局：无约束的方向可以伸展，固定尺寸保持不变。等比缩放则同时改变整体宽高，保留原有比例。

![缩放与重排对比](packages/Scale%20Resize%20Comparison.gif)

例如，AppBar 在普通重排中可以拉宽，但固定工具栏高度不会随宽度增加；整体缩放时，其高度和文字也会一起放大。

![AppBar 对比](packages/AppBar%20Scale%20vs%20Resize%20Comparison.png)

旧版通过断点混合配置 resize 与 autoScale。当前应使用 `ResponsiveBreakpoints` 组织布局条件，需要整体缩放时再使用 `ResponsiveScaledBox`，并结合实际内容验证效果。

![设备预览](packages/Device%20Preview.gif)

## 更多资料

- [Resocoder 响应式教程](https://resocoder.com/2021/10/03/create-responsive-flutter-apps-with-minimal-effort/)：原始项目的介绍文章与视频，阅读时需区分旧版 API。
- [版本变更](CHANGELOG.md)。
- [英文 README](README.md)：上游演示、历史示例与其他项目介绍。

## 关于与贡献

Responsive Framework 由 Codelessly 发起，目标是让 Flutter 界面更方便地适应不同尺寸。可通过 [Codelessly](https://codelessly.com/?utm_medium=link&utm_campaign=direct) 了解其应用界面、网站构建工具和模板。

上游项目以 Emailware 形式分享，订阅动态不是使用条件。感谢 Flutter 团队及项目贡献者：

- 设计：[Ray Li](https://github.com/searchy2)。
- 开发：[Ray Li](https://github.com/searchy2)、[Spencer Lindemuth](https://github.com/SpencerLindemuth)、[Trefa1998](https://github.com/Trefa1998)，以及其他贡献者。
- 赞助：[Codelessly](https://codelessly.com/?utm_medium=link&utm_campaign=direct)。

可通过 [GitHub](https://github.com/Codelessly)、[电子邮件](mailto:ray@codelessly.com) 或 [Twitter](https://twitter.com/BuildCodelessly) 联系上游项目。

## 支持徽章

[![Flutter Responsive](https://img.shields.io/badge/flutter-responsive-brightgreen.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework)

```markdown
[![Flutter Responsive](https://img.shields.io/badge/flutter-responsive-brightgreen.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework)
```

其他支持徽章及 HTML 嵌入方式见 [英文说明](README.md#badges-)。

## 许可证

本项目采用 MIT License，版权归 Codelessly 所有。许可证正文以 [LICENSE](LICENSE) 为准。
