import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';

// 使用真实矩形验证避让边界，防止测试只复述布局判断而漏掉坐标错误。
void main() {
  const first = ValueKey('primary');
  const second = ValueKey('secondary');
  Future<void> layout(
    WidgetTester tester, {
    Size size = const Size(800, 600),
    List<DisplayFeature> features = const [],
    bool rtl = false,
    bool detail = false,
    Widget? secondary,
    Widget? primary,
    ResponsiveTwoPaneMode mode = ResponsiveTwoPaneMode.auto,
    double minPaneWidth = 0,
    double minPaneHeight = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(size: size, displayFeatures: features),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: ResponsiveTwoPane(
          mode: mode,
          minPrimarySize: Size(minPaneWidth, minPaneHeight),
          minSecondarySize: Size(minPaneWidth, minPaneHeight),
          showSecondary: detail,
          primary: primary ?? const ColoredBox(key: first, color: Colors.red),
          secondary:
              secondary ?? const ColoredBox(key: second, color: Colors.blue),
        ),
      ),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('explicit modes override width breakpoint', (tester) async {
    ResponsiveTwoPaneLayout? result;
    final probe = Builder(builder: (context) {
      result = ResponsiveTwoPane.of(context);
      return const ColoredBox(key: first, color: Colors.red);
    });
    // 业务可以在紧凑窗口中请求双栏，也可以在宽屏中保持阅读单栏。
    await layout(tester,
        size: const Size(600, 600),
        mode: ResponsiveTwoPaneMode.dual,
        primary: probe);
    expect(result!.isDual, true);
    expect(result!.axis, Axis.horizontal);
    expect(result!.primaryBounds, tester.getRect(find.byKey(first)));
    expect(result!.availableRegions, [const Rect.fromLTWH(0, 0, 600, 600)]);
    expect(() => result!.availableRegions.clear(), throwsUnsupportedError);
    await layout(tester,
        size: const Size(1000, 600),
        mode: ResponsiveTwoPaneMode.single,
        primary: probe);
    expect(result!.isDual, false);
    expect(result!.axis, isNull);
    expect(tester.getRect(find.byKey(first)).width, 1000);
  });

  // 707×773 为 HarmonyOS 双折叠模拟器展开态的实测逻辑尺寸。
  testWidgets('Material platforms keep a 707 wide window single',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(ResponsiveTwoPane.defaultBreakpoint, 840);
    await layout(tester, size: const Size(707, 773));
    expect(tester.getRect(find.byKey(first)).width, 707);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('OHOS splits a 707 wide foldable window like Navigation',
      (tester) async {
    debugDefaultTargetPlatformOverride =
        TargetPlatform.values.firstWhere((p) => p.name == 'ohos');
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(ResponsiveTwoPane.defaultBreakpoint, 600);
    await layout(tester, size: const Size(707, 773));
    expect(tester.getRect(find.byKey(first)).right,
        lessThan(tester.getRect(find.byKey(second)).left));
    await layout(tester, size: const Size(440, 707));
    expect(tester.getRect(find.byKey(first)).width, 440);
    debugDefaultTargetPlatformOverride = null;
  }, skip: !TargetPlatform.values.any((p) => p.name == 'ohos'));

  testWidgets('minimum width prevents cramped fallback columns',
      (tester) async {
    await layout(tester,
        size: const Size(1000, 600),
        mode: ResponsiveTwoPaneMode.dual,
        minPaneWidth: 450);
    expect(find.byKey(second), findsNothing);
    expect(tester.getRect(find.byKey(first)).width, 1000);
  });

  testWidgets('list and detail may specify different minimum sizes',
      (tester) async {
    // 列表无需像编辑器一样宽，独立约束可避免不必要的单栏回退。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: ResponsiveTwoPane(
      minPrimarySize: Size(240, 200),
      minSecondarySize: Size(480, 300),
      primary: ColoredBox(key: first, color: Colors.red),
      secondary: ColoredBox(key: second, color: Colors.blue),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(second), findsOneWidget);
    expect(tester.getRect(find.byKey(first)).width, greaterThanOrEqualTo(240));
    expect(tester.getRect(find.byKey(second)).width, greaterThanOrEqualTo(480));
  });

  testWidgets('minimum height fallback stays in the selected physical region',
      (tester) async {
    ResponsiveTwoPaneLayout? result;
    await layout(tester, minPaneHeight: 280, detail: true, features: const [
      DisplayFeature(
          bounds: Rect.fromLTWH(0, 260, 800, 20),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened),
    ], secondary: Builder(builder: (context) {
      result = ResponsiveTwoPane.of(context);
      return const ColoredBox(key: second, color: Colors.blue);
    }));
    // 显示一侧时仍不跨过铰链，且结果明确区分姿态分区与双栏是否启用。
    expect(result!.hasDisplayFeatureDivision, true);
    expect(result!.isPrimaryVisible, false);
    expect(result!.isSecondaryVisible, true);
    expect(result!.isDual, false);
    expect(tester.getRect(find.byKey(second)),
        const Rect.fromLTWH(0, 280, 800, 320));
  });

  testWidgets('single mode still avoids physical hinge', (tester) async {
    await layout(tester, mode: ResponsiveTwoPaneMode.single, features: const [
      DisplayFeature(
          bounds: Rect.fromLTWH(350, 0, 20, 600),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat),
    ]);
    expect(
        tester.getRect(find.byKey(first)), const Rect.fromLTWH(0, 0, 350, 600));
    expect(find.byKey(second), findsNothing);
  });

  testWidgets(
      'anchor helper converts a laid-out control into window coordinates',
      (tester) async {
    BuildContext? control;
    await tester.pumpWidget(MaterialApp(
        home: Padding(
      padding: const EdgeInsets.only(left: 40, top: 80),
      child: Align(
          alignment: Alignment.topLeft,
          child: Builder(builder: (context) {
            control = context;
            return const SizedBox(width: 100, height: 60);
          })),
    )));
    expect(ResponsiveTwoPane.maybeOf(control!), isNull);
    expect(() => ResponsiveTwoPane.of(control!), throwsFlutterError);
    expect(ResponsiveTwoPane.anchorPointFor(control!), const Offset(90, 110));
  });

  testWidgets('flat narrow fold keeps single pane', (tester) async {
    await layout(tester, features: const [
      DisplayFeature(
        bounds: Rect.fromLTWH(400, 0, 0, 600),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      )
    ]);
    expect(
        tester.getRect(find.byKey(first)), const Rect.fromLTWH(0, 0, 800, 600));
    expect(find.byKey(second), findsNothing);
  });

  testWidgets('zero width half-open fold separates panes', (tester) async {
    await layout(tester, features: const [
      DisplayFeature(
        bounds: Rect.fromLTWH(350, 0, 0, 600),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      )
    ]);
    expect(
        tester.getRect(find.byKey(first)), const Rect.fromLTWH(0, 0, 350, 600));
    expect(tester.getRect(find.byKey(second)),
        const Rect.fromLTWH(350, 0, 450, 600));
  });

  testWidgets('hinge gap is excluded and RTL reverses reading order',
      (tester) async {
    await layout(tester, rtl: true, features: const [
      DisplayFeature(
        bounds: Rect.fromLTWH(300, 0, 20, 600),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      )
    ]);
    expect(tester.getRect(find.byKey(first)),
        const Rect.fromLTWH(320, 0, 480, 600));
    expect(tester.getRect(find.byKey(second)),
        const Rect.fromLTWH(0, 0, 300, 600));
  });

  testWidgets('tabletop publishes local size and removes separating fold',
      (tester) async {
    MediaQueryData? local;
    await layout(tester, features: const [
      DisplayFeature(
        bounds: Rect.fromLTWH(0, 260, 800, 20),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      )
    ], secondary: Builder(builder: (context) {
      local = MediaQuery.of(context);
      return const ColoredBox(key: second, color: Colors.blue);
    }));
    expect(tester.getRect(find.byKey(second)),
        const Rect.fromLTWH(0, 280, 800, 320));
    expect(local!.size, const Size(800, 320));
    expect(local!.displayFeatures, isEmpty);
  });

  testWidgets('camera cutout does not force two panes', (tester) async {
    await layout(tester, features: const [
      DisplayFeature(
        bounds: Rect.fromLTWH(390, 0, 20, 30),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      )
    ]);
    expect(find.byKey(second), findsNothing);
  });

  testWidgets('features outside a local viewport do not create oversized panes',
      (tester) async {
    // 平移到局部容器后，落在容器外的折痕不应使窗格超过父约束。
    await layout(tester, features: const [
      DisplayFeature(
        bounds: Rect.fromLTWH(900, 0, 20, 600),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      )
    ]);
    expect(
        tester.getRect(find.byKey(first)), const Rect.fromLTWH(0, 0, 800, 600));
    expect(find.byKey(second), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide fallback avoids a hinge clipped to the viewport edge',
      (tester) async {
    // 一个边缘遮挡不会形成两个物理区域，但普通双栏也不能覆盖它。
    await layout(tester, size: const Size(1000, 600), features: const [
      DisplayFeature(
        bounds: Rect.fromLTWH(0, 0, 20, 600),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      )
    ]);
    expect(tester.getRect(find.byKey(first)).left, 20);
    expect(tester.getRect(find.byKey(second)).right, 1000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resize and compact detail preserve editor State',
      (tester) async {
    // Material 祖先由宿主负责，测试保持与真实页面相同的使用条件。
    const editor = Material(child: TextField(key: ValueKey('editor')));
    await layout(tester, size: const Size(1000, 700), secondary: editor);
    await tester.enterText(find.byKey(const ValueKey('editor')), '保留输入');
    await layout(tester, size: const Size(400, 700), secondary: editor);
    expect(find.byKey(const ValueKey('editor')), findsNothing);
    await layout(tester,
        size: const Size(400, 700), detail: true, secondary: editor);
    expect(find.text('保留输入'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('centered max width translates and clips hinge coordinates',
      (tester) async {
    MediaQueryData? local;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600), displayFeatures: [
        DisplayFeature(
          bounds: Rect.fromLTWH(390, 0, 20, 600),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        )
      ]),
      child: MaxWidthBox(
          maxWidth: 400,
          child: Builder(builder: (context) {
            local = MediaQuery.of(context);
            return const SizedBox.expand();
          })),
    )));
    await tester.pump();
    expect(local!.size.width, 400);
    expect(local!.displayFeatures.single.bounds.left, 190);
  });
}
