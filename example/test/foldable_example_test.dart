import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal/main.dart';

// 默认示例使用本地内容，直接验证用户可以启动、编辑并切换折叠布局。
void main() {
  testWidgets('example opens and preserves input across preview modes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('笔记'), findsOneWidget);
    final editor = find.byKey(const ValueKey('note-editor'));
    await tester.enterText(editor, '折叠后保留这段文字');
    await tester.tap(find.byTooltip('切换折叠模式').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('上下折叠').last);
    await tester.pumpAndSettle();
    expect(find.text('折叠后保留这段文字'), findsOneWidget);
    expect(tester.getRect(editor).top, greaterThan(400));
    // 从双栏切回手机窗口后，点击笔记仍可进入同一份编辑内容。
    await tester.tap(find.byTooltip('切换折叠模式').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('完全展开').last);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    await tester.tap(find.text('旅行计划').first);
    await tester.pumpAndSettle();
    expect(find.text('折叠后保留这段文字'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
