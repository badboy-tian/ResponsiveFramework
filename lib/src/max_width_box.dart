import 'package:flutter/material.dart';

import 'utils/region_media_query.dart';

class MaxWidthBox extends StatelessWidget {
  final double? maxWidth;
  final Widget child;

  /// Control child alignment.
  /// Defaults to [Alignment.topCenter] because app
  /// content is usually top aligned.
  final AlignmentGeometry alignment;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const MaxWidthBox(
      {super.key,
      required this.maxWidth,
      required this.child,
      this.alignment = Alignment.topCenter,
      this.padding,
      this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: Container(
          color: backgroundColor,
          padding: padding,
          child: LayoutBuilder(builder: (context, constraints) {
            // 居中和内边距会改变区域原点，必须裁剪并平移折痕，而非只改 size。
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : media.size.width;
            final height = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : media.size.height;
            final insets = padding ?? EdgeInsets.zero;
            final resolved = alignment.resolve(Directionality.of(context));
            final offset = resolved.alongOffset(Offset(
                  (media.size.width - width - insets.horizontal)
                      .clamp(0.0, double.infinity),
                  (media.size.height - height - insets.vertical)
                      .clamp(0.0, double.infinity),
                )) +
                Offset(insets.left, insets.top);
            final rect = (offset & Size(width, height))
                .intersect(Offset.zero & media.size);
            return MediaQuery(
              data: mediaQueryForRegion(media, rect),
              child: child,
            );
          }),
        ),
      ),
    );
  }
}
