import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:foldable/foldable.dart' show DisplayFeatureBridgeMode;

import '../responsive_fold_posture.dart';

/// 通道只传物理坐标，统一使用 FlutterView 的 DPR 转换，避免混用 vp 与逻辑像素。
@immutable
class OhosFoldableData {
  const OhosFoldableData(
      {this.isFoldable,
      this.posture = ResponsiveFoldPosture.unknown,
      this.features = const [],
      this.creases = const [],
      this.angles = const [],
      this.geometryValid = false});

  final bool? isFoldable;
  final ResponsiveFoldPosture posture;
  final List<DisplayFeature> features;
  // 原生折痕与悬停避让分开，展开态不能被误认为存在物理遮挡。
  final List<Rect> creases;
  final List<double> angles;
  final bool geometryValid;

  static OhosFoldableData decode(
      Map<Object?, Object?>? raw, Size size, double dpr) {
    if (raw == null || raw['wireVersion'] != 1) return const OhosFoldableData();
    final status = raw['foldStatus'];
    // 双折轴枚举是组合状态，不能仅识别旧版的 1/2/3。
    final posture = switch (status) {
      1 || 11 || 12 => ResponsiveFoldPosture.flat,
      2 => ResponsiveFoldPosture.closed,
      3 || 13 || 21 || 22 || 23 => ResponsiveFoldPosture.halfOpened,
      _ => ResponsiveFoldPosture.unknown,
    };
    final rawAngles = raw['angles'];
    // 任一折轴非法时舍弃整组，避免过滤后把第二折轴误当成第一折轴。
    final angles = rawAngles is List &&
            rawAngles.every((n) => n is num && n.isFinite && n >= 0 && n <= 180)
        ? rawAngles.cast<num>().map((n) => n.toDouble()).toList()
        : <double>[];
    final view = _rect(raw['viewRect']);
    final valid = view != null &&
        dpr.isFinite &&
        dpr > 0 &&
        (view.width - size.width * dpr).abs() <= 2 &&
        (view.height - size.height * dpr).abs() <= 2 &&
        raw['displayId'] != null &&
        raw['displayId'] == raw['creaseDisplayId'];
    final features = <DisplayFeature>[];
    final creases = <Rect>[];
    // 展开态仅暴露折痕元数据；半折时才将其注入自动避让的 MediaQuery。
    if (valid &&
        (posture == ResponsiveFoldPosture.halfOpened ||
            posture == ResponsiveFoldPosture.flat) &&
        raw['creases'] is List) {
      for (final entry in raw['creases'] as List) {
        final rect = _rect(entry);
        if (rect == null) continue;
        final local = rect.shift(-view.topLeft);
        final bounds = Offset.zero & Size(size.width * dpr, size.height * dpr);
        final crosses = (local.top <= 0 &&
                local.bottom >= bounds.bottom &&
                local.left > 0 &&
                local.right < bounds.right) ||
            (local.left <= 0 &&
                local.right >= bounds.right &&
                local.top > 0 &&
                local.bottom < bounds.bottom);
        if (!crosses) continue;
        final clipped = local.intersect(bounds);
        final logical = Rect.fromLTRB(clipped.left / dpr, clipped.top / dpr,
            clipped.right / dpr, clipped.bottom / dpr);
        creases.add(logical);
        if (posture == ResponsiveFoldPosture.halfOpened) {
          features.add(DisplayFeature(
              bounds: logical,
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureHalfOpened));
        }
      }
    }
    return OhosFoldableData(
        isFoldable:
            raw['isFoldable'] is bool ? raw['isFoldable'] as bool : null,
        posture: posture,
        angles: List.unmodifiable(angles),
        features: List.unmodifiable(features),
        creases: List.unmodifiable(creases),
        geometryValid: valid);
  }

  static Rect? _rect(Object? value) {
    if (value is! Map) return null;
    final numbers =
        ['left', 'top', 'width', 'height'].map((key) => value[key]).toList();
    if (numbers.any((n) => n is! num || !n.isFinite) ||
        (numbers[2] as num) < 0 ||
        (numbers[3] as num) < 0) {
      return null;
    }
    return Rect.fromLTWH(
        (numbers[0] as num).toDouble(),
        (numbers[1] as num).toDouble(),
        (numbers[2] as num).toDouble(),
        (numbers[3] as num).toDouble());
  }
}

enum OhosFoldableAspect { posture, capability, features, creases, angle }

