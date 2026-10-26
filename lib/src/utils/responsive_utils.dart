import 'package:flutter/foundation.dart';

import '../breakpoint.dart';

/// Util functions for the Responsive Framework.
class ResponsiveUtils {
  /// Comparator function to order [Breakpoint]s from small to large by start sections.
  static int breakpointComparator(Breakpoint a, Breakpoint b) {
    return a.start.compareTo(b.start);
  }

  /// Print a visual view of [breakpoints]
  /// for debugging purposes.
  static String debugLogBreakpoints(List<Breakpoint>? breakpoints) {
    if (breakpoints == null || breakpoints.isEmpty) return '| Empty |';
    List<Breakpoint> breakpointsHolder = List.from(breakpoints);
    breakpointsHolder.sort(breakpointComparator);

    var stringBuffer = StringBuffer();
    stringBuffer.write('| ');
    for (int i = 0; i < breakpointsHolder.length; i++) {
      // Convenience variable.
      Breakpoint breakpoint = breakpointsHolder[i];
      stringBuffer.write(breakpoint.start);
      stringBuffer.write(' ----- ');
      List<dynamic> attributes = [];
      String? name = breakpoint.name;
      if (name != null) attributes.add(name);
      if (attributes.isNotEmpty) {
        stringBuffer.write('(');
        for (int i = 0; i < attributes.length; i++) {
          stringBuffer.write(attributes[i]);
          if (i != attributes.length - 1) stringBuffer.write(',');
        }
        stringBuffer.write(')');
        stringBuffer.write(' ----- ');
      }
      if (breakpoint.end == double.infinity) {
        stringBuffer.write('∞');
      } else {
        stringBuffer.write(breakpoint.end);
      }
      if (i != breakpoints.length - 1) {
        stringBuffer.write(' ----- ');
      }
    }
    stringBuffer.write(' |');
    debugPrint(stringBuffer.toString());
    return stringBuffer.toString();
  }
}

/// A superset of [TargetPlatform] that includes [web] as an enum option.
/// Flutter's TargetPlatform does not include web as a platform option.
enum ResponsiveTargetPlatform {
  android,
  fuchsia,
  iOS,
  linux,
  macOS,
  windows,
  web,
  // OH 分支增加了平台枚举；未来未知平台保持显式未知，避免误判为手机。
  ohos,
  unknown,
}

/// A helper extension to convert [TargetPlatform] to [ResponsiveTargetPlatform].
extension TargetPlatformExtension on TargetPlatform {
  // 按稳定名称映射，避免直接引用 TargetPlatform.ohos 导致标准 SDK 编译失败。
  ResponsiveTargetPlatform get responsiveTargetPlatform =>
      ResponsiveTargetPlatform.values.firstWhere(
        (platform) => platform.name == name,
        orElse: () => ResponsiveTargetPlatform.unknown,
      );
}
