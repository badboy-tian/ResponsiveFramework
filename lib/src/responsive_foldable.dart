// 引擎区域类型不由 widgets.dart 完整导出，显式引用以保持接口可编译。
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:foldable/foldable.dart';

import 'responsive_fold_posture.dart';
import 'ohos/ohos_foldable.dart';

// 保留原模块的姿态类型导出，避免破坏已有直接导入。
export 'responsive_fold_posture.dart';

// 在局部 MediaQuery 裁掉折痕之前保留窗口数据，窗格内仍能读取设备姿态。
class _EngineFoldScope extends InheritedWidget {
  _EngineFoldScope(
      {required List<DisplayFeature> features, required super.child})
      : features = List.unmodifiable(features);
  final List<DisplayFeature> features;

  @override
  bool updateShouldNotify(_EngineFoldScope oldWidget) =>
      !listEquals(features, oldWidget.features);
}

/// 在 MaterialApp.builder 中接入折叠区域，确保已有 MediaQuery 和 FlutterView。
///
/// iOS 使用 foldable 桥接，OHOS 使用 ArkTS 插件，Android 保留引擎数据。
/// full 模式会让弹窗和 sheet 避开折痕；调用方应为浮层选择 anchorPoint。
class ResponsiveFoldable extends StatelessWidget {
  // 显式包装才启用桥接，避免安装依赖就改变所有既有页面的浮层行为。
  const ResponsiveFoldable({
    super.key,
    required this.child,
    this.bridgeMode = DisplayFeatureBridgeMode.full,
  });

  final Widget child;

  /// 配置 iOS/OHOS 桥接；Android 始终保留引擎数据。
  final DisplayFeatureBridgeMode bridgeMode;

  /// iOS 只订阅姿态变化，避免角度连续更新导致普通布局高频重建。
  static ResponsiveFoldPosture postureOf(BuildContext context) {
    // 鸿蒙快照独立于局部 MediaQuery，裁剪窗格后仍保留姿态。
    final ohos = OhosFoldableScope.maybeOf(context, OhosFoldableAspect.posture);
    if (ohos != null && ohos.posture != ResponsiveFoldPosture.unknown) {
      return ohos.posture;
    }
    final status = DuoMediaQuery.statusOf(context);
    if (status != HingeStatus.unknown) {
      return switch (status) {
        HingeStatus.closed => ResponsiveFoldPosture.closed,
        HingeStatus.partiallyOpen => ResponsiveFoldPosture.halfOpened,
        HingeStatus.fullyOpen => ResponsiveFoldPosture.flat,
        HingeStatus.unknown => ResponsiveFoldPosture.unknown,
      };
    }
    // Android 的铰链状态由引擎提供，缺少记录不等于设备不支持折叠。
    final folds = _engineDisplayFeatures(context).where((feature) =>
        feature.type == DisplayFeatureType.fold ||
        feature.type == DisplayFeatureType.hinge);
    if (folds.any(
        (feature) => feature.state == DisplayFeatureState.postureHalfOpened)) {
      return ResponsiveFoldPosture.halfOpened;
    }
    if (folds
        .any((feature) => feature.state == DisplayFeatureState.postureFlat)) {
      return ResponsiveFoldPosture.flat;
    }
    return ResponsiveFoldPosture.unknown;
  }

  /// true 为已检测到铰链，false 为原生明确无铰链，null 为能力未知。
  static bool? isFoldableOf(BuildContext context) {
    final ohos =
        OhosFoldableScope.maybeOf(context, OhosFoldableAspect.capability);
    if (ohos?.isFoldable != null) return ohos!.isFoldable;
    final native = InheritedModel.inheritFrom<DuoMediaQuery>(context,
            aspect: FoldableAspect.capabilities)
        ?.data
        .capabilities;
    if (native?.supportLevel == FoldableSupportLevel.availableNoHinge) {
      return false;
    }
    if (native?.isFoldable == true) return true;
    return _engineDisplayFeatures(context).any((feature) =>
            feature.type == DisplayFeatureType.fold ||
            feature.type == DisplayFeatureType.hinge)
        ? true
        : null;
  }

