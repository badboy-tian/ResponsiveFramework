library responsive_framework;

export 'src/breakpoint.dart';
// 统一暴露折叠屏接入和区域布局，调用者无需导入内部实现。
export 'src/responsive_foldable.dart';
export 'src/responsive_two_pane.dart';
// 桥接模式属于公共配置，使用方不必另行导入插件的内部模型。
export 'package:foldable/foldable.dart' show DisplayFeatureBridgeMode;
export 'src/max_width_box.dart';
export 'src/responsive_breakpoints.dart';
export 'src/responsive_grid.dart';
export 'src/responsive_row_column.dart';
export 'src/responsive_scaled_box.dart';
export 'src/responsive_value.dart';
export 'src/utils/responsive_utils.dart';
export 'src/utils/scroll_behavior.dart';
