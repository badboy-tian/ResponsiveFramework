import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

// 示例用本地笔记验证布局切换，避免网络加载影响设备验收。
enum FoldPreview { device, book, tabletop, flat }

class FoldablePage extends StatefulWidget {
  const FoldablePage({super.key});
  static const name = 'foldable';

  @override
  State<FoldablePage> createState() => _FoldablePageState();
}

class _FoldablePageState extends State<FoldablePage> {
  FoldPreview _preview = FoldPreview.device;
  int _selected = 0;
  bool _detail = false;
  final _notes = ['旅行计划', '阅读清单', '周末安排'];
  final _editor = TextEditingController(text: '去海边走走。\n\n带上相机，留一点时间看日落。');
  final _contents = [
    '去海边走走。\n\n带上相机，留一点时间看日落。',
    '读完手边的书，再开始下一本。',
    '周六上午散步，下午整理照片。',
  ];

  @override
  void dispose() {
    // 控制器归页面所有，折叠时不销毁，离开页面时正常释放。
    _editor.dispose();
    super.dispose();
  }

  String _label(FoldPreview value) => switch (value) {
        FoldPreview.device => '跟随设备',
        FoldPreview.book => '左右折叠',
        FoldPreview.tabletop => '上下折叠',
        FoldPreview.flat => '完全展开',
      };

  Widget _modeMenu() => PopupMenuButton<FoldPreview>(
        tooltip: '切换折叠模式',
        initialValue: _preview,
        onSelected: (value) => setState(() => _preview = value),
        itemBuilder: (context) => [
          for (final value in FoldPreview.values)
            PopupMenuItem(value: value, child: Text(_label(value))),
        ],
        icon: const Icon(Icons.devices_fold),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 预览只替换区域数据；跟随设备时完整使用 Android/iOS 的实时桥接结果。
      final size = constraints.biggest;
      final List<DisplayFeature>? features = switch (_preview) {
        FoldPreview.device => null,
        FoldPreview.flat => const [],
        FoldPreview.book => [
            DisplayFeature(
              bounds: Rect.fromLTWH(size.width * 0.48, 0, 20, size.height),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureHalfOpened,
            )
          ],
        FoldPreview.tabletop => [
            DisplayFeature(
              bounds: Rect.fromLTWH(0, size.height * 0.48, size.width, 20),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureHalfOpened,
            )
          ],
      };
      return ColoredBox(
        color: const Color(0xFFDBE3E3),
        child: ResponsiveTwoPane(
          displayFeatures: features,
          spacing: 1,
          showSecondary: _detail,
          primary: Scaffold(
            backgroundColor: const Color(0xFFF2F6F6),
            appBar: AppBar(
                title: const Text('笔记'),
                actions: [const _FoldStateBadge(), _modeMenu()]),
            body: SafeArea(
              top: false,
              child: ListView.builder(
                key: const PageStorageKey('notes'),
                itemCount: _notes.length,
                itemBuilder: (context, index) => ListTile(
                  selected: index == _selected,
                  selectedTileColor: const Color(0xFFDDECE8),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(_notes[index]),
                  onTap: () => setState(() {
                    _contents[_selected] = _editor.text;
                    _selected = index;
                    _editor.text = _contents[index];
                    _detail = true;
                  }),
                ),
              ),
            ),
          ),
          secondary: Builder(builder: (paneContext) {
            // 在窗格上下文读取结果，双栏时移除返回按钮及其占位。
            final layout = ResponsiveTwoPane.of(paneContext);
            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: layout.isDual
                    ? null
                    : BackButton(
                        onPressed: () => setState(() => _detail = false)),
                title: Text(_notes[_selected],
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  _modeMenu(),
                  Builder(
                      builder: (context) => IconButton(
                            tooltip: '查看详情',
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                              // 浮层使用触发按钮的全局位置，确保落在用户正在操作的子屏。
                              showDialog<void>(
                                context: context,
                                anchorPoint:
                                    ResponsiveTwoPane.anchorPointFor(context),
                                builder: (context) => AlertDialog(
                                  title: Text(_notes[_selected]),
                                  content: const Text('修改会在折叠和展开后保留。'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('关闭'),
                                    )
                                  ],
                                ),
                              );
                            },
                          )),
                ],
              ),
              body: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    key: const ValueKey('note-editor'),
                    controller: _editor,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '写点什么…',
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    });
  }
}

/// 示例中显示真实桥接数据，真机验收时可区分设备事件与手动预览。
class _FoldStateBadge extends StatelessWidget {
  const _FoldStateBadge();

  @override
  Widget build(BuildContext context) {
    final posture = ResponsiveFoldable.postureOf(context).name;
    final featureCount = ResponsiveFoldable.displayFeaturesOf(context).length;
    final angle = ResponsiveFoldable.angleOf(context);
    final angleLabel = angle == null ? '—' : '${angle.round()}°';
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text('$posture · $featureCount · $angleLabel',
            key: const ValueKey('ohos-fold-state')),
      ),
    );
  }
}
