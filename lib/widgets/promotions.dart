import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/models/promotion_model.dart';
import 'package:tnt_lh/providers/promotion_provider.dart';
import 'package:tnt_lh/screens/cafe/cafe_item_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Everything the store is promoting, at the top of its menu: an announcement
/// strip, a swipeable banner carousel and a row of offer cards. Each part
/// appears only when an admin has published something for it, so with nothing
/// live the menu starts exactly as before.
class PromotionsSection extends ConsumerStatefulWidget {
  final String brand;

  /// Open the menu on this category (a banner's "category" action).
  final ValueChanged<String> onCategory;

  const PromotionsSection({
    super.key,
    required this.brand,
    required this.onCategory,
  });

  @override
  ConsumerState<PromotionsSection> createState() => _PromotionsSectionState();
}

class _PromotionsSectionState extends ConsumerState<PromotionsSection> {
  final Set<String> _counted = {};

  void _seen(Promotion p) {
    if (_counted.add(p.id)) trackPromotion(widget.brand, p.id, 'view');
  }

  Future<void> _open(Promotion p) async {
    HapticFeedback.selectionClick();
    trackPromotion(widget.brand, p.id, 'tap');
    await openPromotion(context, p, widget.brand, widget.onCategory);
  }

  @override
  Widget build(BuildContext context) {
    final promos =
        ref.watch(promotionsProvider(widget.brand)).value ?? const [];

    // A pop-up, once per campaign, after the menu has appeared.
    final popup = promos.where((p) => p.kind == PromoKind.popup).firstOrNull;
    if (popup != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeShowPopup(context, popup, _open),
      );
    }

    final strips = promos.where((p) => p.kind == PromoKind.strip).toList();
    final banners = promos.where((p) => p.kind == PromoKind.banner).toList();
    final offers = promos.where((p) => p.kind == PromoKind.offer).toList();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (strips.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: _Strip(promo: strips.first, onTap: _open, onSeen: _seen),
            ),
          if (banners.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: _Carousel(banners: banners, onTap: _open, onSeen: _seen),
            ),
          if (offers.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: _OfferRow(offers: offers, onTap: _open, onSeen: _seen),
            ),
        ],
      ),
    );
  }
}

/// What a tap on a promotion does.
Future<void> openPromotion(
  BuildContext context,
  Promotion p,
  String brand,
  ValueChanged<String> onCategory,
) async {
  switch (p.action) {
    case PromoAction.category:
      onCategory(p.actionValue);
    case PromoAction.product:
      try {
        final res = await http
            .get(
              AppConfig.buildUrl(
                '/customer/products/${p.actionValue}',
                brand: brand,
              ),
            )
            .timeout(const Duration(seconds: 15));
        final data = jsonDecode(res.body)['data'];
        final json = data is Map && data['product'] is Map
            ? data['product']
            : data;
        if (json is! Map<String, dynamic> || !context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(product: Product.fromJson(json)),
          ),
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("That item isn't available now")),
          );
        }
      }
    case PromoAction.coupon:
      await Clipboard.setData(ClipboardData(text: p.actionValue));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Code ${p.actionValue} copied. Apply it in your bag.',
              ),
            ),
          );
      }
    case PromoAction.url:
      final uri = Uri.tryParse(p.actionValue);
      if (uri != null && uri.scheme == 'https') {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    case PromoAction.none:
      break;
  }
}

// ------------------------------------------------------------------ strip ---

class _Strip extends StatelessWidget {
  final Promotion promo;
  final ValueChanged<Promotion> onTap;
  final ValueChanged<Promotion> onSeen;
  const _Strip({
    required this.promo,
    required this.onTap,
    required this.onSeen,
  });

  @override
  Widget build(BuildContext context) {
    onSeen(promo);
    final bg = promo.color ?? Theme.of(context).colorScheme.primary;
    final fg = bg.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: promo.action == PromoAction.none ? null : () => onTap(promo),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            children: [
              _Wiggle(
                child: Icon(
                  PhosphorIcons.megaphoneSimple(PhosphorIconsStyle.fill),
                  color: fg,
                  size: 18.sp,
                ),
              ),
              GapW(Space.xs),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: promo.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (promo.subtitle.isNotEmpty)
                        TextSpan(text: '  ${promo.subtitle}'),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 12.sp, color: fg),
                ),
              ),
              if (promo.action != PromoAction.none)
                Icon(PhosphorIcons.caretRight(), color: fg, size: 14.sp),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, occasional nudge so the eye finds the announcement.
class _Wiggle extends StatefulWidget {
  final Widget child;
  const _Wiggle({required this.child});

  @override
  State<_Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<_Wiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      // Still most of the time; a quick, fading shake in the first tenth.
      final t = _c.value;
      final angle = t < 0.1
          ? math.sin(t / 0.1 * math.pi * 4) * 0.18 * (1 - t / 0.1)
          : 0.0;
      return Transform.rotate(angle: angle, child: child);
    },
    child: widget.child,
  );
}

