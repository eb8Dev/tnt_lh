import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Product imagery in one place, handling all three states properly.
///
/// The old call sites only fell back to an icon when the URL was null/empty —
/// a URL that *existed but 404'd* (the legacy Cloudinary links) threw and
/// rendered Flutter's broken-image error instead. This always lands on the
/// brand glyph, and fades the real photo in once it decodes.
///
/// Backed by [CachedNetworkImage]: `Image.network` keeps an in-memory cache
/// only, so every cold start re-downloaded the whole menu over the customer's
/// mobile data — on a photo-heavy grid that's the most expensive thing the app
/// does, and they pay for it.
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

  Widget _placeholder(BuildContext context) {
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
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback(context);

    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, _) => _placeholder(context),
      // A dead link must not surface a broken-image glyph to the customer.
      errorWidget: (context, _, _) => _fallback(context),
    );
  }
}

/// A remote icon (category tiles), cached and with a glyph fallback.
///
/// These were raw `Image.network` calls scattered across the home screens —
/// re-fetched on every cold start, and re-decoded on every scroll.
class RemoteIcon extends StatelessWidget {
  final String? url;
  final IconData fallback;
  final Color color;
  final double size;

  const RemoteIcon({
    super.key,
    required this.url,
    required this.fallback,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Icon(fallback, color: color, size: size);
    }

    return CachedNetworkImage(
      imageUrl: url!,
      color: color,
      placeholder: (context, _) => Icon(
        fallback,
        color: color.withValues(alpha: 0.35),
        size: size,
      ),
      errorWidget: (context, _, _) => Icon(fallback, color: color, size: size),
    );
  }
}
