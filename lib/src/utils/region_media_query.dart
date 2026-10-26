import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/widgets.dart';

// SDK 的 removeDisplayFeatures 不负责改写 size 或转换矩形，统一在此补齐。
MediaQueryData mediaQueryForRegion(MediaQueryData media, Rect region) {
  final features = <DisplayFeature>[];
  for (final feature in media.displayFeatures) {
    final rect = feature.bounds;
    // 零宽折线仅在区域内部有效，边界折线不能再次切割已划分的窗格。
    final inside = rect.width == 0
        ? rect.left > region.left &&
            rect.left < region.right &&
            rect.bottom > region.top &&
            rect.top < region.bottom
        : rect.height == 0
            ? rect.top > region.top &&
                rect.top < region.bottom &&
                rect.right > region.left &&
                rect.left < region.right
            : rect.overlaps(region);
    if (!inside) continue;
    features.add(DisplayFeature(
      bounds: rect.intersect(region).shift(-region.topLeft),
      type: feature.type,
      state: feature.state,
    ));
  }
  final gestures = media.systemGestureInsets;
  return media.removeDisplayFeatures(region).copyWith(
        size: region.size,
        displayFeatures: features,
        // 手势边界也只作用于实际贴着系统边缘的窗格。
        systemGestureInsets: EdgeInsets.fromLTRB(
          math.max(0, gestures.left - region.left),
          math.max(0, gestures.top - region.top),
          math.max(0, gestures.right - (media.size.width - region.right)),
          math.max(0, gestures.bottom - (media.size.height - region.bottom)),
        ),
      );
}
