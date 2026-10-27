import 'package:flutter/widgets.dart';

// 每条折线只作用于其实际穿过的子区域，避免 SDK 多折线算法扩大已有子区域。
List<Rect> foldRegions(Rect bounds, Iterable<Rect> obstructions) {
  var regions = <Rect>[bounds];
  for (final fold in obstructions) {
    final next = <Rect>[];
    for (final region in regions) {
      final vertical = fold.top <= region.top &&
          fold.bottom >= region.bottom &&
          fold.left < region.right &&
          fold.right > region.left;
      final horizontal = fold.left <= region.left &&
          fold.right >= region.right &&
          fold.top < region.bottom &&
          fold.bottom > region.top;
      if (vertical || horizontal) {
        next.addAll(DisplayFeatureSubScreen.subScreensInBounds(region, [fold])
            .where((part) => !part.isEmpty));
      } else {
        next.add(region);
      }
    }
    regions = next;
  }
  return regions;
}
