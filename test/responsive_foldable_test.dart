import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable/foldable.dart'
    show DuoMediaQuery, FoldableData, HingeStatus;
import 'package:responsive_framework/responsive_framework.dart';

// 模拟原生通道的真实结构，验证 iOS 接入而不要求测试主机具有铰链。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('angle-only updates do not rebuild posture consumers',
      (tester) async {
    final snapshot = ValueNotifier(FoldableData.unsupported
        .copyWith(status: HingeStatus.partiallyOpen, angleDegrees: 90));
    addTearDown(snapshot.dispose);
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<FoldableData>(
      valueListenable: snapshot,
      child: Builder(builder: (context) {
        // 消费姿态的布局不应随角度流重建，性能约束通过独立变化来验证。
        builds++;
        ResponsiveFoldable.postureOf(context);
        ResponsiveFoldable.displayFeaturesOf(context);
        return const SizedBox();
      }),
      builder: (context, value, child) =>
          DuoMediaQuery(data: value, child: child!),
    )));
    final initial = builds;
    snapshot.value = snapshot.value.copyWith(angleDegrees: 120);
    await tester.pump();
    expect(builds, initial);
  });

  testWidgets('Android posture survives pane-local feature removal',
      (tester) async {
    ResponsiveFoldPosture? posture;
    List<DisplayFeature>? local;
    List<DisplayFeature>? window;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600), displayFeatures: [
        DisplayFeature(
            bounds: Rect.fromLTWH(390, 0, 20, 600),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureHalfOpened),
      ]),
      child: ResponsiveFoldable(
          child: ResponsiveTwoPane(
        primary: Builder(builder: (context) {
          posture = ResponsiveFoldable.postureOf(context);
          window = ResponsiveFoldable.displayFeaturesOf(context);
          local = MediaQuery.of(context).displayFeatures;
          return const SizedBox();
        }),
        secondary: const SizedBox(),
      )),
    )));
    await tester.pumpAndSettle();
    expect(local, isEmpty);
    expect(window!.single.bounds, const Rect.fromLTWH(390, 0, 20, 600));
    expect(posture, ResponsiveFoldPosture.halfOpened);
  });

  testWidgets('iOS snapshot bridges reserved division into MediaQuery',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const methods = MethodChannel('foldable/methods');
    const events = MethodChannel('foldable/events');
    var status = 'partiallyOpen';
    messenger.setMockMethodCallHandler(
        methods,
        (call) async => {
              'isFoldable': true,
              'supportLevel': 'available',
              'status': status,
              'angleDegrees': 90,
              'regions': [
                {
                  'kind': 'division',
                  'active': true,
                  'left': 390,
                  'top': 0,
                  'width': 20,
                  'height': 600
                },
              ],
            });
    messenger.setMockMethodCallHandler(events, (call) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockMethodCallHandler(events, null);
    });
    MediaQueryData? latest;
    ResponsiveFoldPosture? posture;
    bool? foldable;
    double? angle;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveFoldable(child: child!),
      home: Builder(builder: (context) {
        latest = MediaQuery.of(context);
        // 消费统一接口，确认业务不再依赖 iOS 插件的姿态枚举。
        posture = ResponsiveFoldable.postureOf(context);
        foldable = ResponsiveFoldable.isFoldableOf(context);
        angle = ResponsiveFoldable.angleOf(context);
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    expect(latest!.displayFeatures.single.bounds,
        const Rect.fromLTWH(390, 0, 20, 600));
    expect(posture, ResponsiveFoldPosture.halfOpened);
    expect(foldable, true);
    expect(angle, 90);
    // 原生区域标志可能延迟，恢复到展开态后不能继续发布旧分割区域。
    status = 'fullyOpen';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(latest!.displayFeatures, isEmpty);
    expect(posture, ResponsiveFoldPosture.flat);
    // 先卸载再移除 mock，确保取消订阅也被覆盖。
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('none bridge exposes raw iOS regions without changing MediaQuery',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const methods = MethodChannel('foldable/methods');
    const events = MethodChannel('foldable/events');
    messenger.setMockMethodCallHandler(
        methods,
        (call) async => {
              'isFoldable': true,
              'supportLevel': 'available',
              'status': 'partiallyOpen',
              'regions': [
                {
                  'kind': 'division',
                  'active': true,
                  'left': 390,
                  'top': 0,
                  'width': 20,
                  'height': 600
                },
              ],
            });
    messenger.setMockMethodCallHandler(events, (call) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockMethodCallHandler(events, null);
    });
    List<DisplayFeature>? raw;
    List<DisplayFeature>? bridged;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveFoldable(
          bridgeMode: DisplayFeatureBridgeMode.none, child: child!),
      home: Builder(builder: (context) {
        raw = ResponsiveFoldable.displayFeaturesOf(context);
        bridged = MediaQuery.of(context).displayFeatures;
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    expect(raw!.single.bounds, const Rect.fromLTWH(390, 0, 20, 600));
    expect(bridged, isEmpty);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('empty engine data means unknown posture and capability',
      (tester) async {
    ResponsiveFoldPosture? posture;
    bool? foldable;
    double? angle;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      posture = ResponsiveFoldable.postureOf(context);
      foldable = ResponsiveFoldable.isFoldableOf(context);
      angle = ResponsiveFoldable.angleOf(context);
      return const SizedBox();
    })));
    expect(posture, ResponsiveFoldPosture.unknown);
    expect(foldable, isNull);
    expect(angle, isNull);
  });

  testWidgets('Android preserves engine features without invoking iOS channel',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var calls = 0;
    const methods = MethodChannel('foldable/methods');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls++;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(methods, null));
    const features = [
      DisplayFeature(
        bounds: Rect.fromLTWH(390, 0, 20, 600),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      )
    ];
    MediaQueryData? latest;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data:
          const MediaQueryData(size: Size(800, 600), displayFeatures: features),
      child: ResponsiveFoldable(child: Builder(builder: (context) {
        latest = MediaQuery.of(context);
        return const Text('Android');
      })),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Android'), findsOneWidget);
    expect(calls, 0);
    expect(latest!.displayFeatures, same(features));
    debugDefaultTargetPlatformOverride = null;
  });
}
