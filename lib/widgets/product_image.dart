import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Product imagery in one place, handling all three states properly.
///
/// The old call sites only fell back to an icon when the URL was null/empty —
/// a URL that *existed but 404'd* (the legacy Cloudinary links) threw and
/// rendered Flutter's broken-image error instead. This always lands on the
/// brand glyph, and fades the real photo in once it decodes.
class ProductImage extends StatelessWidget {
  final String? url;
  final bool isLittleH;
  final double iconSize;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.url,
    required this.isLittleH,
    this.iconSize = 40,
    this.fit = BoxFit.cover,
  });

  Widget _fallback(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: PhosphorIcon(
        isLittleH
            ? PhosphorIcons.cake(PhosphorIconsStyle.duotone)
            : PhosphorIcons.coffee(PhosphorIconsStyle.duotone),
        size: iconSize.sp,
        color: Colors.black.withValues(alpha: 0.18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback(context);

    return Image.network(
      url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      // A dead link must not surface a broken-image glyph to the customer.
      errorBuilder: (context, _, _) => _fallback(context),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: SizedBox(
            width: 18.sp,
            height: 18.sp,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ),
        );
      },
    );
  }
}
