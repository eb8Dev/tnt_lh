import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/cart_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/screens/store_home.dart';
import 'package:tnt_lh/screens/order_detail_screen.dart';
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final Cart cart;
  final String? specificBrand; // 'teasntrees', 'littleh' or null for global
  const CheckoutScreen({super.key, required this.cart, this.specificBrand});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  String _paymentMethod = "COD";
  bool _isLoading = false;
  bool _isGlobal = true;

  // Pricing
  double _deliveryCharge = 50;
  double _gstRate = 5;

  @override
  void initState() {
    super.initState();
    _isGlobal = widget.specificBrand == null;
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchUserAddress(), _fetchSettings()]);
  }

  Future<void> _fetchUserAddress() async {
    try {
      final brand = widget.specificBrand ?? ref.read(brandProvider);
      final profile = await AuthService.getProfile(brand: brand);
      if (profile['success'] == true && profile['data']['user'] != null) {
        final address = profile['data']['user']['address'];
        if (address != null && mounted) {
          _addressController.text = address;
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchSettings() async {
    try {
      final brand = widget.specificBrand ?? ref.read(brandProvider);
      final settings = await OrderService.getSettings(brand: brand);
      if (mounted) {
        setState(() {
          _deliveryCharge = (settings['deliveryCharge'] ?? 50).toDouble();
          _gstRate = (settings['gstRate'] ?? 5).toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentBrand = widget.specificBrand ?? ref.read(brandProvider);

      // Map cart items to backend format
      final itemsPayload = widget.cart.items
          .map(
            (item) => {
              "product": item.product.id,
              "quantity": item.quantity,
              "price": item.price,
              "customization": item.customization,
            },
          )
          .toList();

      // Place order
      final result = await OrderService.createOrder(
        deliveryAddress: _addressController.text.trim(),
        deliveryInstructions: _instructionsController.text.trim(),
        paymentMethod: _paymentMethod,
        brand: currentBrand,
        items: _isGlobal ? null : itemsPayload,
      );

      if (result['success'] == true) {
        if (!_isGlobal) {
          for (var item in widget.cart.items) {
            try {
              await ref
                  .read(cartProvider.notifier)
                  .removeItem(item.id, brand: item.brand);
            } catch (_) {}
          }
        }

        // Refresh local cart state
        await ref.read(cartProvider.notifier).fetchCart();

        if (mounted) {
          _showSuccessDialog(result['data']);
        }
      } else {
        throw result['message'] ?? 'Checkout failed';
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Error: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> orderData) {
    final orderId =
        orderData['orderId']?.toString() ?? orderData['_id']?.toString() ?? '';
    final orders = orderData['orders'] as List?;
    final isMultiOrder = orders != null && orders.length > 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          "Order Placed!",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMultiOrder
                  ? "Your orders have been placed successfully."
                  : "Your order #${orderData['orderNumber'] ?? ''} has been placed successfully.",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            ),
            if (isMultiOrder) ...[
              const SizedBox(height: 16),
              ...orders.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: o['brand'] == 'teasntrees' 
                              ? const Color(0xFF57733C) 
                              : const Color(0xFF8C3414),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${o['brand'] == 'teasntrees' ? 'Cafe' : 'Bakery'}: #${o['orderNumber']}",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const StoreHomeScreen(initialIndex: 3),
                ),
                (route) => false,
              );
            },
            child: Text(
              "My Orders",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
          ),
          TactileButton(
            onTap: () {
              Navigator.pop(ctx);
              if (orderId.isNotEmpty) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      orderId: orderId,
                      brand: widget.specificBrand,
                    ),
                  ),
                  (route) => false,
                );
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreHomeScreen(initialIndex: 3),
                  ),
                  (route) => false,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                "Track Order",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.cart.subtotal;
    final tax = subtotal * (_gstRate / 100);
    final total = subtotal + _deliveryCharge + tax;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _isGlobal ? "Checkout All" : "Checkout Store",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontSize: 20,
              ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isGlobal && widget.cart.itemCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "We'll separate your orders for each brand to ensure the best experience.",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildSectionTitle("Delivery Address"),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(
                    "Where should we deliver?",
                  ),
                  validator: (val) =>
                      val!.isEmpty ? "Address is required" : null,
                ),

                const SizedBox(height: 36),

                _buildSectionTitle("Special Instructions"),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(
                    "e.g. Ring the bell, leave at the gate...",
                  ),
                ),

                const SizedBox(height: 36),

                _buildSectionTitle("Payment Method"),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: "COD",
                        groupValue: _paymentMethod,
                        onChanged: (val) =>
                            setState(() => _paymentMethod = val.toString()),
                        title: Text(
                          "Cash on Delivery",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          "Pay when your order arrives",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),
                      RadioListTile<String>(
                        value: "Online",
                        groupValue: _paymentMethod,
                        onChanged: (val) {
                          SnackBarUtils.showThemedSnackBar(
                            context: context,
                            message: "Online payment coming soon!",
                          );
                        },
                        title: Text(
                          "Online Payment",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          "UPI, Cards, Netbanking",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Summary
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        "Item Total",
                        "₹${subtotal.toStringAsFixed(2)}",
                      ),
                      const SizedBox(height: 14),
                      _buildSummaryRow(
                        "Delivery Fee",
                        "₹${_deliveryCharge.toStringAsFixed(2)}",
                      ),
                      const SizedBox(height: 14),
                      _buildSummaryRow(
                        "GST ($_gstRate%)",
                        "₹${tax.toStringAsFixed(2)}",
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(color: Color(0xFFF0F0F0)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Grand Total",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "₹${total.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                TactileButton(
                  onTap: _isLoading ? null : _placeOrder,
                  child: Container(
                    width: double.infinity,
                    height: 64,
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
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isGlobal ? "Place All Orders" : "Confirm Order",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.black87,
          ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black26),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildSummaryRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
