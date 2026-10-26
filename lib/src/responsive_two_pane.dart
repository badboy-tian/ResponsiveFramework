import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'utils/region_media_query.dart';

/// 显式策略只控制窗格数量，始终保留物理铰链避让和最小尺寸约束。
enum ResponsiveTwoPaneMode { auto, single, dual }

/// 窗格读取实际布局结果，避免业务端再次按屏宽推测是否存在双栏。
@immutable
class ResponsiveTwoPaneLayout {
  ResponsiveTwoPaneLayout({
    required this.primaryBounds,
    required this.secondaryBounds,
    required this.isDual,
    required this.showSecondary,
    required this.hasDisplayFeatureDivision,
    required this.axis,
    required List<Rect> availableRegions,
  }) : availableRegions = List.unmodifiable(availableRegions);

  // 矩形相对于 TwoPane 原点；浮层需使用 anchorPointFor 转换到窗口坐标。
  final Rect primaryBounds;
  final Rect secondaryBounds;
  final bool isDual;
  final bool showSecondary;
  final bool hasDisplayFeatureDivision;
  final Axis? axis;
  final List<Rect> availableRegions;
  bool get isPrimaryVisible => isDual || !showSecondary;
  bool get isSecondaryVisible => isDual || showSecondary;

  @override
  bool operator ==(Object other) =>
      other is ResponsiveTwoPaneLayout &&
      primaryBounds == other.primaryBounds &&
      secondaryBounds == other.secondaryBounds &&
      isDual == other.isDual &&
      showSecondary == other.showSecondary &&
      hasDisplayFeatureDivision == other.hasDisplayFeatureDivision &&
      axis == other.axis &&
      listEquals(availableRegions, other.availableRegions);

  @override
  int get hashCode => Object.hash(
      primaryBounds,
      secondaryBounds,
      isDual,
      showSecondary,
      hasDisplayFeatureDivision,
      axis,
      Object.hashAll(availableRegions));
}

// 布局元数据只在结果变化时通知，父组件的无关重建不会打扰消费者。
class _TwoPaneScope extends InheritedWidget {
  const _TwoPaneScope({required this.data, required super.child});
  final ResponsiveTwoPaneLayout data;

  @override
  bool updateShouldNotify(_TwoPaneScope oldWidget) => data != oldWidget.data;
}

