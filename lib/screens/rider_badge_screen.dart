import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/widgets/lanyard.dart';

/// "Meet your rider": their ID badge drops in on a lanyard when a rider takes
/// the order (and from the rider row any time after). Swing it, throw it, tap
/// it to see the back.
class RiderBadgeScreen extends StatelessWidget {
  final RiderBadge rider;
  final String brand;
  final String? pin;
  const RiderBadgeScreen({
    super.key,
    required this.rider,
    required this.brand,
    this.pin,
  });

  /// Opens the badge over the current screen.
  static Future<void> show(
    BuildContext context, {
    required RiderBadge rider,
    required String brand,
    String? pin,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) =>
            RiderBadgeScreen(rider: rider, brand: brand, pin: pin),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _call() async {
    final phone = rider.phone;
    if (phone == null || phone.isEmpty) return;
    HapticFeedback.selectionClick();
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  @override
  Widget build(BuildContext context) {
    final bakery = Brands.isBakery(brand);
    final ink = bakery ? Brands.bakeryChocolate : const Color(0xFF0F2419);
    final accent = bakery ? Brands.bakeryColor : Brands.cafeColor;
    final first = rider.name.split(' ').first;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ink.withValues(alpha: 0.94),
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: Icon(PhosphorIcons.x(), color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Lanyard(
                  cardSize: Size(232.w, 336.w),
                  strapLength: 170.h,
                  strapColor: accent,
                  strapAccent: Colors.white,
                  front: _Front(
                    rider: rider,
                    brand: brand,
                    ink: ink,
                    accent: accent,
                  ),
                  back: _Back(
                    rider: rider,
                    pin: pin,
                    ink: ink,
                    accent: accent,
                    onCall: _call,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Space.lg.w,
                  0,
                  Space.lg.w,
                  Space.md.h,
                ),
                child: Column(
                  children: [
                    Text(
                      '$first is bringing your order',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Gap(Space.xxs),
                    Text(
                      'Tap the card to flip it. Swing it if you like.',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 12.5.sp,
                      ),
                    ),
                    Gap(Space.md),
                    Row(
                      children: [
                        if ((rider.phone ?? '').isNotEmpty) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _call,
                              icon: Icon(PhosphorIcons.phone(), size: 18.sp),
                              label: Text(
                                'Call $first',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                minimumSize: Size.fromHeight(50.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                              ),
                            ),
                          ),
                          GapW(Space.sm),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ink,
                              minimumSize: Size.fromHeight(50.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                            child: Text(
                              'Track order',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Front extends StatelessWidget {
  final RiderBadge rider;
  final String brand;
  final Color ink;
  final Color accent;
  const _Front({
    required this.rider,
    required this.brand,
    required this.ink,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final band = 92.w;
    final avatar = 74.w;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Brand band (slot for the clip, shop name) with the avatar overlapping its edge.
          SizedBox(
            height: band + avatar / 2,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(height: band, color: ink),
                Positioned(
                  top: 12.w,
                  child: Container(
                    width: 52.w,
                    height: 9.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Positioned(
                  top: 30.w,
                  child: Row(
                    children: [
                      Container(
                        width: 22.w,
                        height: 22.w,
                        padding: EdgeInsets.all(2.5.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Image.asset(Brands.logo(brand)),
                      ),
                      SizedBox(width: 7.w),
                      Text(
                        Brands.name(brand).toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: band - avatar / 2,
                  child: Container(
                    width: avatar,
                    height: avatar,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      rider.initials,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 25.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 8.w, left: 12.w, right: 12.w),
                child: Column(
                  children: [
                    Text(
                      rider.name,
                      style: GoogleFonts.poppins(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    Text(
                      rider.code == null
                          ? 'Delivery partner'
                          : 'Delivery partner  ·  ${rider.code}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5.sp,
                        color: Colors.black45,
                      ),
                    ),
                    if (rider.vehicleNumber != null) ...[
                      SizedBox(height: 10.w),
                      // A number plate.
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.w,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7D6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black87, width: 1.6),
                        ),
                        child: Text(
                          rider.vehicleNumber!.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                    if (rider.vehicle != null) ...[
                      SizedBox(height: 3.w),
                      Text(
                        rider.vehicle!,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.fromLTRB(14.w, 6.w, 14.w, 14.w),
            padding: EdgeInsets.symmetric(vertical: 9.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _Stat(
                  value: rider.rating == null
                      ? 'New'
                      : rider.rating!.toStringAsFixed(1),
                  label: rider.rating == null ? 'rider' : 'rating',
                  icon: rider.rating == null
                      ? null
                      : PhosphorIcons.star(PhosphorIconsStyle.fill),
                ),
                Container(width: 1, height: 28.w, color: Colors.black12),
                _Stat(
                  value: '${rider.deliveries}',
                  label: rider.deliveries == 1 ? 'delivery' : 'deliveries',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  const _Stat({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13.sp, color: const Color(0xFFE0A030)),
                SizedBox(width: 3.w),
              ],
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10.sp, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _Back extends StatelessWidget {
  final RiderBadge rider;
  final String? pin;
  final Color ink;
  final Color accent;
  final VoidCallback onCall;
  const _Back({
    required this.rider,
    required this.pin,
    required this.ink,
    required this.accent,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final hasPin = (pin ?? '').isNotEmpty;
    return Container(
      color: ink,
      padding: EdgeInsets.all(18.w),
      child: Column(
        children: [
          SizedBox(height: 24.w),
          Icon(
            PhosphorIcons.lockKey(PhosphorIconsStyle.duotone),
            color: Colors.white70,
            size: 30.sp,
          ),
          SizedBox(height: 10.w),
          Text(
            hasPin ? 'Delivery PIN' : 'Your delivery PIN',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 14.w),
          if (hasPin)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in pin!.split(''))
                  Container(
                    width: 38.w,
                    height: 48.w,
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      d,
                      style: GoogleFonts.poppins(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
              ],
            )
          else
            Text(
              'Shows here once your order is on its way.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 12.5.sp,
                height: 1.4,
              ),
            ),
          SizedBox(height: 10.w),
          if (hasPin)
            Text(
              'Share it only when you have your order.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 11.5.sp,
              ),
            ),
          const Spacer(),
          if ((rider.phone ?? '').isNotEmpty)
            GestureDetector(
              onTap: onCall,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.w),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.phoneCall(PhosphorIconsStyle.fill),
                      color: Colors.white,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Call ${rider.name.split(' ').first}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