/// 按字段通知，角度传感器事件不应使依赖姿态的整页布局重建。
class OhosFoldableScope extends InheritedModel<OhosFoldableAspect> {
  const OhosFoldableScope(
      {super.key, required this.data, required super.child});
  final OhosFoldableData data;
  static OhosFoldableData? maybeOf(
          BuildContext context, OhosFoldableAspect aspect) =>
      InheritedModel.inheritFrom<OhosFoldableScope>(context, aspect: aspect)
          ?.data;
  @override
  bool updateShouldNotify(OhosFoldableScope oldWidget) => true;
  @override
  bool updateShouldNotifyDependent(
          OhosFoldableScope oldWidget, Set<OhosFoldableAspect> dependencies) =>
      dependencies.any((aspect) => switch (aspect) {
            OhosFoldableAspect.posture =>
              data.posture != oldWidget.data.posture,
            OhosFoldableAspect.capability =>
              data.isFoldable != oldWidget.data.isFoldable,
            OhosFoldableAspect.features =>
              !listEquals(data.features, oldWidget.data.features),
            OhosFoldableAspect.creases =>
              !listEquals(data.creases, oldWidget.data.creases),
            OhosFoldableAspect.angle =>
              !listEquals(data.angles, oldWidget.data.angles),
          });
}

/// 单个广播通道供 Provider 与角度流复用，最后一个订阅取消时释放原生监听。
class OhosFoldableChannel {
  static final instance = OhosFoldableChannel();
  static const methods = MethodChannel('responsive_framework/foldable/methods');
  static const events = EventChannel('responsive_framework/foldable/events');
  Stream<Map<Object?, Object?>?>? _snapshots;
  Future<Map<Object?, Object?>?> getSnapshot() async {
    try {
      return await methods.invokeMapMethod<Object?, Object?>('getSnapshot');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('ResponsiveFramework OHOS snapshot: ${error.code}');
      return null;
    }
  }

  Stream<Map<Object?, Object?>?> get snapshots => _snapshots ??= events
      .receiveBroadcastStream()
      .map((event) => event is Map ? event.cast<Object?, Object?>() : null);
  Stream<double> get angleStream => snapshots.expand((raw) {
        final values = raw?['angles'];
        // 与角度列表保持一致，任一折轴无效时不输出误导性的首轴值。
        if (values is! List ||
            !values
                .every((n) => n is num && n.isFinite && n >= 0 && n <= 180)) {
          return <double>[];
        }
        final first = values.isNotEmpty ? values.first : null;
        return first is num && first.isFinite && first >= 0 && first <= 180
            ? [first.toDouble()]
            : <double>[];
      });
}

/// OH 插件缺失时保持未知；窗口变化与恢复前台时重新查询，避免错过显示模式更新。
class OhosFoldableProvider extends StatefulWidget {
  const OhosFoldableProvider(
      {super.key, required this.child, required this.bridgeMode});
  final Widget child;
  final DisplayFeatureBridgeMode bridgeMode;
  @override
  State<OhosFoldableProvider> createState() => _OhosFoldableProviderState();
}

class _OhosFoldableProviderState extends State<OhosFoldableProvider>
    with WidgetsBindingObserver {
  Map<Object?, Object?>? _raw;
  StreamSubscription<Map<Object?, Object?>?>? _subscription;
  int _revision = 0;
  final _channel = OhosFoldableChannel.instance;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    final revision = _revision;
    final initial = await _channel.getSnapshot();
    if (!mounted) return;
    // 延迟返回的查询不能覆盖较新的窗口事件或恢复前台结果。
    if (revision == _revision) _apply(initial);
    if (initial != null) _listen();
  }

  void _listen() {
    // 恢复前台后插件可能才可用；确保恢复成功时也能接收后续事件。
    if (_subscription != null) return;
    _subscription = _channel.snapshots.listen(_apply, onError: (Object error) {
      debugPrint('ResponsiveFramework OHOS events: $error');
      _apply(null);
    });
  }

  void _apply(Map<Object?, Object?>? value) {
    if (mounted) {
      _revision++;
      setState(() => _raw = value);
    }
  }

  Future<void> _refresh() async {
    final revision = _revision;
    final value = await _channel.getSnapshot();
    if (revision == _revision) {
      _apply(value);
      if (mounted && value != null) _listen();
    }
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final data = OhosFoldableData.decode(
        _raw, media.size, View.of(context).devicePixelRatio);
    final engineHasFolds = media.displayFeatures.any((feature) =>
        feature.type == DisplayFeatureType.fold ||
        feature.type == DisplayFeatureType.hinge);
    final folds = engineHasFolds ? media.displayFeatures : data.features;
    final published =
        widget.bridgeMode == DisplayFeatureBridgeMode.full && !engineHasFolds
            ? [...media.displayFeatures, ...folds]
            : media.displayFeatures;
    // 始终保留同一层级的 MediaQuery，姿态和桥接模式变化不会卸载业务 State。
    return MediaQuery(
        data: media.copyWith(displayFeatures: published),
        child: OhosFoldableScope(
            data: OhosFoldableData(
                isFoldable: data.isFoldable,
                posture: data.posture,
                angles: data.angles,
                creases: data.creases,
                features: List.unmodifiable(engineHasFolds
                    ? folds
                    : [...media.displayFeatures, ...folds]),
                geometryValid: data.geometryValid),
            child: widget.child));
  }
}
