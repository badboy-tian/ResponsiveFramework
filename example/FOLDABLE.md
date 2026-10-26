# Android / iOS 折叠屏示例

<!-- 固定本地依赖和可复现命令，确保示例运行的是本次实现。 -->
默认入口 `lib/main.dart` 展示笔记列表和详情，原有博客入口为 `/list`。
折叠图标可选择跟随设备、左右折叠、上下折叠、完全展开。预览不需要折叠设备；
“跟随设备”读取 Android 引擎或 iOS 插件的实际数据。

```sh
flutter pub get
flutter run -d <device-id>
```

<!-- 分开说明库最低版本与示例已升级的宿主工具链，避免误用旧环境。 -->
库声明 Flutter ≥3.24、Dart ≥3.5；本示例宿主要求 Flutter ≥3.47，以支持 AGP 9 的内置 Kotlin。
Android 宿主使用 Java 17、AGP 9.0.1、Gradle 9.1。
iOS 最低部署版本为 15.0，Duo 的保留区域需要 Xcode 27.1 / iOS 27.1 SDK。
普通 iPhone 仍可运行，缺少折叠 API 时自动使用普通响应式布局。

```sh
flutter test
flutter analyze
flutter build apk --debug
flutter build ios --simulator --debug
```

<!-- 本地状态是跨布局的共同来源，折叠切换不等价于重新进入页面。 -->
点击笔记进入详情，编辑后切换折叠模式或内外屏，输入和选中项保留。
详情按钮弹出的对话框使用触发按钮的全局 anchorPoint。
<!-- 示例实际使用公共接口，避免文档中的扩展点缺少集成验证。 -->
返回按钮使用 `ResponsiveTwoPane.of(context).isDual` 判断是否显示；
浮层定位通过 `ResponsiveTwoPane.anchorPointFor(context)` 完成。
姿态、角度与未桥接区域可通过根 README 的 `ResponsiveFoldable` 查询接口读取。
笔记只保存在本次进程内存中，重启应用后恢复示例内容。
