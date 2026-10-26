// ignore_for_file: constant_identifier_names

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'breakpoint.dart';
import 'utils/responsive_utils.dart';

class ResponsiveBreakpoints extends StatefulWidget {
  final Widget child;
  final List<Breakpoint> breakpoints;

  /// A list of breakpoints that are active when the device is in landscape orientation.
  ///
  /// In Flutter, the returned device orientation is not the real device orientation,
  /// but is calculated based on the screen width and height.
  /// This means that landscape only makes sense on devices that support
  /// orientation changes. By default, landscape breakpoints are only
  /// active when the [ResponsiveTargetPlatform] is Android, iOS, or Fuchsia.
  /// To enable landscape breakpoints on other platforms, pass a custom
  /// list of supported platforms to [landscapePlatforms].
  final List<Breakpoint>? breakpointsLandscape;

  /// Override list of platforms to enable landscape mode on.
  /// By default, only mobile platforms support landscape mode.
  /// This override exists primarily to enable custom landscape vs portrait behavior
  /// and future compatibility with Fuschia.
  final List<ResponsiveTargetPlatform>? landscapePlatforms;

  /// Calculate responsiveness based on the shortest
  /// side of the screen, instead of the actual
  /// landscape orientation.
  ///
  /// This is useful for apps that want to avoid
  /// scrolling screens and distribute their content
  /// based on width/height regardless of orientation.
  /// Size units can remain the same when the phone
  /// is in landscape mode or portrait mode.
  /// The developer needs only change a few widgets'
  /// hard-coded size depending on the orientation.
  /// The rest of the widgets maintain their size but
  /// change the way they are displayed.
  ///
  /// `useShortestSide` can be used in conjunction with
  /// [breakpointsLandscape] for additional configurability.
  /// Landscape breakpoints will activate when the
  /// physical device is in landscape mode but base
  /// calculations on the shortest side instead of
  /// the actual landscape width.
  final bool useShortestSide;

  /// Print a visualization of the breakpoints.
  final bool debugLog;

  /// A wrapper widget that makes child widgets responsive.
  const ResponsiveBreakpoints({
    super.key,
    required this.child,
    required this.breakpoints,
    this.breakpointsLandscape,
    this.landscapePlatforms,
    this.useShortestSide = false,
    this.debugLog = false,
  });

  @override
  ResponsiveBreakpointsState createState() => ResponsiveBreakpointsState();

  static Widget builder({
    required Widget child,
    required List<Breakpoint> breakpoints,
    List<Breakpoint>? breakpointsLandscape,
    List<ResponsiveTargetPlatform>? landscapePlatforms,
    bool useShortestSide = false,
    bool debugLog = false,
  }) {
    return ResponsiveBreakpoints(
      breakpoints: breakpoints,
      breakpointsLandscape: breakpointsLandscape,
      landscapePlatforms: landscapePlatforms,
      useShortestSide: useShortestSide,
      debugLog: debugLog,
      child: child,
    );
  }

  static ResponsiveBreakpointsData of(BuildContext context) {
    final InheritedResponsiveBreakpoints? data = context
        .dependOnInheritedWidgetOfExactType<InheritedResponsiveBreakpoints>();
    if (data != null) return data.data;
    throw FlutterError.fromParts(
      <DiagnosticsNode>[
        ErrorSummary(
            'ResponsiveBreakpoints.of() called with a context that does not contain ResponsiveBreakpoints.'),
        ErrorDescription(
            'No Responsive ancestor could be found starting from the context that was passed '
            'to ResponsiveBreakpoints.of(). Place a ResponsiveBreakpoints at the root of the app '
            'or supply a ResponsiveBreakpoints.builder.'),
        context.describeElement('The context used was')
      ],
    );
  }
}

