![Screenshots](packages/Responsive%20Cover.png)
# Responsive Framework

<!-- 在文档入口提供语言切换，方便中文使用者找到同步维护的说明。 -->
[English](README.md) | [简体中文](README_cn.md)

[![Flutter Responsive](https://img.shields.io/badge/flutter-responsive-brightgreen.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework) [![Pub release](https://img.shields.io/pub/v/responsive_framework.svg?style=flat-square)](https://pub.dev/packages/responsive_framework) [![GitHub Release Date](https://img.shields.io/github/release-date/Codelessly/ResponsiveFramework.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework) [![GitHub issues](https://img.shields.io/github/issues/Codelessly/ResponsiveFramework.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework/issues) [![GitHub top language](https://img.shields.io/github/languages/top/Codelessly/ResponsiveFramework.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework) [![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/Codelessly/ResponsiveFramework.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework) [![Awesome Flutter](https://img.shields.io/badge/Awesome-Flutter-blue.svg?longCache=true&style=flat-square)](https://github.com/Solido/awesome-flutter) [![Libraries.io for GitHub](https://img.shields.io/librariesio/github/Codelessly/ResponsiveFramework.svg?style=flat-square)](https://libraries.io/github/Codelessly/ResponsiveFramework) [![License](https://img.shields.io/badge/License-MIT-orange.svg?style=flat-square)](LICENSE)

![Screenshots](packages/Responsive%20Demo.gif)

> ### Responsiveness made simple

The Responsive Framework includes widgets that help developers build responsive apps for mobile, desktop, and website layouts.

## Demo

### [Minimal Website](https://gallery.codelessly.com/flutterwebsites/minimal/?utm_medium=link&utm_campaign=demo)

A demo website built with the Responsive Framework. [View Code](https://github.com/Codelessly/FlutterMinimalWebsite)

### [Flutter Website](https://gallery.codelessly.com/flutterwebsites/flutterwebsite/?utm_medium=link&utm_campaign=demo)

The flutter.dev website recreated in Flutter. [View Code](https://github.com/Codelessly/FlutterWebsite)

### [Pub.dev Website](https://gallery.codelessly.com/flutterwebsites/pub/?utm_medium=link&utm_campaign=demo)

The pub.dev website recreated in Flutter. [View Code](https://github.com/Codelessly/FlutterPubWebsite)

## Quick Start

<!-- 折叠屏接入必须使用当前窗口，明确入口位置可避免坐标和插件依赖错误。 -->
### Android foldables and iPhone Duo

Version 1.6 requires Flutter 3.24+, Dart 3.5+, and iOS 15+ for the iOS plugin.
Build with the iOS 27.1 SDK to receive iPhone Duo reserved regions.
Android uses Flutter's engine-provided `MediaQuery.displayFeatures`.
iOS uses [foldable](https://github.com/berkaycatak/foldable).

```dart
MaterialApp(
  builder: (context, child) => ResponsiveFoldable(child: child!),
  home: ResponsiveTwoPane(
    primary: ListScreen(),
    secondary: DetailScreen(),
  ),
)
```

`ResponsiveTwoPane` follows active vertical/horizontal folds and physical hinge
gaps. Without a separating feature, it uses two columns at 840 logical pixels
and above (600 on OHOS). Configure `breakpoint`, `spacing`, and `primaryFraction` for your
content. Set `showSecondary: true` to display details in compact windows.
Both panes retain their State while switching, and receive local MediaQuery
sizes, insets, and display-feature coordinates. Use SafeArea inside each pane.

<!-- 接口围绕业务实际需要组织，明确未知值，避免按机型或假角度决定布局。 -->
#### Read fold state and geometry

Place `ResponsiveFoldable` at the window origin in `MaterialApp.builder`.
The following methods work below it, including inside either pane:

| API | Result and intended use |
| --- | --- |
| `ResponsiveFoldable.postureOf(context)` | `ResponsiveFoldPosture.unknown`, `.closed`, `.halfOpened`, or `.flat`. Use posture for fold-specific behavior; use constraints to choose general layouts. |
| `ResponsiveFoldable.isFoldableOf(context)` | `bool?`: `true` for a detected hinge, `false` only when native APIs explicitly report no hinge, `null` when unknown. An empty Android feature list does not prove the device is a normal phone. |
| `ResponsiveFoldable.angleOf(context)` | Latest iOS/OHOS first-hinge angle in degrees, or `null` when unavailable. Angles are not synthesized from posture. |
| `ResponsiveFoldable.anglesOf(context)` | Read-only angles in platform hinge order. OHOS can supply multiple hinges; iOS supplies at most one. Unknown data returns an empty list. |
| `ResponsiveFoldable.hingeAngleStream` | iOS/OHOS first-hinge angle stream for effects confined to a small widget. Other platforms return an empty stream. Cancel imperative subscriptions when disposing. |
| `ResponsiveFoldable.displayFeaturesOf(context)` | Active window-level folds and camera regions, including iOS regions when `bridgeMode` is `.none`. |

iOS posture/region readers subscribe to those aspects, so angle-only changes do
not rebuild them. Android window features remain available after a pane's local
MediaQuery removes its separating fold. Without a provider, engine queries fall
back to the current MediaQuery; unknown capability remains `null`.

Window-level features use the coordinate system at the `ResponsiveFoldable`
entry. Inside a pane, use `MediaQuery.of(context).displayFeatures` for **local**
coordinates. Never pass window rectangles into a translated/scaled subtree
without converting them.

<!-- 区域读取与浮层桥接独立，业务可以适配双栏而保留系统浮层的原有行为。 -->
On iOS, to adapt your page without globally splitting Material dialogs and sheets:

```dart
MaterialApp(
  builder: (context, child) => ResponsiveFoldable(
    bridgeMode: DisplayFeatureBridgeMode.none,
    child: child!,
  ),
  home: Builder(builder: (context) {
    return ResponsiveTwoPane(
      displayFeatures: ResponsiveFoldable.displayFeaturesOf(context),
      minPrimarySize: const Size(240, 200),
      minSecondarySize: const Size(360, 240),
      primary: ListScreen(),
      secondary: DetailScreen(),
    );
  }),
)
```

#### Control layout policy

| Property | Default | Behavior |
| --- | --- | --- |
| `mode` | `ResponsiveTwoPaneMode.auto` | `auto` follows divisions or the width breakpoint; `single` shows one pane; `dual` requests two panes without requiring the width breakpoint. |
| `breakpoint` | `null` → `ResponsiveTwoPane.defaultBreakpoint` | Width threshold in logical pixels for ordinary wide-screen columns. Defaults to 840 (Material expanded) and 600 on OHOS, where `Navigation` splits from 600vp and Mate X inner displays are about 711vp wide. |
| `minPrimarySize`, `minSecondarySize` | `Size.zero`, `Size.zero` | Independent minimum outer sizes for the two panes. If either candidate is too small, fall back to one visible pane, even in `dual` mode. |
| `primaryFraction` | `0.4` | Primary share of the width after spacing on ordinary wide screens. Physical folds determine their own split. |
| `spacing` | `24` | Gap between ordinary columns; physical hinge bounds determine the actual fold gap. |
| `showSecondary` | `false` | Selects the secondary pane when only one is visible. |
| `displayFeatures` | `null` | Optional features in this layout's coordinates, for custom integration, tests, or previews. An explicit empty list disables fold divisions. |

Physical hinge avoidance always wins: `single` and minimum-size fallbacks never
expand across a hinge. On a divided screen, the selected pane stays in its own
region. Hidden panes retain State, but are offstage, excluded from focus and
semantics, and have tickers disabled. Their subscriptions and business work
remain the responsibility of the owning widget.

<!-- 消费真实布局结果，而不是再次按屏宽猜测，可以覆盖半折叠与最小尺寸回退。 -->
#### Read the resolved layout and place overlays

Inside `primary` or `secondary`, `ResponsiveTwoPane.of(context)` returns an
immutable `ResponsiveTwoPaneLayout`. `maybeOf(context)` returns `null` outside
a pane layout; `of` throws a descriptive error.

The snapshot exposes `isDual`, `axis` (`null` for single-pane layouts),
`isPrimaryVisible`, `isSecondaryVisible`, `primaryBounds`, `secondaryBounds`,
`hasDisplayFeatureDivision`, and read-only `availableRegions`. The bounds are
relative to the TwoPane origin. Available regions describe the physical
partition before ordinary columns/spacing; the component renders at most two
panes even if more regions exist.

For example, hide the compact-navigation Back button when both panes are visible:

```dart
Builder(builder: (context) {
  final layout = ResponsiveTwoPane.of(context);
  return layout.isDual ? const SizedBox.shrink() : BackButton(onPressed: onBack);
})
```

Use a context belonging to the triggering control for dialog/sheet placement:

```dart
Builder(builder: (buttonContext) => IconButton(
  icon: const Icon(Icons.info_outline),
  onPressed: () => showDialog<void>(
    context: buttonContext,
    anchorPoint: ResponsiveTwoPane.anchorPointFor(buttonContext),
    builder: (context) => const AlertDialog(title: Text('Details')),
  ),
))
```

Call `anchorPointFor` after layout, normally from a control callback. It converts
the control center to window coordinates; pane-local rectangle centers cannot
be passed to a root Navigator directly. For a custom nested Navigator, convert
to that Navigator's coordinate system instead.

As with Flutter's DisplayFeatureSubScreen, put the layout at the origin of its
MediaQuery. If placing it inside an offset container, pass `displayFeatures`
converted to that container's local coordinates. Width and height must be bounded.

Bridging is enabled by explicitly adding `ResponsiveFoldable`. The default
`DisplayFeatureBridgeMode.full` also constrains dialogs and bottom sheets to a
sub-screen: pass an `anchorPoint` based on the triggering control. Choose
`DisplayFeatureBridgeMode.cutoutsOnly` or `.none` to limit this behavior.
Do not nest bridge providers or use a second copy of the same fold features.
`bridgeMode` configures iOS and OHOS. Android always preserves engine-provided display
features, including Flutter's existing dialog/sub-screen behavior.

```sh
cd example
flutter pub get
flutter run
```

The example references this checkout with `path: ../`. Its default screen uses
local notes and includes device, book, tabletop, and flat previews. The original
blog remains available at `/list`. See
[example run instructions](example/FOLDABLE.md) for platform requirements.
The core declares Flutter 3.24+; the example host requires Flutter 3.47+ for its
AGP 9 built-in Kotlin toolchain. Minimum-SDK compatibility has not been separately
tested on Flutter 3.24.

<!-- Flutter 示例与 OHOS 原生宿主按插件标准结构共存于 example/。 -->
### HarmonyOS / OHOS (1.7.0+)

`ResponsiveMultiPane` lays out children across reported separating folds. With
no separator it displays `singlePaneIndex` and keeps other children offstage.
`ResponsiveFoldable.creaseBoundsOf(context)` exposes validated OHOS crease
rectangles, including flat ones, without treating them as occlusions. To split
flat folds explicitly, provide `DisplayFeature`s and set `splitFlatFolds: true`.
An empty list means no usable data, not proof that a device has no hinges.
The example includes a three-pane orientation preview using simulated folds;
it does not verify the native device sensor or crease geometry.

The `ohos/` ArkTS plugin is registered automatically by Flutter OH. Existing
`ResponsiveFoldable` / `ResponsiveTwoPane` calls work without a separate UI API.
Use an **OH-enabled Flutter SDK**, not the standard SDK, for the HarmonyOS host:

```sh
cd example
/path/to/flutter-ohos/bin/flutter pub get
/path/to/flutter-ohos/bin/flutter test
/path/to/flutter-ohos/bin/flutter build hap --debug --no-codesign
```

The unified example was validated with Flutter OH 3.35.8 and the installed
DevEco SDK (API 26); native APIs require API 12+. Its native host is
`example/ohos/`, and it supports fold state,
physical crease rectangles, display/window changes, and multi-hinge angles.
`full` publishes crease geometry into MediaQuery; `none` / `cutoutsOnly` preserve
engine data and expose plugin geometry through `displayFeaturesOf`.

Native rectangles are screen pixels: the bridge subtracts the drawable-window
origin and divides by the actual FlutterView DPR. Mismatched display IDs or
viewport sizes suppress crease geometry while retaining posture/capability.
An embedded FlutterView with a different origin/size requires host integration;
the bridge never invents a centered fold. Angles stay unknown until a real
sensor event. Physical regions are retained, but TwoPane still renders at most
two panes. Complex tri-fold per-hinge activation requires device validation.

The unsigned HAP compiles; it has **not** been run on a HarmonyOS foldable.
Signing/installing and testing inner/outer displays, rotation, floating windows,
and firmware-specific crease coordinates remain separate acceptance steps.
See [OHOS implementation and build notes](docs/ohos-support.md).

[![Pub release](https://img.shields.io/pub/v/responsive_framework.svg?style=flat-square)](https://pub.dev/packages/responsive_framework)

Import this library into your project:

```yaml
responsive_framework: ^latest_version
```

Add `ResponsiveBreakpoints.builder` to your MaterialApp or CupertinoApp. Define your own breakpoints and labels.
```dart
import 'package:responsive_framework/responsive_framework.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      initialRoute: "/",
    );
  }
}
```

Use the labels you defined for layouts and values.

```dart
// Example: if the screen is bigger than the Mobile breakpoint, build full width AppBar icons and labels.
if (ResponsiveBreakpoints.of(context).largerThan(MOBILE))
    FullWidthAppBarItems()

// Booleans
ResponsiveBreakpoints.of(context).isDesktop;
ResponsiveBreakpoints.of(context).isTablet;
ResponsiveBreakpoints.of(context).isMobile;
ResponsiveBreakpoints.of(context).isPhone;

// Conditionals
ResponsiveBreakpoints.of(context).equals(DESKTOP)
ResponsiveBreakpoints.of(context).largerThan(MOBILE)
ResponsiveBreakpoints.of(context).smallerThan(TABLET)
ResponsiveBreakpoints.of(context).between(MOBILE, TABLET)
...
```

### Customization
You can define your own breakpoint labels and use them in your conditionals.

For example, if you're building a Material 3 Navigation Rail and want to expand the menu to full width once there is enough room, you can add a custom `EXPAND_SIDE_PANEL` breakpoint.

```dart
breakpoints: [
  ...
  const Breakpoint(start: 801, end: 1920, name: DESKTOP),
  const Breakpoint(start: 900, end: 900, name: 'EXPAND_SIDE_PANEL') <- Custom label.
  const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
  ...
]
```

Then, in your code, show the Rail based on the breakpoint condition.

> expand: ResponsiveBreakpoints.of(context).largerThan('EXPAND_SIDE_PANEL')

### Responsive Framework Widgets
The ResponsiveFramework includes a few custom widgets that supplement Flutter's responsive capabilities. Their usages are showcased in the demo projects.

- *[ResponsiveValue](https://github.com/Codelessly/ResponsiveFramework/blob/master/lib/src/responsive_value.dart)*
  - *[ResponsiveVisibility](https://github.com/Codelessly/ResponsiveFramework/blob/master/lib/src/responsive_value.dart)*
  - *[ResponsiveConstraints](https://github.com/Codelessly/ResponsiveFramework/blob/master/lib/src/responsive_value.dart)*
- *[ResponsiveRowColumn](https://github.com/Codelessly/ResponsiveFramework/blob/master/lib/src/responsive_row_column.dart)*
- *[ResponsiveGridView](https://github.com/Codelessly/ResponsiveFramework/blob/master/lib/src/responsive_grid.dart)*
- *[ResponsiveScaledBox](https://github.com/Codelessly/ResponsiveFramework/blob/master/lib/src/responsive_scaled_box.dart)*
- *[MaxWidthBox](https://github.com/Codelessly/ResponsiveFramework/blob/master/lib/src/max_width_box.dart)*


## Legacy ReadMe (v0.2.0 and below)

### ResponsiveWrapper Migration
[v1.0.0 Migration Guide](https://github.com/Codelessly/ResponsiveFramework/blob/master/migration_0.2.0_to_1.0.0.md)

### The remainder of the legacy ReadMe is preserved below as the concepts are still useful and used by the new widgets. ResponsiveWrapper has been deprecated and removed.

### The Problem
Supporting multiple display sizes often means recreating the same layout multiple times. Under the traditional _Bootstrap_ approach, building responsive UI is time consuming, frustrating and repetitive. Furthermore, getting everything pixel perfect is near impossible and simple edits take hours.

![Screenshots](packages/Bad%20Viewport%20Selector%20Animated.gif)

### The Solution
Use Responsive Framework to automatically scale your UI.

> **ResponsiveBreakpoint.autoScale(600);**


## AutoScale

![Screenshots](packages/Scale%20Resize%20Comparison.gif)

AutoScale shrinks and expands your layout *proportionally*, preserving the exact look of your UI.
This eliminates the need to manually adapt layouts to mobile, tablet, and desktop.

```dart
ResponsiveBreakpoint.autoScale(600);
```

Flutter's default behavior is resize which Responsive Framework respects. AutoScale is off by default and can be enabled at breakpoints by setting `autoScale` to `true`.

## Breakpoints

![Screenshots](packages/Device%20Preview.gif)

Breakpoints control responsive behavior at different screen sizes.

```dart
ResponsiveWrapper(
    child,
    breakpoints: [
        ResponsiveBreakpoint.resize(600, name: MOBILE),
        ResponsiveBreakpoint.autoScale(800, name: TABLET),
        ResponsiveBreakpoint.autoScale(1200, name: DESKTOP),
    ],
)
```
Breakpoints give you fine-grained control over how your UI displays.

## Introductory Concepts

These concepts helps you start using the Responsive Framework and build an responsive app quickly.

### Scale vs Resize

Flutter's default behavior is to resize your layout when the screen dimensions change. Resizing a layout stretches it in the direction of an unconstrained width or height. Any constrained dimension stays fixed which is why mobile app UIs look tiny on desktop. The following example illustrates the difference between resizing and scaling.

![Screenshots](packages/AppBar%20Scale%20vs%20Resize%20Comparison.png)

An AppBar widget looks correct on a phone. When viewed on a desktop however, the AppBar is too short and the title looks too small.
Here is what happens under each behavior: 
1. Resizing (default) - the AppBar's width is double.infinity so it stretches to fill the available width. The Toolbar height is fixed and stays 56dp.
2. Scaling - the AppBar's width stretches to fill the available width. The height scales proportionally using an aspect ratio automatically calculated from the nearest `ResponsiveBreakpoint`. As the width increases, the height increases proportionally.

When scaled, the AppBar looks correct on desktop, up to a certain size. Once the screen becomes too wide, the AppBar starts to appear too large. This is where breakpoints come in.

### Breakpoint Configuration

To adapt to a wide variety of screen sizes, set breakpoints to control responsive behavior.

```dart
ResponsiveWrapper(
    child,
    maxWidth: 1200,
    minWidth: 480,
    defaultScale: true,
    breakpoints: [
        ResponsiveBreakpoint.resize(480, name: MOBILE),
        ResponsiveBreakpoint.autoScale(800, name: TABLET),
        ResponsiveBreakpoint.resize(1000, name: DESKTOP),
        ResponsiveBreakpoint.autoScale(2460, name: '4K'),
    ],
)
```

An arbitrary number of breakpoints can be set. Resizing/scaling behavior can be mixed and matched.
- below 480: resize on small screens to avoid cramp and overflow errors.
- 480-800: resize on phones for native widget sizes.
- 800-1000: scale on tablets to avoid elements appearing too small.
- 1000+: resize on desktops to use available space. 
- 2460+: scale on extra large 4K displays so text is still legible and widgets are not spaced too far apart.

## Additional Resources

### Resocoder Tutorial

The wonderful people at Resocoder created a great tutorial video and article walking through the usage of the Responsive Framework at the link below.

[View Responsive Framework Tutorial](https://resocoder.com/2021/10/03/create-responsive-flutter-apps-with-minimal-effort/)

### Project Wiki

No project wiki exists yet unfortunately. That means this is an opportunity for you to create and maintain the wiki for one of the most popular Flutter packages. This package needs **your** help with documentation!

Please reach out via the contact links below if you are interested.

## About

Responsive Framework was created out of a desire for a better way to manage responsiveness. The ability to automatically adapt UI to different sizes opens up a world of possibilities. Here at Codelessly, we're building a Flutter app UI and website builder, development tools, and UI templates to increase productivity. If that sounds interesting, you'll want to subscribe to updates below 😎

Responsive Framework is licensed under MIT and released as Emailware. If you like this project or it helped you, please subscribe to updates. Although it is not required, you might miss the goodies we share!

<a href="https://codelessly.com/?utm_medium=banner&utm_campaign=newsletter_subscribe" target="_blank"><img src="https://raw.githubusercontent.com/Codelessly/ResponsiveFramework/master/packages/Email%20Newsletter%20Signup.png"></a>

## Badges 🏆

Now you can proudly display the time and headache saved by using Responsive Framework with a supporter's badge.

[![Pub release](https://img.shields.io/badge/flutter-responsive-brightgreen.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework) 

```
[![Flutter Responsive](https://img.shields.io/badge/flutter-responsive-brightgreen.svg?style=flat-square)](https://github.com/Codelessly/ResponsiveFramework)
```
<img alt="Built Responsive" src="https://raw.githubusercontent.com/Codelessly/ResponsiveFramework/master/packages/Built%20Responsive%20Badge.png"/>

```html
<a href="https://github.com/Codelessly/ResponsiveFramework">
  <img alt="Built Responsive"
       src="https://raw.githubusercontent.com/Codelessly/ResponsiveFramework/master/packages/Built%20Responsive%20Badge.png"/>
</a>
```
<img alt="Built with Responsive Framework" src="https://raw.githubusercontent.com/Codelessly/ResponsiveFramework/master/packages/Built%20with%20Responsive%20Badge.png"/>

```html
<a href="https://github.com/Codelessly/ResponsiveFramework">
  <img alt="Built with Responsive Framework"
       src="https://raw.githubusercontent.com/Codelessly/ResponsiveFramework/master/packages/Built%20with%20Responsive%20Badge.png"/>
</a>
```

## Contributors ❤️

**Design:** 
* [Ray Li](https://github.com/searchy2)

**Development:** 
* [Ray Li](https://github.com/searchy2)
* [Spencer Lindemuth](https://github.com/SpencerLindemuth)
* [Trefa1998](https://github.com/Trefa1998)
* *add yourself here by contributing*

**Sponsor:** [Codelessly - Flutter App UI and Website Builder](https://codelessly.com/?utm_medium=link&utm_campaign=direct)

<a href="mailto:ray@codelessly.com">
  <img alt="Codelessly Email"
       src="https://lh3.googleusercontent.com/yN_m90WN_HSCohXdgC2k91uSTk9dnYfoxTYwG_mv_l5_05dV2CzkQ1B6rEqH4uqdgjA=w96" />
</a>
<a href="https://codelessly.com/?utm_medium=icon&utm_campaign=direct">
  <img alt="Codelessly Website"
       src="https://lh3.googleusercontent.com/YmMGcgeO7Km9-J9vFRByov5sb7OUKetnKs8pTi0JZMDj3GVJ61GMTcTlHB7u9uHDHag=w96" />
</a>
<a href="https://twitter.com/BuildCodelessly">
  <img alt="Codelessly Twitter"
       src="https://lh3.ggpht.com/lSLM0xhCA1RZOwaQcjhlwmsvaIQYaP3c5qbDKCgLALhydrgExnaSKZdGa8S3YtRuVA=w96" />
</a>
<a href="https://github.com/Codelessly">
  <img alt="Codelessly GitHub"
       src="https://lh3.googleusercontent.com/L15QqmKK7Vl-Ag1ZxaBqNQlXVEw58JT2BDb-ef5t2eboDh0pPSLjDgi3-aQ3Opdhhyk=w96" />
</a>
<br></br>

Flutter is a game-changing technology that will revolutionize not just development, but software itself. A big thank you to the Flutter team for building such an amazing platform 💙 

<a href="https://github.com/flutter/flutter">
  <img alt="Flutter"
       src="https://raw.githubusercontent.com/Codelessly/ResponsiveFramework/master/packages/Flutter%20Logo%20Banner.png" />
</a>
 
## License

<!-- 以仓库 LICENSE 为准，修正旧文档残留的 BSD 标注，避免许可信息不一致。 -->
Released under the [MIT License](LICENSE). Copyright © 2024 Codelessly.
