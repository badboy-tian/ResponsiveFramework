import 'dart:ui' show DisplayFeatureState;

// 平台覆盖变量只由 foundation 导出，显式列出以兼容两个 SDK 的测试环境。
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:responsive_framework/src/ohos/ohos_foldable.dart';

// 固定物理坐标验证转换，不依赖测试主机是否拥有折叠硬件。
Map<Object?, Object?> snapshot({int status = 3}) => {
      'wireVersion': 1,
      'isFoldable': true,
      'foldStatus': status,
      'displayId': 7,
      'creaseDisplayId': 7,
      'angles': [90, 120],
      'viewRect': {'left': 100, 'top': 200, 'width': 1600, 'height': 1200},
      'creases': [
        {'left': 880, 'top': 200, 'width': 20, 'height': 1200},
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('physical screen rectangles become view-local logical rectangles', () {
    final data = OhosFoldableData.decode(snapshot(), const Size(800, 600), 2);
    expect(data.features.single.bounds, const Rect.fromLTWH(390, 0, 10, 600));
    expect(data.features.single.state, DisplayFeatureState.postureHalfOpened);
    expect(data.angles, [90.0, 120.0]);
    expect(data.geometryValid, true);
    expect(() => data.angles.clear(), throwsUnsupportedError);
    final horizontal = snapshot()
      ..['creases'] = [
        {'left': 100, 'top': 780, 'width': 1600, 'height': 20},
      ];
    expect(
        OhosFoldableData.decode(horizontal, const Size(800, 600), 2)
            .features
            .single
            .bounds,
        const Rect.fromLTWH(0, 290, 800, 10));
  });

  test('wrong display or mismatched viewport suppresses geometry only', () {
    final raw = snapshot()..['creaseDisplayId'] = 9;
    final wrongDisplay = OhosFoldableData.decode(raw, const Size(800, 600), 2);
    expect(wrongDisplay.features, isEmpty);
    expect(wrongDisplay.posture, ResponsiveFoldPosture.halfOpened);
    expect(wrongDisplay.geometryValid, false);
    final wrongSize =
        OhosFoldableData.decode(snapshot(), const Size(400, 600), 2);
    expect(wrongSize.features, isEmpty);
    expect(wrongSize.isFoldable, true);
  });

  test('flat and closed states do not leave a stale separating fold', () {
    expect(
        OhosFoldableData.decode(snapshot(status: 1), const Size(800, 600), 2)
            .features,
        isEmpty);
    final closed =
        OhosFoldableData.decode(snapshot(status: 2), const Size(800, 600), 2);
    expect(closed.posture, ResponsiveFoldPosture.closed);
    expect(closed.features, isEmpty);
    expect(
        OhosFoldableData.decode(snapshot(status: 99), const Size(800, 600), 2)
            .posture,
        ResponsiveFoldPosture.unknown);
  });

  test('dual hinge statuses and all rectangles are retained', () {
    final raw = snapshot(status: 23);
    raw['creases'] = [
      {'left': 500, 'top': 200, 'width': 0, 'height': 1200},
      {'left': 1200, 'top': 200, 'width': 0, 'height': 1200},
    ];
    final data = OhosFoldableData.decode(raw, const Size(800, 600), 2);
    expect(data.posture, ResponsiveFoldPosture.halfOpened);
    expect(data.features.length, 2);
    for (final status in [1, 11, 12]) {
      expect(
          OhosFoldableData.decode(
                  snapshot(status: status), const Size(800, 600), 2)
              .posture,
          ResponsiveFoldPosture.flat);
    }
  });

  test('invalid payloads and unsupported wire versions remain unknown', () {
    expect(
        OhosFoldableData.decode({'wireVersion': 2}, const Size(800, 600), 2)
            .isFoldable,
        isNull);
    final raw = snapshot()..['angles'] = [double.nan, -1, 181, '90', 85];
    raw['creases'] = [
      {'left': '880'},
      null
    ];
    final data = OhosFoldableData.decode(raw, const Size(800, 600), 2);
    // 不能过滤无效首轴后把第二轴当作第一轴。
    expect(data.angles, isEmpty);
    expect(data.features, isEmpty);
  });

  test('flat crease metadata does not become a separating feature', () {
    final raw = snapshot(status: 11)
      ..['creases'] = [
        {'left': 500, 'top': 200, 'width': 0, 'height': 1200},
        {'left': 1200, 'top': 200, 'width': 0, 'height': 1200},
      ];
    final data = OhosFoldableData.decode(raw, const Size(800, 600), 2);
    expect(data.creases, [
      const Rect.fromLTWH(200, 0, 0, 600),
      const Rect.fromLTWH(550, 0, 0, 600)
    ]);
    expect(data.features, isEmpty);
    expect(
        OhosFoldableData.decode(snapshot(status: 2), const Size(800, 600), 2)
            .creases,
        isEmpty);
  });

  test('platform mapping compiles with both standard and OH enums', () {
    for (final platform in TargetPlatform.values) {
      expect(platform.responsiveTargetPlatform.name, platform.name);
    }
  });

  testWidgets(
      'OH provider bridges folds and preserves native posture in local panes',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        OhosFoldableChannel.methods, (call) async => snapshot());
    var canceled = false;
    const eventMethods = MethodChannel('responsive_framework/foldable/events');
    messenger.setMockMethodCallHandler(eventMethods, (call) async {
      if (call.method == 'cancel') canceled = true;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(OhosFoldableChannel.methods, null);
      messenger.setMockMethodCallHandler(eventMethods, null);
    });
    ResponsiveFoldPosture? posture;
    bool? foldable;
    List<double>? angles;
    bool? dual;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => OhosFoldableProvider(
          bridgeMode: DisplayFeatureBridgeMode.full, child: child!),
      home: ResponsiveTwoPane(
          primary: Builder(builder: (context) {
            posture = ResponsiveFoldable.postureOf(context);
            foldable = ResponsiveFoldable.isFoldableOf(context);
            angles = ResponsiveFoldable.anglesOf(context);
            dual = ResponsiveTwoPane.of(context).isDual;
            return const SizedBox();
          }),
          secondary: const SizedBox()),
    ));
    await tester.pumpAndSettle();
    expect(posture, ResponsiveFoldPosture.halfOpened);
    expect(foldable, true);
    expect(angles, [90.0, 120.0]);
    expect(dual, true);
    // 不改变窗口大小，直接模拟原生姿态事件，布局也必须随之取消分区。
    await messenger.handlePlatformMessage(
        OhosFoldableChannel.events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(snapshot(status: 1)),
        null);
    await tester.pumpAndSettle();
    expect(posture, ResponsiveFoldPosture.flat);
    expect(dual, false);
    // 卸载 Provider 后确认 EventChannel 取消，而非留下全局传感器监听。
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(canceled, true);
  });

  testWidgets('OH SDK dispatches the public wrapper to the native channel',
      (tester) async {
    final platform = TargetPlatform.values.firstWhere((p) => p.name == 'ohos');
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        OhosFoldableChannel.methods, (call) async => snapshot());
    const events = MethodChannel('responsive_framework/foldable/events');
    messenger.setMockMethodCallHandler(events, (call) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(OhosFoldableChannel.methods, null);
      messenger.setMockMethodCallHandler(events, null);
    });
    ResponsiveFoldPosture? posture;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveFoldable(child: child!),
      home: Builder(builder: (context) {
        posture = ResponsiveFoldable.postureOf(context);
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    expect(posture, ResponsiveFoldPosture.halfOpened);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  }, skip: !TargetPlatform.values.any((p) => p.name == 'ohos'));

  testWidgets('angle-only OH snapshots do not rebuild posture consumers',
      (tester) async {
    final state = ValueNotifier(
        OhosFoldableData.decode(snapshot(), const Size(800, 600), 2));
    addTearDown(state.dispose);
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<OhosFoldableData>(
      valueListenable: state,
      child: Builder(builder: (context) {
        ResponsiveFoldable.postureOf(context);
        ResponsiveFoldable.displayFeaturesOf(context);
        builds++;
        return const SizedBox();
      }),
      builder: (context, data, child) =>
          OhosFoldableScope(data: data, child: child!),
    )));
    final initial = builds;
    state.value = OhosFoldableData.decode(
        snapshot()..['angles'] = [100, 130], const Size(800, 600), 2);
    await tester.pump();
    expect(builds, initial);
  });
}
