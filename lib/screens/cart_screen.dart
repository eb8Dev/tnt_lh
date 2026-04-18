import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/cart_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/screens/checkout_screen.dart';
import 'package:tnt_lh/screens/store_home.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/utils/loading_indicator.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).fetchCart());
  }

  Future<void> _updateQuantity(String itemId, int newQty) async {
    try {
      if (newQty < 1) return;
      await ref.read(cartProvider.notifier).updateQuantity(itemId, newQty);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Failed to update: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _removeItem(String itemId, String brand) async {
    try {
      await ref.read(cartProvider.notifier).removeItem(itemId, brand: brand);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Failed to remove: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Clear All Bags?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("This will remove ALL items from both Cafe and Bakery.", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Clear Everything", style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(cartProvider.notifier).clearCart();
        if (mounted) {
          SnackBarUtils.showThemedSnackBar(context: context, message: "All bags cleared");
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showThemedSnackBar(context: context, message: "Failed to clear: $e", isError: true);
        }
      }
    }
  }

  Future<void> _clearBrandCart(String brand) async {
    final brandName = brand == 'teasntrees' ? 'Cafe' : 'Bakery';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Clear $brandName Bag?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Remove all items from your $brandName bag?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Clear Bag", style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(cartProvider.notifier).clearCart(brand: brand);
        if (mounted) {
          SnackBarUtils.showThemedSnackBar(context: context, message: "$brandName bag cleared");
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showThemedSnackBar(context: context, message: "Failed: $e", isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "My Bags",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontSize: 20,
              ),
        ),
        actions: [
          TactileButton(
            onTap: _clearCart,
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Icon(
                Icons.delete_sweep_rounded,
                color: Colors.black45,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: cartState.when(
        loading: () => const Center(child: HouseOfFlavorsLoader(size: 160)),
        error: (err, stack) =>
            Center(child: Text("Error: $err", style: GoogleFonts.poppins())),
        data: (cart) {
          if (cart.items.isEmpty) {
            return _buildEmptyState();
          }

          final cafeItems = cart.items
              .where((i) => i.brand == 'teasntrees')
              .toList();
          final bakeryItems = cart.items
              .where((i) => i.brand == 'littleh')
              .toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  children: [
                    if (cafeItems.isNotEmpty)
                      _buildBrandSection(
                        "Teas N Trees (Cafe)",
                        cafeItems,
                        const Color(0xFF57733C),
                        'teasntrees',
                      ),

                    if (bakeryItems.isNotEmpty) ...[
                      const SizedBox(height: 36),
                      _buildBrandSection(
                        "Little H (Bakery)",
                        bakeryItems,
                        const Color(0xFF8C3414),
                        'littleh',
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              _buildGlobalCheckoutFooter(cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrandSection(
    String title,
    List<CartItem> items,
    Color themeColor,
    String brand,
  ) {
    final brandSubtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 24,
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
              ],
            ),
            Row(
              children: [
                TactileButton(
                  onTap: () => _clearBrandCart(brand),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TactileButton(
                  onTap: () {
                    final brandCart = Cart(
                      items: items,
                      subtotal: brandSubtotal,
                      itemCount: items.length,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CheckoutScreen(cart: brandCart, specificBrand: brand),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Checkout Store",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildCartItem(item),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Dismissible(
      key: Key("cart_item_${item.id}"),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Color(0xFFEF5350), // Colors.red.shade400
          size: 32,
        ),
      ),
      onDismissed: (_) => _removeItem(item.id, item.brand),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
        ),
        child: Row(
          children: [
            Container(
              height: 75,
              width: 75,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child:
                    item.product.image != null && item.product.image!.isNotEmpty
                    ? Image.network(
                        item.product.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.fastfood_rounded,
                          color: Colors.black12,
                          size: 32,
                        ),
                      )
                    : const Icon(
                        Icons.fastfood_rounded,
                        color: Colors.black12,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                  ),
                  if (item.customization != null)
                    Text(
                      item.customization!,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.black38,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${item.price * item.quantity}",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  TactileButton(
                    onTap: () {
                      if (item.quantity == 1) {
                        _removeItem(item.id, item.brand);
                      } else {
                        _updateQuantity(item.id, item.quantity - 1);
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: Icon(
                        item.quantity == 1
                            ? Icons.delete_outline_rounded
                            : Icons.remove_rounded,
                        size: 18,
                        color: item.quantity == 1
                            ? Colors.redAccent
                            : Colors.black87,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      "${item.quantity}",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TactileButton(
                    onTap: () =>
                        _updateQuantity(item.id, item.quantity + 1),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: const Icon(Icons.add_rounded, size: 18, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Icon(
              Icons.shopping_basket_rounded,
              size: 80,
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Your bags are empty",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            "Discover something delicious today",
            style: GoogleFonts.poppins(color: Colors.black38, fontSize: 14),
          ),
          const SizedBox(height: 40),
          TactileButton(
            onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const StoreHomeScreen()),
              (route) => false,
            ),
            child: Container(
              width: 220,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                "Start Exploring",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalCheckoutFooter(Cart cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Total Amount",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "₹${cart.subtotal}",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          TactileButton(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CheckoutScreen(cart: cart)),
            ),
            child: Container(
              width: 180,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Checkout All",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 20, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
