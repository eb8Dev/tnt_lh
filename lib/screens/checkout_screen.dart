import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/cart_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/screens/bakery/bakery_home.dart';
import 'package:tnt_lh/screens/cafe/cafe_home.dart';
import 'package:tnt_lh/screens/order_detail_screen.dart';
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';

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
        // Backend handles clearing the cart for global checkout.
        // For store-wise checkout, we need to remove items manually since /customer/orders
        // doesn't clear the cart by default.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          "Order Placed!",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
              const SizedBox(height: 12),
              ...orders.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    "• ${o['brand'] == 'teasntrees' ? 'Cafe' : 'Bakery'}: #${o['orderNumber']}",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFA9BCA4),
                    ),
                  ),
                ),
              ),
            ] else if (_isGlobal &&
                !isMultiOrder &&
                orders != null &&
                orders.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Order Number: #${orders[0]['orderNumber']}",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA9BCA4),
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
                  builder: (_) => ref.read(brandProvider) == 'teasntrees'
                      ? const CafeHome(initialIndex: 3)
                      : const BakeryHome(initialIndex: 3),
                ),
                (route) => false,
              );
            },
            child: Text(
              "My Orders",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
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
                    builder: (_) => ref.read(brandProvider) == 'teasntrees'
                        ? const CafeHome(initialIndex: 3)
                        : const BakeryHome(initialIndex: 3),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Track Order",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isGlobal ? "Checkout All" : "Checkout Store Wise",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
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
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA9BCA4).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFA9BCA4).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(0xFFA9BCA4),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "You are placing orders for all items in your bags from both stores.",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildSectionTitle("Delivery Address"),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(
                    "Enter your full delivery address",
                  ),
                  validator: (val) =>
                      val!.isEmpty ? "Address is required" : null,
                ),

                const SizedBox(height: 32),

                _buildSectionTitle("Delivery Instructions"),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructionsController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(
                    "e.g. Ring the bell, leave at gate...",
                  ),
                ),

                const SizedBox(height: 32),

                _buildSectionTitle("Payment Method"),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      RadioListTile(
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
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        activeColor: const Color(0xFFA9BCA4),
                      ),
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Colors.grey.shade200,
                      ),
                      RadioListTile(
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
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        activeColor: const Color(0xFFA9BCA4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Summary
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        "Item Total",
                        "₹${subtotal.toStringAsFixed(2)}",
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        "Delivery Fee",
                        "₹${_deliveryCharge.toStringAsFixed(2)}",
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        "GST ($_gstRate%)",
                        "₹${tax.toStringAsFixed(2)}",
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Colors.black12),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Grand Total",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            "₹${total.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: const Color(0xFFA9BCA4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isGlobal ? "Place All Orders" : "Place Order",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
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
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.black26),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
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
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
