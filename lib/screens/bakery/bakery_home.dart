import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/screens/cafe/cafe_home_content.dart';
import 'package:tnt_lh/screens/cafe/cafe_profile_screen.dart';
import 'package:tnt_lh/screens/cart_screen.dart';
import 'package:tnt_lh/screens/orders_screen.dart';
import 'package:tnt_lh/screens/store_selection_screen.dart';
import 'package:tnt_lh/providers/cart_provider.dart';

class BakeryHome extends StatefulWidget {
  final int initialIndex;
  const BakeryHome({super.key, this.initialIndex = 0});

  @override
  State<BakeryHome> createState() => _BakeryHomeState();
}

class _BakeryHomeState extends State<BakeryHome> {
  int _selectedIndex = 0;
  final _storage = const FlutterSecureStorage();

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

  Future<void> _switchStore() async {
    await _storage.delete(key: 'last_visited_store');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const StoreSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (context) => false,
    );
  }

  final List<Widget> _pages = [
    const BrandHomeContent(brand: 'littleh'),
    const CartScreen(),
    const OrdersScreen(),
    const CafeProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    int pageIndex = _selectedIndex;
    if (_selectedIndex > 1) pageIndex = _selectedIndex - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[pageIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _switchStore,
        backgroundColor: Colors.black,
        elevation: 4,
        shape: const CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFA9BCA4), Color(0xFFC5D3C1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.swap_horiz_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, "Home"),
              Consumer(
                builder: (context, ref, child) {
                  final cart = ref.watch(cartProvider).value;
                  final count = cart?.itemCount ?? 0;
                  return _buildNavItem(
                    1,
                    Icons.shopping_basket_rounded,
                    Icons.shopping_basket_outlined,
                    "Bag",
                    badgeCount: count,
                  );
                },
              ),
              const SizedBox(width: 40), // Space for FAB
              _buildNavItem(
                3,
                Icons.receipt_sharp,
                Icons.receipt_long_rounded,
                "Orders",
              ),
              _buildNavItem(
                4,
                Icons.person_rounded,
                Icons.person_outline_rounded,
                "Profile",
              ),
            ],
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
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected ? const Color(0xFFA9BCA4) : Colors.black38,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFA9BCA4),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
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
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFFA9BCA4) : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
