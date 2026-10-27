import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';

void main() {
  testWidgets('two vertical or horizontal folds produce three local panes',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> render(List<DisplayFeature> features,
        {bool rtl = false}) async {
      await tester.pumpWidget(MaterialApp(
          home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: ResponsiveMultiPane(displayFeatures: features, children: [
          for (var i = 0; i < 3; i++)
            ColoredBox(key: ValueKey(i), color: Colors.blue),
        ]),
      )));
      await tester.pump();
    }

    const vertical = [
      DisplayFeature(
          bounds: Rect.fromLTWH(300, 0, 0, 600),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened),
      DisplayFeature(
          bounds: Rect.fromLTWH(600, 0, 0, 600),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened),
    ];
    await render(vertical);
    expect(tester.getRect(find.byKey(const ValueKey(0))),
        const Rect.fromLTWH(0, 0, 300, 600));
    expect(tester.getRect(find.byKey(const ValueKey(2))),
        const Rect.fromLTWH(600, 0, 300, 600));
    await render(vertical, rtl: true);
    expect(tester.getRect(find.byKey(const ValueKey(0))).left, 600);
    await render(const [
      DisplayFeature(
          bounds: Rect.fromLTWH(0, 200, 900, 0),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened),
      DisplayFeature(
          bounds: Rect.fromLTWH(0, 400, 900, 0),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened),
    ]);
    expect(tester.getRect(find.byKey(const ValueKey(2))),
        const Rect.fromLTWH(0, 400, 900, 200));
  });

  testWidgets('flat split is opt-in and hidden children retain their state',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> render(bool split) async {
      await tester.pumpWidget(MaterialApp(
          home: ResponsiveMultiPane(
        splitFlatFolds: split,
        displayFeatures: const [
          DisplayFeature(
              bounds: Rect.fromLTWH(300, 0, 0, 600),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureFlat),
          DisplayFeature(
              bounds: Rect.fromLTWH(600, 0, 0, 600),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureFlat),
        ],
        children: const [
          Text('first'),
          Material(child: TextField(key: ValueKey('editor'))),
          Text('third')
        ],
      )));
      await tester.pump();
    }

    await render(true);
    await tester.enterText(find.byKey(const ValueKey('editor')), '保留内容');
    await render(false);
    expect(find.byKey(const ValueKey('editor')), findsNothing);
    await render(true);
    expect(find.text('保留内容'), findsOneWidget);
  });
}