class ResponsiveBreakpointsState extends State<ResponsiveBreakpoints>
    with WidgetsBindingObserver {
  double windowWidth = 0;
  double getWindowWidth() {
    return MediaQuery.of(context).size.width;
  }

  double windowHeight = 0;
  double getWindowHeight() {
    return MediaQuery.of(context).size.height;
  }

  Breakpoint breakpoint = const Breakpoint(start: 0, end: 0);
  List<Breakpoint> breakpoints = [];

  /// Get screen width calculation.
  double screenWidth = 0;
  double getScreenWidth() {
    double widthCalc = useShortestSide
        ? (windowWidth < windowHeight ? windowWidth : windowHeight)
        : windowWidth;

    return widthCalc;
  }

  /// Get screen height calculations.
  double screenHeight = 0;
  double getScreenHeight() {
    double heightCalc = useShortestSide
        ? (windowWidth < windowHeight ? windowHeight : windowWidth)
        : windowHeight;

    return heightCalc;
  }

  Orientation get orientation => (windowWidth > windowHeight)
      ? Orientation.landscape
      : Orientation.portrait;

  static const List<ResponsiveTargetPlatform> _landscapePlatforms = [
    ResponsiveTargetPlatform.iOS,
    ResponsiveTargetPlatform.android,
    ResponsiveTargetPlatform.fuchsia,
    // 鸿蒙折叠屏同样按窗口形状选择横屏断点。
    ResponsiveTargetPlatform.ohos,
  ];

  ResponsiveTargetPlatform? platform;

  void setPlatform() {
    platform = kIsWeb
        ? ResponsiveTargetPlatform.web
        : Theme.of(context).platform.responsiveTargetPlatform;
  }

  bool get isLandscapePlatform =>
      (widget.landscapePlatforms ?? _landscapePlatforms).contains(platform);

  bool get isLandscape =>
      orientation == Orientation.landscape && isLandscapePlatform;

  bool get useShortestSide => widget.useShortestSide;

  /// Calculate updated dimensions.
  void setDimensions() {
    windowWidth = getWindowWidth();
    windowHeight = getWindowHeight();
    screenWidth = getScreenWidth();
    screenHeight = getScreenHeight();
    breakpoint = breakpoints.firstWhereOrNull((element) =>
            screenWidth >= element.start && screenWidth <= element.end) ??
        const Breakpoint(start: 0, end: 0);
  }

  /// Get enabled breakpoints based on [orientation] and [platform].
  List<Breakpoint> getActiveBreakpoints() {
    // If the device is landscape enabled and the current orientation is landscape, use landscape breakpoints.
    if (isLandscape) {
      return widget.breakpointsLandscape ?? widget.breakpoints;
    }
    return widget.breakpoints;
  }

  /// Set [breakpoints] and [breakpointSegments].
  void setBreakpoints() {
    // 窗口、平台或断点配置都可能单独变化，重新生成快照避免旧缓存。
    windowWidth = getWindowWidth();
    windowHeight = getWindowHeight();
    breakpoints = List<Breakpoint>.of(getActiveBreakpoints())
      ..sort(ResponsiveUtils.breakpointComparator);
  }

  @override
  void initState() {
    super.initState();
    // Log breakpoints to console.
    if (widget.debugLog) {
      // Add Portrait and Landscape annotations if landscape breakpoints are provided.
      if (widget.breakpointsLandscape != null) {
        debugPrint('**PORTRAIT**');
      }
      ResponsiveUtils.debugLogBreakpoints(widget.breakpoints);
      // Print landscape breakpoints.
      if (widget.breakpointsLandscape != null) {
        debugPrint('**LANDSCAPE**');
        ResponsiveUtils.debugLogBreakpoints(widget.breakpointsLandscape);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 在首帧与每次依赖变化时同步计算，局部 MediaQuery 更新也能立即生效。
    setPlatform();
    setBreakpoints();
    setDimensions();

    return InheritedResponsiveBreakpoints(
      data: ResponsiveBreakpointsData.fromWidgetState(this),
      child: widget.child,
    );
  }
}

// Device Type Constants.
const String MOBILE = 'MOBILE';
const String TABLET = 'TABLET';
const String PHONE = 'PHONE';
const String DESKTOP = 'DESKTOP';

/// Responsive data about the current screen.
///
/// Resized and scaled values can be accessed
/// such as [ResponsiveBreakpointsData.scaledWidth].
@immutable
class ResponsiveBreakpointsData {
  final double screenWidth;
  final double screenHeight;
  final Breakpoint breakpoint;
  final List<Breakpoint> breakpoints;
  final bool isMobile;
  final bool isPhone;
  final bool isTablet;
  final bool isDesktop;
  final Orientation orientation;

  /// Creates responsive data with explicit values.
  ///
  /// Alternatively, use [ResponsiveBreakpointsData.fromWidgetState]
  /// to create data based on the [ResponsiveBreakpoints] state.
  const ResponsiveBreakpointsData({
    this.screenWidth = 0,
    this.screenHeight = 0,
    this.breakpoint = const Breakpoint(start: 0, end: 0),
    this.breakpoints = const [],
    this.isMobile = false,
    this.isPhone = false,
    this.isTablet = false,
    this.isDesktop = false,
    this.orientation = Orientation.portrait,
  });

  /// Creates data based on the [ResponsiveBreakpoints] state.
  static ResponsiveBreakpointsData fromWidgetState(
      ResponsiveBreakpointsState state) {
    return ResponsiveBreakpointsData(
      screenWidth: state.screenWidth,
      screenHeight: state.screenHeight,
      breakpoint: state.breakpoint,
      // 使用不可变列表，避免后续刷新改变已发布的数据快照。
      breakpoints: List.unmodifiable(state.breakpoints),
      isMobile: state.breakpoint.name == MOBILE,
      isPhone: state.breakpoint.name == PHONE,
      isTablet: state.breakpoint.name == TABLET,
      isDesktop: state.breakpoint.name == DESKTOP,
      orientation: state.orientation,
    );
  }

  @override
  String toString() =>
      'ResponsiveBreakpoints(breakpoint: $breakpoint, breakpoints: ${breakpoints.asMap()}, isMobile: $isMobile, isPhone: $isPhone, isTablet: $isTablet, isDesktop: $isDesktop)';

  /// Returns if the active breakpoint is [name].
  bool equals(String name) => breakpoint.name == name;

  /// Is the [screenWidth] larger than [name]?
  /// Defaults to false if the [name] cannot be found.
  bool largerThan(String name) =>
      screenWidth >
      (breakpoints.firstWhereOrNull((element) => element.name == name)?.end ??
          double.infinity);

  /// Is the [screenWidth] larger than or equal to [name]?
  /// Defaults to false if the [name] cannot be found.
  bool largerOrEqualTo(String name) =>
      screenWidth >=
      (breakpoints.firstWhereOrNull((element) => element.name == name)?.start ??
          double.infinity);

  /// Is the [screenWidth] smaller than the [name]?
  /// Defaults to false if the [name] cannot be found.
  bool smallerThan(String name) =>
      screenWidth <
      (breakpoints.firstWhereOrNull((element) => element.name == name)?.start ??
          0);

  /// Is the [screenWidth] smaller than or equal to the [name]?
  /// Defaults to false if the [name] cannot be found.
  bool smallerOrEqualTo(String name) =>
      screenWidth <=
      (breakpoints.firstWhereOrNull((element) => element.name == name)?.end ??
          0);

  /// Is the [screenWidth] smaller than or equal to the [name]?
  /// Defaults to false if the [name] cannot be found.
  bool between(String name, String name1) {
    return (screenWidth >=
            (breakpoints
                    .firstWhereOrNull((element) => element.name == name)
                    ?.start ??
                0) &&
        screenWidth <=
            (breakpoints
                    .firstWhereOrNull((element) => element.name == name1)
                    ?.end ??
                0));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResponsiveBreakpointsData &&
          runtimeType == other.runtimeType &&
          screenWidth == other.screenWidth &&
          screenHeight == other.screenHeight &&
          breakpoint == other.breakpoint &&
          // 配置与方向影响消费者的条件判断，必须参与更新通知。
          orientation == other.orientation &&
          listEquals(breakpoints, other.breakpoints) &&
          isMobile == other.isMobile &&
          isPhone == other.isPhone &&
          isTablet == other.isTablet &&
          isDesktop == other.isDesktop;

  @override
  int get hashCode =>
      // 哈希与相等判断保持一致，支持作为响应式快照的集合键。
      Object.hash(screenWidth, screenHeight, breakpoint, orientation,
          Object.hashAll(breakpoints), isMobile, isPhone, isTablet, isDesktop);
}

/// Creates an immutable widget that exposes [ResponsiveBreakpointsData]
/// to child widgets.
///
/// Querying this widget with [ResponsiveBreakpoints.of]
/// creates a dependency that causes an automatic
/// rebuild whenever the [ResponsiveBreakpointsData]
/// changes.
///
/// If no [ResponsiveBreakpoints] is in scope then the
/// [MediaQuery.of] method will throw an exception,
/// unless the `nullOk` argument is set to true, in
/// which case it returns null.
@immutable
class InheritedResponsiveBreakpoints extends InheritedWidget {
  final ResponsiveBreakpointsData data;

  /// Creates a widget that provides [ResponsiveBreakpointsData] to its descendants.
  ///
  /// The [data] and [child] arguments must not be null.
  const InheritedResponsiveBreakpoints(
      {super.key, required this.data, required super.child});

  @override
  bool updateShouldNotify(InheritedResponsiveBreakpoints oldWidget) =>
      data != oldWidget.data;
}
