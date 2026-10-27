import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

import 'utils/region_media_query.dart';
import 'utils/fold_regions.dart';

/// 将现有子组件放入实际分隔区域；没有分隔时只显示选中的窗格。
///
/// 坐标与最近的 MediaQuery 一致；嵌入有偏移的容器时请传入局部坐标。
/// 展开态折线默认不分割，业务可通过 [splitFlatFolds] 显式启用。
class ResponsiveMultiPane extends StatelessWidget {
  const ResponsiveMultiPane({
    super.key,
    required this.children,
    this.displayFeatures,
    this.singlePaneIndex = 0,
    this.splitFlatFolds = false,
  }) : assert(children.length > 0);

  final List<Widget> children;
  final List<DisplayFeature>? displayFeatures;
  final int singlePaneIndex;
  final bool splitFlatFolds;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    assert(singlePaneIndex >= 0 && singlePaneIndex < children.length);
    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
        throw FlutterError(
            'ResponsiveMultiPane requires bounded width and height.');
      }
      final bounds = Offset.zero & constraints.biggest;
      final features = displayFeatures ?? media.displayFeatures;
      final obstructions = features.where((feature) {
        if (feature.type != DisplayFeatureType.fold &&
            feature.type != DisplayFeatureType.hinge) {
          return false;
        }
        // 展开折痕不是遮挡，只有调用方明确要求才用于布局分割。
        if (!splitFlatFolds &&
            feature.type == DisplayFeatureType.fold &&
            feature.state != DisplayFeatureState.postureHalfOpened) {
          return false;
        }
        final r = feature.bounds;
        return r.width == 0
            ? r.left > bounds.left &&
                r.left < bounds.right &&
                r.top < bounds.bottom &&
                r.bottom > bounds.top
            : r.height == 0
                ? r.top > bounds.top &&
                    r.top < bounds.bottom &&
                    r.left < bounds.right &&
                    r.right > bounds.left
                : r.overlaps(bounds);
      }).map((feature) => feature.bounds.intersect(bounds));
      final regions = foldRegions(bounds, obstructions);
      regions.sort((a, b) {
        final row = a.top.compareTo(b.top);
        return row != 0
            ? row
            : (rtl ? b.left.compareTo(a.left) : a.left.compareTo(b.left));
      });
      final single = regions.length <= 1;
      final region = regions.isEmpty ? bounds : regions.first;
      return Stack(children: [
        for (var i = 0; i < children.length; i++)
          // 保持每个子树的索引和层级，折叠时隐藏而不销毁其 State。
          Positioned.fromRect(
            rect: single ? region : (i < regions.length ? regions[i] : region),
            child: MediaQuery(
              data: mediaQueryForRegion(
                  media.copyWith(size: bounds.size, displayFeatures: features),
                  single ? region : (i < regions.length ? regions[i] : region)),
              child: TickerMode(
                enabled: single ? i == singlePaneIndex : i < regions.length,
                child: ExcludeFocus(
                  excluding:
                      single ? i != singlePaneIndex : i >= regions.length,
                  child: Offstage(
                    offstage:
                        single ? i != singlePaneIndex : i >= regions.length,
                    child: children[i],
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}
