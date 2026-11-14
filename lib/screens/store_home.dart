import 'package:tnt_lh/core/responsive.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:flutter/material.dart';
import 'package:tnt_lh/widgets/bump_on_change.dart';
import 'package:tnt_lh/widgets/active_order_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/unsaved_changes_provider.dart';
import 'package:tnt_lh/screens/cafe/cafe_home_content.dart';
import 'package:tnt_lh/screens/cafe/cafe_profile_screen.dart';
import 'package:tnt_lh/screens/cart_screen.dart';
import 'package:tnt_lh/screens/orders_screen.dart';
import 'package:tnt_lh/services/notification_service.dart';
import 'package:tnt_lh/services/update_service.dart';
import 'package:tnt_lh/widgets/store_transition_overlay.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

class StoreHomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const StoreHomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends ConsumerState<StoreHomeScreen> {
  int _selectedIndex = 0;

  // The four tabs map directly to page indices now that the centre store-switch
  // FAB is gone (the switch moved to a top segmented control on the home tab).
  static const int _profileTab = 3;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    // Check for a newer build once the home is on screen (Play on Android,
    // App Store lookup on iOS). Fire-and-forget; it never blocks or throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.check(context);
      // Signed in and on the home screen: the right moment to ask about
      // notifications and register this device for order pushes.
      NotificationService.enableForSignedInUser();
    });
  }

  Future<void> _onItemTapped(int index) async {
    if (index == _selectedIndex) return;

    // Leaving the profile mid-edit would silently bin the changes, so ask first.
    if (_selectedIndex == _profileTab &&
        ref.read(profileHasUnsavedChangesProvider)) {
      final leave = await _confirmDiscardChanges();
      if (leave != true) return;
      // The dialog was open and awaited; the tab bar could be gone by now.
      if (!mounted) return;
      ref.read(profileHasUnsavedChangesProvider.notifier).set(false);
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool?> _confirmDiscardChanges() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discard your changes?',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "You've edited your profile but haven't saved it. Leaving now "
              'will discard those changes.',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'Keep editing',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'Discard',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Cross into a specific store from the top segmented switcher. No-ops if it's
  /// already the active brand. The full-screen radial wipe (kept from the old
  /// FAB) sells the "you're entering a different store" moment; it now
  /// originates from the top where the switcher lives.
  void _switchToBrand(String targetBrand) {
    final currentBrand = ref.read(brandProvider);
    if (targetBrand == currentBrand) return;

    HapticFeedback.selectionClick();

    final targetColor = targetBrand == 'teasntrees'
        ? const Color(0xFF57733C)
        : Brands.bakeryColor;

    final targetLogo = Brands.logo(targetBrand);

    // Teas N Trees is the left segment, Cream N Crust the right — start the wipe
    // under whichever one was tapped, up near the switcher.
    final originAlignment = targetBrand == 'teasntrees'
        ? const Alignment(-0.6, -0.82)
        : const Alignment(0.6, -0.82);

    StoreTransitionOverlay.show(
      context,
      color: targetColor,
      logoAsset: targetLogo,
      originAlignment: originAlignment,
      onTransitionPoint: () {
        ref.read(brandProvider.notifier).setBrand(targetBrand);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);

    final List<Widget> pages = [
      BrandHomeContent(brand: brand, onSelectStore: _switchToBrand),
      const CartScreen(),
      const OrdersScreen(),
      const CafeProfileScreen(),
    ];

    // Landscape tablets: navigation moves to a rail on the left, so the
    // content gets the full height.
    if (Responsive.isExpanded(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            _buildSideRail(brand),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: IndexedStack(index: _selectedIndex, children: pages),
                  ),
                  const SafeArea(top: false, child: ActiveOrderBar()),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // IndexedStack keeps every tab's state alive (scroll position, search
      // text). A keyed cross-fade here would remount and lose all of it, so the
      // liveness comes from the haptic on tap instead of a page fade.
      body: IndexedStack(index: _selectedIndex, children: pages),
      // A floating pill nav with the active-order card riding just above it, so
      // an in-flight order is always one tap from tracking no matter the tab.
      // Both reserve real layout space (they're not a pure overlay), so no
      // screen's own bottom content — the cart checkout footer especially — is
      // ever hidden behind them.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [const ActiveOrderBar(), _buildFloatingNav(brand)],
      ),
    );
  }

  Widget _buildSideRail(String brand) {
    final cartCount = ref.watch(cartProvider).value?.itemCount ?? 0;
    final primary = Theme.of(context).colorScheme.primary;
    final label = GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    NavigationRailDestination dest(
      IconData icon,
      IconData active,
      String text, {
      int badge = 0,
    }) => NavigationRailDestination(
      icon: BumpOnChange(
        value: badge,
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          child: Icon(icon),
        ),
      ),
      selectedIcon: BumpOnChange(
        value: badge,
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          child: Icon(active),
        ),
      ),
      label: Text(text),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        right: false,
        child: NavigationRail(
          backgroundColor: Colors.white,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          labelType: NavigationRailLabelType.all,
          groupAlignment: -0.85,
          indicatorColor: primary,
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedIconTheme: const IconThemeData(color: Colors.black45),
          selectedLabelTextStyle: label.copyWith(color: primary),
          unselectedLabelTextStyle: label.copyWith(color: Colors.black54),
          leading: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: SizedBox(
              width: 64,
              height: 40,
              child: Image.asset(Brands.logo(brand), fit: BoxFit.contain),
            ),
          ),
          destinations: [
            dest(
              PhosphorIcons.house(),
              PhosphorIcons.house(PhosphorIconsStyle.fill),
              'Home',
            ),
            dest(
              brand == 'teasntrees'
                  ? PhosphorIcons.shoppingBag()
                  : PhosphorIcons.basket(),
              brand == 'teasntrees'
                  ? PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill)
                  : PhosphorIcons.basket(PhosphorIconsStyle.fill),
              'Bag',
              badge: cartCount,
            ),
            dest(
              PhosphorIcons.receipt(),
              PhosphorIcons.receipt(PhosphorIconsStyle.fill),
              'Orders',
            ),
            dest(
              PhosphorIcons.user(),
              PhosphorIcons.user(PhosphorIconsStyle.fill),
              'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNav(String brand) {
    final cartCount = ref.watch(cartProvider).value?.itemCount ?? 0;

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
        height: 64.h,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              0,
              PhosphorIcons.house(PhosphorIconsStyle.fill),
              PhosphorIcons.house(),
              "Home",
            ),
            _buildNavItem(
              1,
              brand == 'teasntrees'
                  ? PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill)
                  : PhosphorIcons.basket(PhosphorIconsStyle.fill),
              brand == 'teasntrees'
                  ? PhosphorIcons.shoppingBag()
                  : PhosphorIcons.basket(),
              "Bag",
              badgeCount: cartCount,
            ),
            _buildNavItem(
              2,
              PhosphorIcons.receipt(PhosphorIconsStyle.fill),
              PhosphorIcons.receipt(),
              "Orders",
            ),
            _buildNavItem(
              3,
              PhosphorIcons.user(PhosphorIconsStyle.fill),
              PhosphorIcons.user(),
              "Profile",
            ),
          ],
        ),
      ),
    );
  }

  /// An expanding-pill nav item: the selected tab fills with the brand colour
  /// and reveals its label; the rest stay as compact icons. Matches the modern
  /// floating-nav look (Zomato/Swiggy) the client referenced.
  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;
    final primary = Theme.of(context).colorScheme.primary;

    return TactileButton(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.w : 12.w,
          vertical: 10.h,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BumpOnChange(
              value: badgeCount,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : inactiveIcon,
                    color: isSelected ? Colors.white : Colors.black38,
                    size: 24.sp,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        padding: EdgeInsets.all(3.r),
                        constraints: BoxConstraints(
                          minWidth: 16.w,
                          minHeight: 16.w,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$badgeCount',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: primary,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 8.w),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