/// 使用有效折痕或宽度阈值划分两个窗格，并在切换时保留两侧 State。
///
/// 与 DisplayFeatureSubScreen 相同，默认区域坐标相对于最近的 MediaQuery。
/// 应放在该 MediaQuery 的原点处；嵌套在有偏移的容器中时，传入已转换到
/// 局部坐标的 [displayFeatures]。父约束的宽高必须有界。
class ResponsiveTwoPane extends StatelessWidget {
  const ResponsiveTwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint,
    this.spacing = 24,
    this.primaryFraction = 0.4,
    this.showSecondary = false,
    this.displayFeatures,
    this.mode = ResponsiveTwoPaneMode.auto,
    this.minPrimarySize = Size.zero,
    this.minSecondarySize = Size.zero,
  })  : assert(breakpoint == null || breakpoint > 0),
        assert(spacing >= 0),
        assert(primaryFraction > 0 && primaryFraction < 1);

  final Widget primary;
  final Widget secondary;

  /// 为 null 时使用 [defaultBreakpoint]。
  final double? breakpoint;

  /// 跟随各平台分栏规范：OHOS 的 Navigation 在 600vp 起分栏，
  /// Mate X 展开态约 711vp；Material 列表详情在 840dp 的 expanded 起双栏。
  static double get defaultBreakpoint =>
      !kIsWeb && defaultTargetPlatform.name == 'ohos' ? 600 : 840;
  final double spacing;
  final double primaryFraction;

  /// 紧凑窗口中显示详情；另一侧仍保留 State，但不参与绘制与语义树。
  final bool showSecondary;
  final List<DisplayFeature>? displayFeatures;

  /// dual 跳过宽度阈值，single 只显示一侧；两者都不能覆盖物理铰链。
  final ResponsiveTwoPaneMode mode;

  /// 两侧内容需求不同，分别设置最小外框；任一过小时退回单窗格。
  final Size minPrimarySize;
  final Size minSecondarySize;

  static ResponsiveTwoPaneLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TwoPaneScope>()?.data;

  /// 在 primary/secondary 内调用，单栏时隐藏的窗格也能读取同一份布局结果。
  static ResponsiveTwoPaneLayout of(BuildContext context) {
    final layout = maybeOf(context);
    if (layout != null) return layout;
    throw FlutterError(
        'ResponsiveTwoPane.of() requires a ResponsiveTwoPane ancestor.');
  }

  /// 在已布局的按钮回调中调用，避免把窗格局部坐标误传给 DialogRoute。
  static Offset anchorPointFor(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      throw FlutterError('anchorPointFor() requires a laid-out RenderBox. '
          'Call it from the triggering control callback.');
    }
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    // Size 的 getter 不能用于 const 构造断言，放在 build 验证以保留 const 用法。
    assert(minPrimarySize.width >= 0 && minPrimarySize.height >= 0);
    assert(minSecondarySize.width >= 0 && minSecondarySize.height >= 0);
    final media = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
        throw FlutterError(
            'ResponsiveTwoPane requires bounded width and height. '
            'Place it in an Expanded or SizedBox inside scrollable layouts.');
      }
      final bounds = Offset.zero & constraints.biggest;
      // 相机遮挡不应把整个页面切成两半；零宽半折痕则确实需要分区。
      final obstructions = (displayFeatures ?? media.displayFeatures)
          .where((feature) =>
              (feature.type == DisplayFeatureType.fold ||
                  feature.type == DisplayFeatureType.hinge) &&
              (feature.bounds.shortestSide > 0 ||
                  feature.state == DisplayFeatureState.postureHalfOpened))
          .map((feature) => feature.bounds)
          // 局部容器可能收到窗口外的折痕，先过滤再裁剪，防止生成越界窗格。
          .where((rect) => rect.width == 0
              ? rect.left > bounds.left &&
                  rect.left < bounds.right &&
                  rect.top < bounds.bottom &&
                  rect.bottom > bounds.top
              : rect.height == 0
                  ? rect.top > bounds.top &&
                      rect.top < bounds.bottom &&
                      rect.left < bounds.right &&
                      rect.right > bounds.left
                  : rect.overlaps(bounds))
          .map((rect) => rect.intersect(bounds));
      final regions =
          DisplayFeatureSubScreen.subScreensInBounds(bounds, obstructions)
              .where((region) => !region.isEmpty)
              .toList();
      // 边缘铰链只留下一个区域时，普通宽屏分栏也必须限制在该区域内。
      final usable = regions.length == 1 ? regions.single : bounds;
      Rect first = usable;
      Rect second = usable;
      final hasDivision = regions.length > 1;
      var dual = mode != ResponsiveTwoPaneMode.single &&
          (hasDivision ||
              mode == ResponsiveTwoPaneMode.dual ||
              usable.width >= (breakpoint ?? defaultBreakpoint));
      if (hasDivision) {
        // 两窗格只消费两个区域，额外区域不跨越铰链合并，保证内容不被遮挡。
        regions.sort((a, b) {
          final row = a.top.compareTo(b.top);
          return row != 0
              ? row
              : (rtl ? b.left.compareTo(a.left) : a.left.compareTo(b.left));
        });
        first = regions[0];
        second = regions[1];
      } else if (dual) {
        // 普通宽屏也可双栏，但使用逻辑阅读顺序以支持 RTL。
        // 间距不大于窗口本身，避免紧凑容器中出现越界的空窗格。
        final gap = spacing.clamp(0.0, usable.width);
        final available = usable.width - gap;
        final primaryWidth = available * primaryFraction;
        final secondaryWidth = available - primaryWidth;
        first = Rect.fromLTWH(
            usable.left + (rtl ? usable.width - primaryWidth : 0),
            usable.top,
            primaryWidth,
            usable.height);
        second = Rect.fromLTWH(usable.left + (rtl ? 0 : primaryWidth + gap),
            usable.top, secondaryWidth, usable.height);
      } else if (regions.isNotEmpty) {
        // 窗口边缘的铰链可能只剩一个可用区域，也不能把内容铺回遮挡处。
        first = second = regions.single;
      }

      // 策略只能请求双栏，内容最小尺寸仍是硬约束；物理分区保留原位。
      dual = dual &&
          first.width >= minPrimarySize.width &&
          second.width >= minSecondarySize.width &&
          first.height >= minPrimarySize.height &&
          second.height >= minSecondarySize.height;
      if (!dual && !hasDivision) first = second = usable;
      final layout = ResponsiveTwoPaneLayout(
        primaryBounds: first,
        secondaryBounds: second,
        isDual: dual,
        showSecondary: showSecondary,
        hasDisplayFeatureDivision: hasDivision,
        axis: !dual
            ? null
            : (first.right <= second.left || second.right <= first.left
                ? Axis.horizontal
                : Axis.vertical),
        availableRegions: regions,
      );

      Widget pane(Rect rect, bool visible, Widget child) {
        // 每侧都发布局部 MediaQuery，让嵌套断点和 SafeArea 使用实际可用区域。
        final localMedia = mediaQueryForRegion(
          media.copyWith(
            size: constraints.biggest,
            displayFeatures: displayFeatures ?? media.displayFeatures,
          ),
          rect,
        );
        return Positioned.fromRect(
          rect: rect,
          child: MediaQuery(
            data: localMedia,
            child: TickerMode(
              enabled: visible,
              // 隐藏窗格仍保留 State，但不能继续持有输入焦点或接收按键。
              child: ExcludeFocus(
                excluding: !visible,
                child: Offstage(offstage: !visible, child: child),
              ),
            ),
          ),
        );
      }

      // 固定树结构，旋转、折叠和列表/详情切换都不会重新挂载窗格。
      return _TwoPaneScope(
          data: layout,
          child: Stack(children: [
            pane(first, layout.isPrimaryVisible, primary),
            pane(second, layout.isSecondaryVisible, secondary),
          ]));
    });
  }
}
