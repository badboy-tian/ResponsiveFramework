// 显式引用引擎类型，确保折痕探针不依赖组件库的间接导出。
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';

// 使用可控窗口和折痕，区分组件缺陷与尚未验证的平台数据接入。
void main() {
  const points = [
    Breakpoint(start: 0, end: 599, name: MOBILE),
    Breakpoint(start: 600, end: double.infinity, name: TABLET),
  ];

  testWidgets('first frame exposes initialized breakpoint dimensions',
      (tester) async {
    ResponsiveBreakpointsData? first;
    await tester.pumpWidget(MaterialApp(
        home: ResponsiveBreakpoints(
      breakpoints: points,
      child: Builder(builder: (context) {
        // 首帧不应依赖下一帧回调，否则消费端可能先构建错误的布局。
        first ??= ResponsiveBreakpoints.of(context);
        return const SizedBox();
      }),
    )));
    expect(first!.screenWidth, 800);
    expect(first!.breakpoint.name, TABLET);
  });

  testWidgets('platform change refreshes landscape breakpoints at same size',
      (tester) async {
    ResponsiveBreakpointsData? latest;
    Widget tree(TargetPlatform platform) => MaterialApp(
          theme: ThemeData(platform: platform),
          home: ResponsiveBreakpoints(
            breakpoints: const [
              Breakpoint(start: 0, end: double.infinity, name: MOBILE)
            ],
            breakpointsLandscape: const [
              Breakpoint(start: 0, end: double.infinity, name: TABLET)
            ],
            child: Builder(builder: (context) {
              latest = ResponsiveBreakpoints.of(context);
              return const SizedBox();
            }),
          ),
        );
    // 主题的平台变化不改变窗口，但会影响横屏断点是否启用。
    await tester.pumpWidget(tree(TargetPlatform.android));
    expect(latest!.breakpoint.name, TABLET);
    await tester.pumpWidget(tree(TargetPlatform.linux));
    await tester.pumpAndSettle();
    expect(latest!.breakpoint.name, MOBILE);
  });

  testWidgets('physical window resize updates breakpoint', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ResponsiveBreakpointsData? latest;
    await tester.pumpWidget(MaterialApp(
        home: ResponsiveBreakpoints(
      breakpoints: points,
      child: Builder(builder: (context) {
        latest = ResponsiveBreakpoints.of(context);
        return const SizedBox();
      }),
    )));
    await tester.pumpAndSettle();
    expect(latest!.breakpoint.name, MOBILE);
    tester.view.physicalSize = const Size(900, 800);
    await tester.pumpAndSettle();
    expect(latest!.breakpoint.name, TABLET);
  });

  testWidgets('inherited MediaQuery change updates cached child',
      (tester) async {
    final size = ValueNotifier(const Size(400, 800));
    addTearDown(size.dispose);
    ResponsiveBreakpointsData? latest;
    final responsive = ResponsiveBreakpoints(
      breakpoints: points,
      child: Builder(builder: (context) {
        latest = ResponsiveBreakpoints.of(context);
        return const SizedBox();
      }),
    );
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<Size>(
      valueListenable: size,
      child: responsive,
      builder: (context, value, child) =>
          MediaQuery(data: MediaQueryData(size: value), child: child!),
    )));
    await tester.pumpAndSettle();
    size.value = const Size(900, 800);
    await tester.pumpAndSettle();
    // 局部可用区域变化不一定触发物理窗口事件，因此必须独立验证。
    expect(latest!.screenWidth, 900);
  });

  testWidgets('breakpoint configuration changes at same size', (tester) async {
    ResponsiveBreakpointsData? latest;
    Widget tree(String name) => MaterialApp(
            home: ResponsiveBreakpoints(
          breakpoints: [Breakpoint(start: 0, end: double.infinity, name: name)],
          child: Builder(builder: (context) {
            latest = ResponsiveBreakpoints.of(context);
            return const SizedBox();
          }),
        ));
    await tester.pumpWidget(tree(MOBILE));
    await tester.pumpAndSettle();
    await tester.pumpWidget(tree(TABLET));
    await tester.pumpAndSettle();
    expect(latest!.breakpoint.name, TABLET);
  });

  testWidgets('scaled content receives scaled hinge coordinates',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MediaQueryData? latest;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600), displayFeatures: [
        DisplayFeature(
            bounds: Rect.fromLTWH(390, 0, 20, 600),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat),
      ]),
      child: ResponsiveScaledBox(
          width: 400,
          child: Builder(builder: (context) {
            latest = MediaQuery.of(context);
            return const SizedBox();
          })),
    )));
    await tester.pumpAndSettle();
    expect(latest!.size, const Size(400, 300));
    // 折痕与内容必须使用同一个坐标系，否则子树会在错误位置避让。
    expect(latest!.displayFeatures.single.bounds,
        const Rect.fromLTWH(195, 0, 10, 300));
  });
}
