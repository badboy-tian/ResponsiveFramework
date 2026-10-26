# OHOS 折叠屏支持（1.7.0）

<!-- 单独记录 OH 工具链，避免把标准 Flutter 示例的验证结果套用到鸿蒙。 -->
本实现参考 [saver_gallery](https://github.com/fluttercandies/saver_gallery) 的 OHOS 插件目录及注册方式，没有引入其相册功能或依赖。根目录 `ohos/` 提供 ArkTS 插件；`example/ohos/` 是统一 Flutter 示例的 HarmonyOS 原生宿主。

目录职责如下：

```text
lib/src/ohos/                 Dart 通道、数据校验和 MediaQuery 桥接
ohos/                         发布到使用方的 ArkTS 插件
example/lib/                  唯一的 Flutter 折叠屏示例页面
example/test/                 示例组件测试
example/ohos/                 示例的 HarmonyOS Ability 和构建配置
test/ohos_foldable_test.dart  无设备时运行的桥接单元测试
```

## 官方文档与知识 MCP

用户提供的 [HarmonyOS 知识 MCP 说明](https://developer.huawei.com/consumer/cn/doc/start/hosknowledgemcp-0000002664603963) 适用于这次查询。本次直接调用官方服务 `https://connect-api.cloud.huawei.com/api/developerknowledge/mcp` 的 `tools/list`、`searchDocuments` 和 `getDocumentsById`，检索并读取了完整 API 文档，没有修改本机全局 MCP 配置。

实现依据：

- [屏幕属性开发指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/screenproperty-guideline)：折叠状态、显示模式和折痕区域。
- [display 屏幕属性 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-display)：`isFoldable`、`getFoldStatus`、`getLiveCreaseRegion`、`getCurrentFoldCreaseRegion`、`foldStatusChange`、`foldDisplayModeChange`、`foldAngleChange`。
- [折叠屏悬停态](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-folded-hover)：官方实践使用 `getLiveCreaseRegion`；插件优先使用它，API 20 以下或结果为空时回退到 `getCurrentFoldCreaseRegion`。

本机 OH Flutter 3.35.8 的引擎封装中，折痕上报代码处于注释状态，不能依赖该版本的 `MediaQuery.displayFeatures` 自动获得折痕。因此插件补充原生桥接，同时优先保留引擎已有的折叠数据，避免重复注入。

## 接口与数据约定

UI 仍使用 `ResponsiveFoldable` 和 `ResponsiveTwoPane`。通过 `MaterialApp.builder` 在页面外放置一个 `ResponsiveFoldable`，具体示例见根 README。

| 接口 | OHOS 行为 |
| --- | --- |
| `postureOf` / `isFoldableOf` | 姿态、可选能力；原生数据不可用时保持未知，并允许引擎数据回退 |
| `displayFeaturesOf` | 有效显示特征，供自定义布局查询，不根据屏幕比例猜测中线 |
| `ResponsiveTwoPane.of(context).availableRegions` | 双窗格布局计算得到的可用区域 |
| `angleOf` | 首折轴最新有效角度，未知为 `null` |
| `anglesOf` | 全部有效角度的只读列表，保留平台顺序；尚无传感器事件时为空 |
| `hingeAngleStream` | 首折轴角度流；手动订阅需要取消 |
| `bridgeMode.full` | 把有效原生折痕发布到 `MediaQuery`，保留引擎切口 |
| `bridgeMode.none` / `cutoutsOnly` | 保持引擎数据，仍可显式查询插件折痕 |

`foldStatusChange` 早于最终显示模式和窗口尺寸变化，因此插件还监听显示模式、屏幕、窗口尺寸和位置，并在 Flutter metrics 变化及恢复前台时重新查询。取消订阅或脱离 Ability 时按回调引用释放监听。

原生通道内部使用带版本号的快照（`wireVersion: 1`），不是公开宿主协议。折痕为屏幕物理像素，转换时减去 `windowRect + drawableRect` 的屏幕原点，再除以当前 FlutterView 的 DPR。必须满足显示 ID 一致、原生可绘制尺寸与 FlutterView 物理尺寸一致，才发布几何；尺寸切换中的不匹配快照只保留姿态与能力。

仅半折姿态发布穿过视口的有效分隔折痕。关闭、展开和未知姿态清除旧分隔数据。支持双折轴状态枚举及多个矩形/角度；`ResponsiveTwoPane` 最多渲染两个窗格。三折设备各折轴的实际可见性、方向与区域选择仍需设备验收。

角度变化复用几何缓存；InheritedModel 按姿态、能力、几何、角度分别通知，避免角度传感器事件触发仅依赖姿态的组件重建。

## 工具链和构建

已验证 Flutter OH `3.35.8-ohos-0.0.3`（Dart 3.9.2）及 DevEco 内置 HarmonyOS API 26 SDK。宿主的最低兼容版本为 `5.0.0(12)`，不固定编译 SDK 版本，由安装的 DevEco 工具链解析。标准 Flutter SDK 不具备 `build hap` 能力。

```sh
cd example
/path/to/flutter-ohos/bin/flutter pub get
/path/to/flutter-ohos/bin/flutter analyze
/path/to/flutter-ohos/bin/flutter test
# 用 OH SDK 同时验证组件库，而不覆盖根目录标准 SDK 的 package_config。
/path/to/flutter-ohos/bin/flutter test --no-pub ../test
/path/to/flutter-ohos/bin/flutter build hap --debug --no-codesign
```

`example/` 是唯一 Flutter 宿主，`example/ohos/` 仅放置 OHOS 原生文件，和 saver_gallery 的目录职责一致。不要用 OH SDK 在根目录执行带自动 example 解析的 pub get；需要时使用 `--no-example`。

本机原有 Flutter OH 全局 SDK 配置指向另一套 OpenHarmony SDK，而当前 DevEco 使用内置 HarmonyOS SDK。为避免改动全局配置，实际构建在 Flutter 生成资源后，通过宿主被忽略的 `ohos/local.properties` 指向 DevEco 的 SDK 根目录：

```properties
# 按本机安装路径填写；SDK 根目录包含 default/hms 和 default/openharmony。
hwsdk.dir=/path/to/DevEco-Studio.app/Contents/sdk
```

在 `example/ohos` 中执行了：

```sh
HVIGOR=/path/to/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
$HVIGOR assembleHap \
  -p product=default -p buildMode=debug -p ohos.sign=false --no-daemon
```

`flutter build hap` 输出为 `example/build/ohos/hap/entry-default-unsigned.hap`；直接使用 Hvigor 时输出为 `example/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`。`flutter build hap` 可能重新生成 local.properties；如果 SDK 冲突，检查生成后的路径，或使用 DevEco 打开宿主构建。工具链中旧 Flutter embedding 对较新 SDK 存在弃用告警，当前未升级或修改 SDK 自身代码。

## 验证边界

- 标准 Flutter：组件库 35 个测试通过，1 个仅 OH 枚举分派测试跳过。
- OH Flutter：组件库 36 个测试通过，包含实际 `TargetPlatform.ohos` 分派；统一示例 1 个组件测试通过。
- 覆盖物理坐标/DPR、窗口偏移、显示 ID/尺寸不匹配、旋转方向、展开/关闭清理、双折轴状态、非法快照、事件更新与取消、角度独立通知。
- ArkTS 插件与宿主无签名 HAP 编译通过，压缩包包含 Flutter 引擎及 Dart 资源。
- 标准 Android/iOS 示例回归：组件测试通过，Android debug APK 和 iOS Simulator debug 应用均构建成功；根库及 OH 示例静态分析通过。
- 双折叠模拟器（API 26，`emulator 7.0.0.107`，2210×2416 px，DPR 3.125）：已签名安装运行。窗口为 707×773 逻辑像素；`HALF_FOLD` 时快照姿态为 3，但 `getCurrentFoldCreaseRegion()` 返回 `undefined`，`getLiveCreaseRegion()` 返回空 `creaseRects`，横竖屏结果相同。插件因此只发布姿态，不发布折痕。
- 依据[双折叠开发指南](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-foldable-guide)（Mate X5 展开态 711×798vp）和 [Navigation 分栏规则](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-architecture)（600vp 起分栏），OHOS 默认双栏断点为 600。修改前该模拟器在展开与半折时都只显示一个窗格，修改后显示双栏；缺少折痕时分隔线按 `primaryFraction` 放置，不对齐物理折痕。
- **尚未在鸿蒙折叠真机上运行。** 内外屏切换、旋转、悬浮窗口、三折设备及不同固件的折痕坐标需要安装签名包后验收。

目前原生坐标假设 FlutterView 填满 Ability 的 drawableRect。任意偏移/不同尺寸的嵌入式 FlutterView 需要宿主提供视图几何；现有尺寸校验只能拒绝尺寸不匹配，不能识别所有同尺寸但不同原点的嵌入方式。不要把该场景当作已经支持。

## 折叠真机验收

先在折叠设备上启用开发者选项和 USB 调试，用 USB 或已授权的无线调试连接。先用 Flutter OH 确认它识别到设备：

```sh
/path/to/flutter-ohos/bin/flutter devices
```

再使用同一套 OpenHarmony SDK 内的 HDC。`flutter doctor -v` 会显示 Flutter OH 实际使用的 SDK 根目录；在这个根目录下选择目标 API 的 `openharmony/toolchains/hdc`。不要混用另一套 DevEco SDK 的 HDC 服务。

```sh
# 将 <api-version> 替换为 flutter doctor -v 显示的已安装 SDK 版本。
HDC=/你的/OHOS_SDK_HOME/<api-version>/openharmony/toolchains/hdc
$HDC list targets
```

如果 `flutter devices` 能发现设备而 DevEco 的 HDC 返回 `[Empty]`，通常是两套 SDK 使用不同 HDC 服务；应改用 Flutter OH 配置的 SDK。设备 ID 出现后，用 DevEco Studio 打开 `example/ohos/`，在 **File → Project Structure → Signing Configs** 为 `entry` 配置自动生成的调试签名，再构建调试 HAP。官方的[自动签名说明](https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-signing-auto)要求设备已连接或已在调试设备列表中注册。

签名完成后，也可用命令行安装并启动。以下 `HAP` 使用 DevEco 产生的已签名包；不要安装本文档前文的 `unsigned.hap`：

```sh
HDC=/你的/OHOS_SDK_HOME/<api-version>/openharmony/toolchains/hdc
HAP=/绝对路径/entry-default-signed.hap
$HDC install "$HAP"
$HDC shell aa start \
  -b com.example.responsiveframework.responsive_foldable_ohos \
  -a EntryAbility
```

`hdc install` 和 `aa start` 的调用形式见 [OpenHarmony HDC 文档](https://github.com/openharmony/docs/blob/master/en/application-dev/dfx/hdc.md)。也可以在 DevEco 中选择设备后直接 Run；它会处理安装与启动。

示例顶部的状态标签会显示 `姿态 · 折痕数 · 首折轴角度`，用于观察桥接是否真的收到设备数据。每一步至少等待窗口尺寸稳定后再记录结果：

| 场景 | 预期结果 |
| --- | --- |
| 外屏折叠 | 状态不保留旧折痕；内容是单窗格 |
| 内屏完全展开 | 折痕数为 0；无内容落在中线遮挡区域 |
| 半折（横、竖各一次） | 状态为 `halfOpened`；折痕数大于 0；列表和编辑器分别落在两个区域 |
| 内外屏切换、旋转 | 页面不崩溃，不短暂使用旧折痕；编辑器输入仍保留 |
| 分屏或悬浮窗 | 若 FlutterView 未填满 drawableRect，预期只保留姿态且抑制折痕几何；记录该机型/固件 |
| 双折轴设备 | 核对每个角度和折痕的顺序；TwoPane 只选两个安全区域 |

安装后保存日志，便于定位设备差异：

```sh
$HDC shell hilog | rg 'ResponsiveFramework|flutter'
```
