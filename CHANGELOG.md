# Changelog
<!-- OHOS 的构建验证与真机验收分开记录，避免把 HAP 构建当成设备适配完成。 -->
## 1.7.0
- Expose validated OHOS crease metadata independently of separating features and add `ResponsiveMultiPane` for multiple reported partitions.
- Add an OHOS ArkTS plugin for fold status, display mode, crease rectangles, and hinge angles.
- Bridge screen-pixel rectangles into Flutter view coordinates with display and viewport validation.
- Add `ResponsiveFoldable.anglesOf` for multi-hinge data; `angleOf` and `hingeAngleStream` use the first hinge on OHOS.
- Map OH platform enums without referencing OH-only symbols from the standard Flutter SDK.
- Add an independent `example_ohos` host compatible with Flutter OH 3.35.8.
- Compile an unsigned HarmonyOS HAP; physical foldable device validation remains required.
- Default `ResponsiveTwoPane.breakpoint` to 600 on OHOS (840 elsewhere), so Mate X class inner displays use two panes.
- Prefer `getLiveCreaseRegion` (API 20+) and treat empty crease lists as missing geometry.

<!-- 记录最低版本变化，避免升级后才发现原生工具链要求。 -->
## 1.6.0
<!-- 补齐可复用的数据和策略接口，避免业务依赖内部实现或重复推断布局。 -->
- Expose platform-neutral posture, nullable fold capability, iOS angles, and unbridged window regions through `ResponsiveFoldable` queries.
- Add explicit single/dual modes, minimum pane bounds, immutable resolved layout queries, and a control-to-window anchor helper.
- Keep Android window posture available inside locally cropped panes; avoid iOS posture/region rebuilds on angle-only updates.
- Add `ResponsiveFoldable` for iPhone Duo reserved regions and Android engine display features.
- Add `ResponsiveTwoPane` for hinge-aware horizontal/vertical layouts, RTL, local pane metrics, and retained widget state.
- Fix breakpoint updates on the first frame, local MediaQuery changes, configuration changes, and platform changes.
- Transform display-feature coordinates when scaling or constraining content.
- Require Dart 3.5+, Flutter 3.24+, and iOS 15+ when building the iOS plugin. Use the iOS 27.1 SDK for Duo reserved regions.
- Run the local example with fold previews; update its Android and iOS host projects.

## 1.5.1
- Fix ScrollBehavior missing default values.

## 1.5.0
- Create new MaxWidthBox implementation that only uses constraints for setting max width.
- Create NoScrollBarBehavior.
- Update ScrollBehavior to inherit default behavior.
- Fix imports. Added responsive_utils.dart to the library file.
- Update examples.

## 1.4.0
- Update license.

## 1.3.0
- Refactor Library Imports. 
  - Unify library imports.
- Restore const Conditions.
  - Fix `copyWith` type.
- Update examples.
- Fix ResponsiveVisibility nullable type error.

## 1.2.0
- Flutter v3.19 update.
- ResponsiveValue nullable type support.
- Update ResponsiveRowColumn to use underlying Flex instead of Row and Columns.
  - Preserves nested widget state when switching between Rows and Columns.
- Fix `landscape` incorrectly set to always true.

## 1.1.1
- v1.0.0 migration guide: [Migration Guide](https://github.com/Codelessly/ResponsiveFramework/blob/master/migration_0.2.0_to_1.0.0.md)
- Fix landscape values null.
- Remove names and comments of deprecated `ResponsiveWrapper` in code.

## 1.1.0
- Breaking Change - Responsive Value Condition is no longer constant to support inheriting type nullability.
- Simplify example.

## 1.0.0
- New ResponsiveBreakpoints widget.
- Deprecated ResponsiveWrapper widget.

## 0.2.0
Legacy `ResponsiveWrapper` implementation.

Usage instructions:

```yaml
responsive_framework: 0.2.0
```

Add `ResponsiveWrapper.builder` to your MaterialApp or CupertinoApp.
```dart
import 'package:responsive_framework/responsive_framework.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => ResponsiveWrapper.builder(
          child,
          maxWidth: 1200,
          minWidth: 480,
          defaultScale: true,
          breakpoints: [
            ResponsiveBreakpoint.resize(480, name: MOBILE),
            ResponsiveBreakpoint.autoScale(800, name: TABLET),
            ResponsiveBreakpoint.resize(1000, name: DESKTOP),
          ],
          background: Container(color: Color(0xFFF5F5F5))),
      initialRoute: "/",
    );
  }
}
```
