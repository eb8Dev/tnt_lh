import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  Future<void> _onItemTapped(int index) async {
    if (index == _selectedIndex) return;

    // Leaving the profile mid-edit would silently bin the changes, so ask first.
    const profileTab = 4;
    if (_selectedIndex == profileTab &&
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
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
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
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
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

  void _handleStoreSwitch() {
    HapticFeedback.selectionClick();
    final currentBrand = ref.read(brandProvider);
    final targetBrand = currentBrand == 'teasntrees' ? 'littleh' : 'teasntrees';

    // Determine target color and logo
    final targetColor = targetBrand == 'teasntrees'
        ? Color(0xFF57733C)
        : Color(0xFF8C3414);

    final targetLogo = targetBrand == 'teasntrees'
        ? "assets/images/teas_n_trees_no_bg.png"
        : "assets/images/little_h_logo_no_bg.png";

    StoreTransitionOverlay.show(
      context,
      color: targetColor,
      logoAsset: targetLogo,
      onTransitionPoint: () {
        ref.read(brandProvider.notifier).setBrand(targetBrand);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);

    final List<Widget> pages = [
      BrandHomeContent(brand: brand, onSwitchStore: _handleStoreSwitch),
      CartScreen(),
      OrdersScreen(),
      CafeProfileScreen(),
    ];

    // Map _selectedIndex to page index since we have 4 pages but 5 slots (1 is FAB)
    int pageIndex = _selectedIndex;
    if (_selectedIndex > 1) pageIndex = _selectedIndex - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // IndexedStack keeps every tab's state alive (scroll position, search
      // text). A keyed cross-fade here would remount and lose all of it, so the
      // liveness comes from the haptic on tap instead of a page fade.
      // The active-order bar sits just above the bottom nav on every tab, so an
      // in-flight order is always one tap from tracking. IndexedStack stays in
      // an Expanded so tab state is still preserved.
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: pageIndex, children: pages)),
          const ActiveOrderBar(),
        ],
      ),
      floatingActionButton: TactileButton(
        onTap: _handleStoreSwitch,
        child: Container(
          width: 64.w,
          height: 64.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.onPrimary,
                Theme.of(context).colorScheme.inversePrimary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(12.0.r),
            child: Image.asset(
              brand == 'teasntrees'
                  ? "assets/images/little_h_logo_no_bg.png"
                  : "assets/images/teas_n_trees_no_bg.png",
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: CircularNotchedRectangle(),
          notchMargin: 10,
          color: Colors.white,
          elevation: 0,
          child: SizedBox(
            height: 60.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, PhosphorIcons.house(PhosphorIconsStyle.fill), PhosphorIcons.house(), "Home"),
                Consumer(
                  builder: (context, ref, child) {
                    final cart = ref.watch(cartProvider).value;
                    final count = cart?.itemCount ?? 0;
                    return _buildNavItem(
                      1,
                      brand == 'teasntrees'
                          ? PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill)
                          : PhosphorIcons.basket(PhosphorIconsStyle.fill),
                      brand == 'teasntrees'
                          ? PhosphorIcons.shoppingBag()
                          : PhosphorIcons.basket(),
                      "Bag",
                      badgeCount: count,
                    );
                  },
                ),
                SizedBox(width: 48.w), // Space for FAB
                _buildNavItem(
                  3,
                  PhosphorIcons.receipt(PhosphorIconsStyle.fill),
                  PhosphorIcons.receipt(PhosphorIconsStyle.fill),
                  "Orders",
                ),
                _buildNavItem(
                  4,
                  PhosphorIcons.user(PhosphorIconsStyle.fill),
                  PhosphorIcons.user(),
                  "Profile",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: TactileButton(
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black26,
                  size: 26.sp,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5.w),
                      ),
                      constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