// --------------------------------------------------------------- carousel ---

class _Carousel extends StatefulWidget {
  final List<Promotion> banners;
  final ValueChanged<Promotion> onTap;
  final ValueChanged<Promotion> onSeen;
  const _Carousel({
    required this.banners,
    required this.onTap,
    required this.onSeen,
  });

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  late final PageController _pc = PageController(viewportFraction: 0.92);
  Timer? _auto;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    _auto?.cancel();
    if (widget.banners.length < 2) return;
    _auto = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pc.hasClients) return;
      final next = (_page + 1) % widget.banners.length;
      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _Carousel old) {
    super.didUpdateWidget(old);
    if (old.banners.length != widget.banners.length) {
      _page = 0;
      _startAuto();
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    widget.onSeen(widget.banners[_page.clamp(0, widget.banners.length - 1)]);
    return Column(
      children: [
        AspectRatio(
          // Upload banners at 2:1, e.g. 1200 × 600.
          aspectRatio: 2.15,
          child: NotificationListener<ScrollStartNotification>(
            // A swipe by hand pauses the auto-advance until it settles.
            onNotification: (n) {
              if (n.dragDetails != null) _auto?.cancel();
              return false;
            },
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                _startAuto();
                return false;
              },
              child: PageView.builder(
                controller: _pc,
                itemCount: widget.banners.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final b = widget.banners[i];
                  return AnimatedBuilder(
                    animation: _pc,
                    builder: (_, child) {
                      // The banners either side sit slightly smaller.
                      var d = 0.0;
                      if (_pc.position.haveDimensions) {
                        d = ((_pc.page ?? 0) - i).abs().clamp(0.0, 1.0);
                      } else {
                        d = i == _page ? 0 : 1;
                      }
                      return Transform.scale(scale: 1 - d * 0.06, child: child);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: _Banner(promo: b, onTap: widget.onTap),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          Gap(Space.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                  width: i == _page ? 16.w : 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: i == _page ? primary : Colors.black12,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final Promotion promo;
  final ValueChanged<Promotion> onTap;
  const _Banner({required this.promo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasText = promo.title.isNotEmpty || promo.ctaLabel.isNotEmpty;
    return GestureDetector(
      onTap: promo.action == PromoAction.none ? null : () => onTap(promo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: promo.imageUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 250),
              placeholder: (_, _) => ColoredBox(color: Colors.black12),
              errorWidget: (_, _, _) =>
                  ColoredBox(color: promo.color ?? Colors.black12),
            ),
            if (hasText)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            if (hasText)
              Padding(
                padding: EdgeInsets.all(14.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (promo.title.isNotEmpty)
                      SizedBox(
                        width: 200.w,
                        child: Text(
                          promo.title,
                          maxLines: 2,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    if (promo.subtitle.isNotEmpty)
                      SizedBox(
                        width: 200.w,
                        child: Text(
                          promo.subtitle,
                          maxLines: 2,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                    if (promo.ctaLabel.isNotEmpty) ...[
                      Gap(Space.xs),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          promo.ctaLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- offers ---

class _OfferRow extends StatelessWidget {
  final List<Promotion> offers;
  final ValueChanged<Promotion> onTap;
  final ValueChanged<Promotion> onSeen;
  const _OfferRow({
    required this.offers,
    required this.onTap,
    required this.onSeen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: offers.length,
        separatorBuilder: (_, _) => GapW(Space.sm),
        itemBuilder: (context, i) {
          final o = offers[i];
          onSeen(o);
          final primary = o.color ?? Theme.of(context).colorScheme.primary;
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(14.r),
              onTap: () => onTap(o),
              child: Container(
                width: 230.w,
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        PhosphorIcons.sealPercent(PhosphorIconsStyle.fill),
                        color: primary,
                        size: 22.sp,
                      ),
                    ),
                    GapW(Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            o.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            o.action == PromoAction.coupon
                                ? 'Use code ${o.actionValue}'
                                : o.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ popup ---

const _seenStore = FlutterSecureStorage();
final Set<String> _shownThisRun = {};

Future<void> _maybeShowPopup(
  BuildContext context,
  Promotion p,
  ValueChanged<Promotion> onTap,
) async {
  if (!_shownThisRun.add(p.id)) return;
  final key = 'promo_seen_${p.id}';
  try {
    if (await _seenStore.read(key: key) != null) return;
    await _seenStore.write(key: key, value: '1');
  } catch (_) {
    return; // can't remember it, so don't risk showing it every launch
  }
  if (!context.mounted) return;
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    transitionBuilder: (_, anim, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: anim, child: child),
    ),
    pageBuilder: (ctx, _, _) => Center(
      child: Padding(
        padding: EdgeInsets.all(28.r),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  if (p.action != PromoAction.none) onTap(p);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.r),
                  child: CachedNetworkImage(
                    imageUrl: p.imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Positioned(
                top: -12,
                right: -12,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(PhosphorIcons.x(), size: 16.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
