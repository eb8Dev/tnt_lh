import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleStoreSwitch() {
    final currentBrand = ref.read(brandProvider);
    final targetBrand = currentBrand == 'teasntrees' ? 'littleh' : 'teasntrees';
    
    // Determine target color and logo
    final targetColor = targetBrand == 'teasntrees' 
        ? const Color(0xFF57733C) 
        : const Color(0xFF8C3414);
    
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
      BrandHomeContent(brand: brand),
      const CartScreen(),
      const OrdersScreen(),
      const CafeProfileScreen(),
    ];

    // Map _selectedIndex to page index since we have 4 pages but 5 slots (1 is FAB)
    int pageIndex = _selectedIndex;
    if (_selectedIndex > 1) pageIndex = _selectedIndex - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: pageIndex,
        children: pages,
      ),
      floatingActionButton: TactileButton(
        onTap: _handleStoreSwitch,
        child: Container(
          width: 64,
          height: 64,
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
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
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          color: Colors.white,
          elevation: 0,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_filled, Icons.home, "Home"),
                Consumer(
                  builder: (context, ref, child) {
                    final cart = ref.watch(cartProvider).value;
                    final count = cart?.itemCount ?? 0;
                    return _buildNavItem(
                      1,
                      brand == 'teasntrees' ? Icons.shopping_bag_rounded : Icons.shopping_basket_rounded,
                      brand == 'teasntrees' ? Icons.shopping_bag_outlined : Icons.shopping_basket_outlined,
                      "Bag",
                      badgeCount: count,
                    );
                  },
                ),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(
                  3,
                  Icons.receipt,
                  Icons.receipt_long_rounded,
                  "Orders",
                ),
                _buildNavItem(
                  4, Icons.person_rounded,
                  Icons.person_2_outlined,
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
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black26,
                  size: 26,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