  /// 返回首折轴的真实角度，单位为度；不可用时为 null，不根据姿态合成角度。
  static double? angleOf(BuildContext context) {
    final ohos = OhosFoldableScope.maybeOf(context, OhosFoldableAspect.angle);
    return ohos == null
        ? DuoMediaQuery.angleOf(context)
        : (ohos.angles.isEmpty ? null : ohos.angles.first);
  }

  /// 多折轴设备按系统顺序返回角度；iOS 至多一个，未知时为空列表。
  static List<double> anglesOf(BuildContext context) {
    final ohos = OhosFoldableScope.maybeOf(context, OhosFoldableAspect.angle);
    if (ohos != null) return ohos.angles;
    final angle = DuoMediaQuery.angleOf(context);
    return angle == null ? const [] : List.unmodifiable([angle]);
  }

  /// OHOS 原生报告的折痕矩形，使用入口窗口逻辑坐标；不可用时为空。
  /// 展开态的折痕只作为元数据，不自动认作遮挡或要求分栏。
  static List<Rect> creaseBoundsOf(BuildContext context) =>
      OhosFoldableScope.maybeOf(context, OhosFoldableAspect.creases)?.creases ??
      const [];

  /// 高帧率效果直接监听流，避免通过整页 rebuild 驱动动画；监听者负责取消。
  static Stream<double> get hingeAngleStream {
    if (kIsWeb) return const Stream<double>.empty();
    // 使用名称检测，兼容标准 SDK 中没有 TargetPlatform.ohos 的情况。
    if (defaultTargetPlatform.name == 'ohos') {
      return OhosFoldableChannel.instance.angleStream;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? Foldable.hingeAngleStream
        : const Stream<double>.empty();
  }

  /// 即使 bridgeMode 为 none，也能读取有效区域供自定义页面布局使用。
  ///
  /// ResponsiveFoldable 应置于窗口原点，返回该入口的窗口坐标。
  /// 局部容器需先转换；没有包装器时，Android 退回当前 MediaQuery 的坐标。
  static List<DisplayFeature> displayFeaturesOf(BuildContext context) {
    final ohos =
        OhosFoldableScope.maybeOf(context, OhosFoldableAspect.features);
    if (ohos != null) return ohos.features;
    final native = InheritedModel.inheritFrom<DuoMediaQuery>(context,
        aspect: FoldableAspect.regions);
    if (native == null) return _engineDisplayFeatures(context);
    // 上游引擎开始提供区域时与插件保持一致，优先使用引擎，避免重复发布。
    if (View.maybeOf(context)?.displayFeatures.isNotEmpty == true) {
      return _engineDisplayFeatures(context);
    }
    // 只依赖区域和姿态，角度变化不会使区域消费者重建。
    return DisplayFeatureBridge.build(
      mode: DisplayFeatureBridgeMode.full,
      regions: native.data.regions,
      status: DuoMediaQuery.statusOf(context),
    );
  }

  static List<DisplayFeature> _engineDisplayFeatures(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_EngineFoldScope>()
          ?.features ??
      MediaQuery.of(context).displayFeatures;

  @override
  Widget build(BuildContext context) {
    // 所有平台保留入口的引擎坐标，未来 iOS 引擎接管区域数据时也不丢失窗口信息。
    final scopedChild = _EngineFoldScope(
        features: MediaQuery.of(context).displayFeatures, child: child);
    // 平台以运行环境判断，不能用 Theme.platform 冒充原生能力。
    // 鸿蒙原生插件只在 OH 分支调用，Android/iOS 不访问该通道。
    if (!kIsWeb && defaultTargetPlatform.name == 'ohos') {
      return OhosFoldableProvider(bridgeMode: bridgeMode, child: scopedChild);
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return scopedChild;
    }
    return FoldableProvider(bridgeMode: bridgeMode, child: scopedChild);
  }
}
