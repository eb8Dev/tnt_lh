import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:tnt_lh/models/cart_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/screens/address_picker_screen.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/status_provider.dart';
import 'package:tnt_lh/screens/store_home.dart';
import 'package:tnt_lh/screens/order_detail_screen.dart';
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/services/coupon_service.dart';
import 'package:tnt_lh/services/address_service.dart';
import 'package:tnt_lh/models/address_model.dart';
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

  /// Set once the user confirms a pin on the map. Without these the order
  /// reaches the backend with no point, and the rider has nothing to navigate to.
  double? _latitude;
  double? _longitude;

  // Pricing
  double _deliveryCharge = 50;
  double _gstRate = 5;

  // Coupon
  final TextEditingController _couponController = TextEditingController();
  String? _appliedCoupon;
  double _couponDiscount = 0;
  bool _validatingCoupon = false;
  String? _couponError;

  // Saved addresses
  List<SavedAddress> _savedAddresses = [];
  String? _selectedAddressId;
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _isGlobal = widget.specificBrand == null;
    _fetchData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _instructionsController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchUserAddress(),
      _fetchSettings(),
      _fetchSavedAddresses(),
    ]);
  }

  Future<void> _fetchSavedAddresses() async {
    try {
      final brand = widget.specificBrand ?? ref.read(brandProvider);
      final list = await AddressService.getAddresses(brand: brand);
      if (!mounted) return;
      setState(() {
        _savedAddresses = list;
        _loadingAddresses = false;
        // Preselect the default (or first) saved address.
        if (list.isNotEmpty) {
          final def = list.firstWhere(
            (a) => a.isDefault,
            orElse: () => list.first,
          );
          _selectAddress(def);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  void _selectAddress(SavedAddress a) {
    _selectedAddressId = a.id;
    _addressController.text = a.label.isEmpty
        ? a.addressLine
        : '${a.label}, ${a.addressLine}';
    _latitude = a.latitude;
    _longitude = a.longitude;
  }

  Future<void> _addNewAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialLocation: _latitude != null && _longitude != null
              ? LatLng(_latitude!, _longitude!)
              : null,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final label = (result['name'] as String?)?.trim() ?? '';
    final line = (result['address'] as String?)?.trim() ?? '';
    final lat = result['lat'] as double?;
    final lng = result['lng'] as double?;
    try {
      final brand = widget.specificBrand ?? ref.read(brandProvider);
      final saved = await AddressService.addAddress(
        label: label.isEmpty ? 'Home' : label,
        addressLine: line,
        latitude: lat,
        longitude: lng,
        isDefault: _savedAddresses.isEmpty,
        brand: brand,
      );
      if (!mounted) return;
      await _fetchSavedAddresses();
      if (saved != null && mounted) setState(() => _selectAddress(saved));
    } catch (e) {
      if (!mounted) return;
      // Saving failed, but let the order proceed with the picked address.
      setState(() {
        _addressController.text = label.isEmpty ? line : '$label, $line';
        _latitude = lat;
        _longitude = lng;
        _selectedAddressId = null;
      });
    }
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
    } catch (_) {
      // Prefilling is a convenience — the user can still pick on the map.
    }
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
    } catch (_) {
      // Falling back to hardcoded charges would quietly show the wrong total,
      // so tell the user the figures below may not be current.
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Couldn't load delivery charges. Pull back and retry.",
          isError: true,
        );
      }
    }
  }

  /// Saved-address book: a list of the customer's saved addresses (radio-style)
  /// plus "Add new address". Falls back to just the map-picker card when there
  /// are none. Wrapped in a FormField so "Address is required" still validates.
  Widget _buildAddressSection() {
    if (_loadingAddresses) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return FormField<String>(
      validator: (_) =>
          _addressController.text.trim().isEmpty ? "Address is required" : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._savedAddresses.map((a) => _buildSavedAddressTile(a, field)),
            SizedBox(height: _savedAddresses.isEmpty ? 0 : 8.h),
            // The picker card (also the "add new" path).
            _buildAddressPickerField(field),
            if (field.hasError)
              Padding(
                padding: EdgeInsets.only(top: 8.h, left: 4.w),
                child: Text(
                  field.errorText!,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.redAccent,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSavedAddressTile(SavedAddress a, FormFieldState<String> field) {
    final selected = _selectedAddressId == a.id;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: TactileButton(
        onTap: () {
          setState(() => _selectAddress(a));
          field.didChange(_addressController.text);
        },
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black.withValues(alpha: 0.08),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black38,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          a.label.isEmpty ? 'Address' : a.label,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (a.isDefault)
                          Padding(
                            padding: EdgeInsets.only(left: 8.w),
                            child: Text(
                              'Default',
                              style: GoogleFonts.poppins(
                                fontSize: 10.sp,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      a.addressLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
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
  }

  /// The "add new address" / pick-on-map card.
  Widget _buildAddressPickerField(FormFieldState<String> field) {
    {
      final hasAddress =
          _selectedAddressId == null && _addressController.text.trim().isNotEmpty;
      // When no saved address is picked but a one-off map address is set, show
      // it here; otherwise this is the "add new" prompt.
      return TactileButton(
        onTap: () async {
          await _addNewAddress();
          field.didChange(_addressController.text);
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: field.hasError
                  ? Colors.redAccent
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_location_alt_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 22.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  hasAddress
                      ? _addressController.text
                      : (_savedAddresses.isEmpty
                            ? "Pick your delivery location on the map"
                            : "Add a new address"),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: hasAddress ? Colors.black87 : Colors.black45,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.black38,
                size: 22.sp,
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _validatingCoupon = true;
      _couponError = null;
    });
    try {
      final brand =
          widget.specificBrand ?? ref.read(brandProvider) ?? 'teasntrees';
      final result = await CouponService.validate(
        code: code,
        orderValue: widget.cart.subtotal,
        brand: brand,
      );
      if (!mounted) return;
      setState(() {
        _appliedCoupon = result.code;
        _couponDiscount = result.discountAmount;
        _validatingCoupon = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validatingCoupon = false;
        _couponError = e.toString().replaceFirst('Exception: ', '');
        _appliedCoupon = null;
        _couponDiscount = 0;
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0;
      _couponError = null;
      _couponController.clear();
    });
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
        latitude: _latitude,
        longitude: _longitude,
        brand: currentBrand,
        items: _isGlobal ? null : itemsPayload,
        couponCode: _appliedCoupon,
      );

      if (result['success'] == true) {
        if (!_isGlobal) {
          for (var item in widget.cart.items) {
            try {
              await ref
                  .read(cartProvider.notifier)
                  .removeItem(item.id, brand: item.brand);
            } catch (_) {
              // The order is already placed; a failed cleanup is corrected by
              // the fetchCart below, which takes the server's cart as truth.
            }
          }
        }

        // Refresh local cart state
        await ref.read(cartProvider.notifier).fetchCart();

        if (mounted) {
          HapticFeedback.mediumImpact(); // a satisfying "done" on order placed
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32.r),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          "Order Placed!",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMultiOrder
                  ? "Your orders have been placed successfully."
                  : "Your order #${orderData['orderNumber'] ?? ''} has been placed successfully.",
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.black87,
              ),
            ),
            if (isMultiOrder) ...[
              SizedBox(height: 16.h),
              ...orders.map(
                (o) => Padding(
                  padding: EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: BoxDecoration(
                          color: o['brand'] == 'teasntrees'
                              ? Color(0xFF57733C)
                              : Color(0xFF8C3414),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "${o['brand'] == 'teasntrees' ? 'Cafe' : 'Bakery'}: #${o['orderNumber']}",
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
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
                  builder: (_) => StoreHomeScreen(initialIndex: 3),
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
                    builder: (_) => StoreHomeScreen(initialIndex: 3),
                  ),
                  (route) => false,
                );
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Text(
                "Track Order",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
    final total = subtotal + _deliveryCharge + tax - _couponDiscount;

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
            fontSize: 20.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isGlobal && widget.cart.itemCount > 0)
                  Container(
                    margin: EdgeInsets.only(bottom: 32),
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28.sp,
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            "We'll separate your orders for each brand to ensure the best experience.",
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              height: 1.4.h,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildSectionTitle("Delivery Address"),
                SizedBox(height: 16.h),
                _buildAddressSection(),

                SizedBox(height: 40.h),

                _buildSectionTitle("Special Instructions"),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _instructionsController,
                  style: GoogleFonts.poppins(fontSize: 14.sp),
                  decoration: _inputDecoration(
                    "e.g. Ring the bell, leave at the gate...",
                  ),
                ),

                SizedBox(height: 40.h),

                _buildSectionTitle("Payment Method"),
                SizedBox(height: 16.h),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.02),
                    ),
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
                            fontSize: 15.sp,
                          ),
                        ),
                        subtitle: Text(
                          "Pay when your order arrives",
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.black38,
                          ),
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 4.h,
                        ),
                      ),
                      Divider(
                        height: 1.h,
                        indent: 20,
                        endIndent: 20,
                        color: Color(0xFFF0F0F0),
                      ),
                      // No payment gateway is wired up yet, so this is shown as
                      // a disabled row rather than a radio that looks selectable
                      // and only ever answers with a "coming soon" snackbar.
                      RadioListTile<String>(
                        value: "Online",
                        groupValue: _paymentMethod,
                        onChanged: null,
                        title: Text(
                          "Online Payment",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                            color: Colors.black38,
                          ),
                        ),
                        subtitle: Text(
                          "UPI, Cards, Netbanking — coming soon",
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.black26,
                          ),
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 4.h,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40.h),

                // Summary
                Container(
                  padding: EdgeInsets.all(28.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.02),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildCouponField(),
                      SizedBox(height: 20.h),
                      _buildSummaryRow(
                        "Item Total",
                        "₹${subtotal.toStringAsFixed(2)}",
                      ),
                      SizedBox(height: 16.h),
                      _buildSummaryRow(
                        "Delivery Fee",
                        "₹${_deliveryCharge.toStringAsFixed(2)}",
                      ),
                      SizedBox(height: 16.h),
                      _buildSummaryRow(
                        "GST ($_gstRate%)",
                        "₹${tax.toStringAsFixed(2)}",
                      ),
                      if (_couponDiscount > 0) ...[
                        SizedBox(height: 16.h),
                        _buildSummaryRow(
                          "Coupon ($_appliedCoupon)",
                          "- ₹${_couponDiscount.toStringAsFixed(2)}",
                          valueColor: Colors.green.shade700,
                        ),
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        child: Divider(color: Color(0xFFF0F0F0)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Grand Total",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "₹${total.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 24.sp,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 48.h),

                TactileButton(
                  onTap: _isLoading ? null : _placeOrder,
                  child: Container(
                    width: double.infinity,
                    height: 52.h,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? SizedBox(
                            height: 24.h,
                            width: 24.w,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isGlobal ? "Place All Orders" : "Confirm Order",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 17.sp,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 48.h),
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
        fontSize: 17.sp,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14.sp, color: Colors.black26),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20.r),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20.r),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20.r),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
    );
  }

  Widget _buildSummaryRow(String label, String amount, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            color: Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.poppins(
            fontSize: 15.sp,
            color: valueColor ?? Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Coupon entry: type a code → Apply → validated against the order value.
  /// Once applied it collapses to a removable chip and the discount shows in the
  /// summary above.
  Widget _buildCouponField() {
    if (_appliedCoupon != null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_offer_rounded,
              color: Colors.green.shade700,
              size: 18.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                "'$_appliedCoupon' applied — you save ₹${_couponDiscount.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ),
            GestureDetector(
              onTap: _removeCoupon,
              child: Text(
                'Remove',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Offers the backend says this customer can actually use — tap to fill
        // the field instead of making them know a code by heart.
        Consumer(
          builder: (context, ref, _) {
            final offers = ref
                .watch(customerStatusProvider)
                .maybeWhen(
                  data: (s) => s.activeOffers,
                  orElse: () => const <String>[],
                );
            if (offers.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: offers
                    .map(
                      (code) => TactileButton(
                        onTap: () {
                          _couponController.text = code;
                          _applyCoupon();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer_rounded,
                                size: 13.sp,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                code,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Coupon code',
                  prefixIcon: Icon(
                    Icons.local_offer_outlined,
                    size: 18.sp,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            ElevatedButton(
              onPressed: _validatingCoupon ? null : _applyCoupon,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: _validatingCoupon
                  ? SizedBox(
                      height: 16.h,
                      width: 16.h,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Apply'),
            ),
          ],
        ),
        if (_couponError != null)
          Padding(
            padding: EdgeInsets.only(top: 8.h, left: 4.w),
            child: Text(
              _couponError!,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.redAccent,
              ),
            ),
          ),
      ],
    );
  }
}
