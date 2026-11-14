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

    // DECODE AT THE SIZE WE ACTUALLY DRAW.
    //
    // Uploads are stored at up to 1920x1920 (sharp resizes to that). Flutter
    // decodes to a raw ARGB bitmap, so ONE product photo held ~1920*1920*4 =
    // **15 MB of RAM** — no matter that we paint it into a 180px grid tile.
    // A grid of a dozen products blows straight through Flutter's 100 MB image
    // cache and takes a 2 GB phone with it. Nothing anywhere constrained this.
    //
    // memCacheWidth makes the codec downscale during decode, so the bitmap in
    // memory is the size of the tile, not the size of the file. A 180px tile at
    // 3x is ~540px => ~1.2 MB. Roughly a 12x saving, invisible on screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final logicalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final decodeWidth = (logicalWidth * dpr).round().clamp(64, 1080);

        return CachedNetworkImage(
          imageUrl: url!,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: decodeWidth,
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (context, _) => _placeholder(context),
          // A dead link must not surface a broken-image glyph to the customer.
          errorWidget: (context, _, _) => _fallback(context),
        );
      },
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

    // Same decode cap as ProductImage, but these are tiny — a category tile is
    // ~30px, so decoding a 1920px source into RAM for it was pure waste.
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return CachedNetworkImage(
      imageUrl: url!,
      color: color,
      memCacheWidth: (size * 2 * dpr).round().clamp(48, 256),
      placeholder: (context, _) =>
          Icon(fallback, color: color.withValues(alpha: 0.35), size: size),
      errorWidget: (context, _, _) => Icon(fallback, color: color, size: size),
    );
  }
}
