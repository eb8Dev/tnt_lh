import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tnt_lh/widgets/app_sheets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/core/theme.dart';
import 'package:tnt_lh/models/address_model.dart';
import 'package:tnt_lh/models/cart_model.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/status_provider.dart';
import 'package:tnt_lh/providers/address_provider.dart';
import 'package:tnt_lh/screens/address_book_screen.dart';
import 'package:tnt_lh/screens/address_form_screen.dart';
import 'package:tnt_lh/screens/order_placed_screen.dart';
import 'package:tnt_lh/services/coupon_service.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/utils/formatters.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

/// The bag and checkout, on one page.
///
/// This replaces a Bag *tab* that led to a separate Checkout page. Food apps
/// don't park the cart in the tab bar: it's a bar that appears over the menu
/// once something is in it, and opens one page where you review the items,
/// apply an offer, choose where it goes and pay. Two pages meant entering the
/// address and seeing the real total only after leaving the bag.
///
/// One store at a time. Each store cooks, prices (delivery fee, GST) and
/// delivers its own order, and coupons belong to one store, so a bag holding
/// both shows a switch at the top rather than a merged bill that never quite
/// matched what was charged.
class BagScreen extends ConsumerStatefulWidget {
  /// Open on this store's items, if the bag has any.
  final String? store;

  const BagScreen({super.key, this.store});

  @override
  ConsumerState<BagScreen> createState() => _BagScreenState();
}

class _StorePricing {
  final double deliveryCharge;
  final double gstRate;
  const _StorePricing(this.deliveryCharge, this.gstRate);
}

const _instructionChips = [
  'Ring the bell',
  "Don't ring the bell",
  'Leave at the door',
  'Call when you arrive',
];

class _BagScreenState extends ConsumerState<BagScreen> {
  String? _store;

  /// The line just taken out, kept for a few seconds so it can be put back.
  CartItem? _removed;
  Timer? _undoTimer;

  final Map<String, _StorePricing> _pricing = {};
  bool _pricingFailed = false;

  /// Where this order goes: the "Deliver to" choice shared with the home
  /// header and the address book.
  SavedAddress? get _address => ref.read(addressBookProvider).value?.selected;

  final Set<String> _chips = {};
  final _noteController = TextEditingController();
  final _altPhoneController = TextEditingController();
  bool _showAltPhone = false;
  String? _altPhoneError;

  String? _coupon;
  double _discount = 0;

  bool _placing = false;

  /// Survives retries of one checkout; see OrderService.createOrder. A timeout
  /// after the server already took the order must not let "Place order" create
  /// a second one.
  String? _idempotencyKey;

  @override
  void dispose() {
    _undoTimer?.cancel();
    _noteController.dispose();
    _altPhoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data ---

  Future<void> _loadPricing(String store) async {
    if (_pricing.containsKey(store)) return;
    try {
      final s = await OrderService.getSettings(brand: store);
      if (!mounted) return;
      setState(() {
        _pricing[store] = _StorePricing(
          (s['deliveryCharge'] ?? 50).toDouble(),
          (s['gstRate'] ?? 5).toDouble(),
        );
        _pricingFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _pricingFailed = true);
    }
  }

  // ------------------------------------------------------------- actions ---

  void _switchStore(String store) {
    if (store == _store) return;
    HapticFeedback.selectionClick();
    setState(() {
      _store = store;
      // Coupons and retries belong to one store's order.
      _coupon = null;
      _discount = 0;
      _idempotencyKey = null;
    });
    _loadPricing(store);
  }

  Future<void> _changeQuantity(CartItem item, int quantity) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(cartProvider.notifier);
    if (quantity >= 1) {
      notifier.updateQuantity(item.id, quantity);
      _couponNeedsRecheck();
      return;
    }

    // Taking the last one out removes it; the line disappearing is the
    // confirmation.
    try {
      await notifier.removeItem(item.id, brand: item.brand);
    } catch (_) {
      return; // cartErrorProvider has already said why
    }
    _couponNeedsRecheck();
    if (!mounted) return;
    // An undo strip takes the line's place for a few seconds.
    _undoTimer?.cancel();
    setState(() => _removed = item);
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _removed = null);
    });
  }

  void _undoRemove() {
    final item = _removed;
    if (item == null) return;
    HapticFeedback.selectionClick();
    _undoTimer?.cancel();
    setState(() => _removed = null);
    ref
        .read(cartProvider.notifier)
        .addToCart(
          product: item.product,
          quantity: item.quantity,
          customization: item.customization,
        )
        .catchError((_) {});
    _couponNeedsRecheck();
  }

  Widget? _undoStrip() {
    final r = _removed;
    if (r == null || r.brand != _store) return null;
    return _UndoStrip(name: r.product.name, onUndo: _undoRemove);
  }

  /// The discount was worked out on the old item total; it may no longer hold
  /// (a minimum order, a percentage). Drop it rather than show a wrong bill;
  /// the customer can re-apply in one tap.
  void _couponNeedsRecheck() {
    if (_coupon == null) return;
    setState(() {
      _coupon = null;
      _discount = 0;
    });
  }

  Future<void> _openCoupons(double itemTotal) async {
    final result = await showModalBottomSheet<CouponResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => Theme(
        data: themeFor(_store),
        child: _CouponSheet(store: _store!, itemTotal: itemTotal),
      ),
    );
    if (result == null || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _coupon = result.code;
      _discount = result.discountAmount;
    });
  }

  Future<void> _chooseAddress() async {
    final book = ref.read(addressBookProvider).value;
    // Nothing saved yet: straight to adding one.
    if (book == null || book.addresses.isEmpty) {
      await openAddressEditor(context);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(
          data: themeFor(_store),
          child: const AddressBookScreen(choosing: true),
        ),
      ),
    );
  }

  String get _instructions {
    final parts = [..._chips];
    final note = _noteController.text.trim();
    if (note.isNotEmpty) parts.add(note);
    return parts.join('. ');
  }

  Future<void> _placeOrder(List<CartItem> items) async {
    final address = _address;
    if (address == null) {
      _chooseAddress();
      return;
    }

    final alt = _altPhoneController.text.trim();
    if (alt.isNotEmpty && !RegExp(r'^[0-9]{10}$').hasMatch(alt)) {
      setState(() => _altPhoneError = 'Enter a 10-digit number');
      return;
    }

    setState(() => _placing = true);
    _idempotencyKey ??= _newKey();
    final store = _store!;

    // Ordering for someone else: the rider asks for them and calls them.
    final receiver = [
      address.receiverName,
      address.receiverPhone,
    ].where((x) => x.isNotEmpty).join(', ');
    final instructions = [
      if (receiver.isNotEmpty) 'Deliver to $receiver',
      if (_instructions.isNotEmpty) _instructions,
    ].join('. ');

    try {
      final result = await OrderService.createOrder(
        deliveryAddress: address.fullText,
        deliveryInstructions: instructions,
        alternatePhone: alt.isNotEmpty
            ? alt
            : (address.receiverPhone.isNotEmpty ? address.receiverPhone : null),
        paymentMethod: 'COD',
        latitude: address.latitude,
        longitude: address.longitude,
        brand: store,
        items: [
          for (final i in items)
            {
              'product': i.product.id,
              'quantity': i.quantity,
              'price': i.price,
              'customization': i.customization,
            },
        ],
        couponCode: _coupon,
        idempotencyKey: _idempotencyKey,
      );
      if (result['success'] != true) {
        throw result['message'] ?? "Couldn't place the order";
      }
      _idempotencyKey = null;

      // The order is placed; take its items out of the bag. A failed clean-up
      // is corrected by the refetch, which takes the server's bag as truth.
      final cart = ref.read(cartProvider.notifier);
      for (final i in items) {
        try {
          await cart.removeItem(i.id, brand: i.brand);
        } catch (_) {}
      }
      cart.fetchCart(background: true);

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final data = (result['data'] as Map?)?.cast<String, dynamic>() ?? {};
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, _, _) => OrderPlacedScreen(
            orderId:
                data['orderId']?.toString() ?? data['_id']?.toString() ?? '',
            orderNumber: data['orderNumber']?.toString(),
            store: store,
          ),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      noticeSheet(
        context,
        title: "Couldn't place your order",
        message: errorText(e),
      );
    }
  }

  String _newKey() {
    final rand = Random.secure();
    return List.generate(
      16,
      (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  // ------------------------------------------------------------------ UI ---

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).value;
    final all = cart?.items ?? const <CartItem>[];

    final stores = <String>[
      Brands.cafeKey,
      Brands.bakeryKey,
    ].where((s) => all.any((i) => i.brand == s)).toList();

    // Keep the chosen store while it still has items; otherwise fall back to
    // the requested one, the one being browsed, or whichever has items.
    if (_store == null || !stores.contains(_store)) {
      final wanted = [widget.store, ref.read(brandProvider)];
      final next =
          wanted.firstWhere(stores.contains, orElse: () => null) ??
          stores.firstOrNull;
      if (next != _store) {
        _store = next;
        _coupon = null;
        _discount = 0;
        _idempotencyKey = null;
      }
      if (next != null) _loadPricing(next);
    }

    final items = all.where((i) => i.brand == _store).toList();
    // The bag is about one store, so it wears that store's colours even when
    // the other store is being browsed (a Cream N Crust bag came up green).
    final theme = themeFor(_store);

    return Theme(
      data: theme,
      child: CenteredPage(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your bag',
                  style: GoogleFonts.poppins(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_store != null)
                  Text(
                    Brands.name(_store),
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Empty this bag',
                  icon: Icon(PhosphorIcons.trash(), size: 20.sp),
                  onPressed: () => _confirmClear(_store!),
                ),
            ],
          ),
          body: items.isEmpty
              ? Column(
                  children: [
                    if (_undoStrip() case final strip?)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          Space.md.w,
                          Space.xs.h,
                          Space.md.w,
                          0,
                        ),
                        child: strip,
                      ),
                    Expanded(
                      child: _EmptyBag(onBrowse: () => Navigator.pop(context)),
                    ),
                  ],
                )
              : _buildBody(items, stores, all),
          bottomNavigationBar: items.isEmpty ? null : _buildFooter(items),
        ),
      ),
    );
  }

  Widget _buildBody(
    List<CartItem> items,
    List<String> stores,
    List<CartItem> all,
  ) {
    final pricing = _pricing[_store];
    final itemTotal = items.fold<double>(0, (s, i) => s + i.price * i.quantity);

    // Tapping anywhere outside a field, or scrolling, puts the keyboard away.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          Space.md.w,
          Space.xs.h,
          Space.md.w,
          Space.lg.h,
        ),
        children: [
          if (stores.length > 1) ...[
            _StoreSwitch(
              stores: stores,
              selected: _store!,
              counts: {
                for (final s in stores)
                  s: all
                      .where((i) => i.brand == s)
                      .fold<int>(0, (n, i) => n + i.quantity),
              },
              onSelect: _switchStore,
            ),
            Gap(Space.sm),
          ],
          _Card(
            child: Column(
              children: [
                for (final item in items) ...[
                  _ItemRow(
                    item: item,
                    onChange: (q) => _changeQuantity(item, q),
                  ),
                  if (item != items.last)
                    Divider(height: Space.lg.h, color: Colors.black12),
                ],
                if (_undoStrip() case final strip?) ...[
                  SizedBox(height: Space.sm.h),
                  strip,
                ],
                Divider(height: Space.lg.h, color: Colors.black12),
                _LinkRow(
                  icon: PhosphorIcons.plus(),
                  text: 'Add more items',
                  onTap: () {
                    ref.read(brandProvider.notifier).setBrand(_store!);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          Gap(Space.sm),
          _Card(
            padding: EdgeInsets.zero,
            child: _coupon == null
                ? _LinkRow(
                    padding: EdgeInsets.all(Space.md.r),
                    icon: PhosphorIcons.sealPercent(),
                    text: 'Apply a coupon',
                    trailing: Icon(
                      PhosphorIcons.caretRight(),
                      size: 16.sp,
                      color: Colors.black38,
                    ),
                    onTap: () => _openCoupons(itemTotal),
                  )
                : _AppliedCoupon(
                    code: _coupon!,
                    saving: _discount,
                    onRemove: () => setState(() {
                      _coupon = null;
                      _discount = 0;
                    }),
                  ),
          ),
          Gap(Space.sm),
          _Card(child: _buildInstructions()),
          Gap(Space.sm),
          _Card(
            child: _Bill(
              itemTotal: itemTotal,
              pricing: pricing,
              failed: _pricingFailed,
              discount: _discount,
              coupon: _coupon,
              onRetry: () => _loadPricing(_store!),
            ),
          ),
          Gap(Space.sm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.xs.w),
            child: Text(
              'Orders can be cancelled until the store starts preparing them.',
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                color: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    final primary = themeFor(_store).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Delivery instructions'),
        Gap(Space.xs),
        Wrap(
          spacing: Space.xs.w,
          runSpacing: Space.xs.h,
          children: [
            for (final c in _instructionChips)
              FilterChip(
                label: Text(c),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: _chips.contains(c) ? primary : Colors.black87,
                  fontWeight: _chips.contains(c)
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                selected: _chips.contains(c),
                showCheckmark: false,
                selectedColor: primary.withValues(alpha: 0.10),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _chips.contains(c)
                      ? primary
                      : Colors.black.withValues(alpha: 0.12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                visualDensity: VisualDensity.compact,
                onSelected: (on) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    // Ringing and not ringing can't both apply. (This
                    // compared 'ring' against "Ring the bell", missed the
                    // capital R, and let both be picked.)
                    bool aboutBell(String x) =>
                        x.toLowerCase().contains('ring');
                    if (on && aboutBell(c)) _chips.removeWhere(aboutBell);
                    on ? _chips.add(c) : _chips.remove(c);
                  });
                },
              ),
          ],
        ),
        Gap(Space.sm),
        _CompactField(
          controller: _noteController,
          hint: 'Anything else for the rider? (optional)',
          maxLines: 2,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _showAltPhone
              ? Padding(
                  padding: EdgeInsets.only(top: Space.xs.h),
                  child: _CompactField(
                    controller: _altPhoneController,
                    hint: 'Another number the rider can call',
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    autofocus: true,
                    errorText: _altPhoneError,
                    onChanged: (_) {
                      if (_altPhoneError != null) {
                        setState(() => _altPhoneError = null);
                      }
                    },
                    // Changed your mind: close it and forget the number.
                    onClear: () => setState(() {
                      _showAltPhone = false;
                      _altPhoneController.clear();
                      _altPhoneError = null;
                      FocusManager.instance.primaryFocus?.unfocus();
                    }),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.only(top: Space.xs.h),
                  child: _LinkRow(
                    icon: PhosphorIcons.phonePlus(),
                    text: 'Add another contact number',
                    onTap: () => setState(() => _showAltPhone = true),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFooter(List<CartItem> items) {
    final pricing = _pricing[_store];
    final itemTotal = items.fold<double>(0, (s, i) => s + i.price * i.quantity);
    final toPay = pricing == null
        ? null
        : _Bill.total(itemTotal, pricing, _discount);
    final theme = themeFor(_store);
    final primary = theme.colorScheme.primary;
    final addresses = ref.watch(addressBookProvider);
    final hasAddress = addresses.value?.selected != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Space.md.w,
            Space.sm.h,
            Space.md.w,
            Space.sm.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddressStrip(
                loading: addresses.isLoading && !addresses.hasValue,
                address: addresses.value?.selected,
                onTap: _chooseAddress,
              ),
              Gap(Space.sm),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PAY ON DELIVERY',
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          letterSpacing: 0.6,
                          color: Colors.black45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Cash',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  GapW(Space.md),
                  Expanded(
                    child: TactileButton(
                      onTap: _placing || (toPay == null && hasAddress)
                          ? null
                          : () => _placeOrder(items),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: Sizes.buttonPrimary.h,
                        padding: EdgeInsets.symmetric(horizontal: Space.md.w),
                        decoration: BoxDecoration(
                          color: _placing
                              ? primary.withValues(alpha: 0.7)
                              : primary,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: _placing
                            ? Center(
                                child: SizedBox(
                                  width: 22.r,
                                  height: 22.r,
                                  child:
                                      const CircularProgressIndicator.adaptive(
                                        strokeWidth: 2.4,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                ),
                              )
                            : Row(
                                children: [
                                  if (toPay != null && hasAddress)
                                    _AnimatedAmount(
                                      amount: toPay,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  const Spacer(),
                                  Text(
                                    hasAddress
                                        ? 'Place order'
                                        : 'Add delivery address',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  GapW(Space.xxs),
                                  Icon(
                                    PhosphorIcons.caretRight(
                                      PhosphorIconsStyle.bold,
                                    ),
                                    color: Colors.white,
                                    size: 16.sp,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(String store) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Space.lg.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Empty your ${Brands.name(store)} bag?',
                style: GoogleFonts.poppins(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap(Space.xs),
              Text(
                'Everything from this store will be removed.',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: Colors.black54,
                ),
              ),
              Gap(Space.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep it'),
                    ),
                  ),
                  GapW(Space.sm),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Empty bag'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(cartProvider.notifier).clearCart(brand: store);
    } catch (e) {
      if (!mounted) return;
      noticeSheet(context, message: errorText(e));
    }
  }
}

// ------------------------------------------------------------- pieces ---

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? EdgeInsets.all(Space.md.r),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
    ),
    child: child,
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.poppins(fontSize: 14.sp, fontWeight: FontWeight.w600),
  );
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const _LinkRow({
    required this.icon,
    required this.text,
    required this.onTap,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: primary),
            GapW(Space.xs),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// "Removed X  Undo", in the list where the item was, for a few seconds.
class _UndoStrip extends StatelessWidget {
  final String name;
  final VoidCallback onUndo;
  const _UndoStrip({required this.name, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(12.w, 6.h, 4.w, 6.h),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.trash(), size: 16.sp, color: Colors.black45),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Removed $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: onUndo,
              child: Text(
                'Undo',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onChange;
  const _ItemRow({required this.item, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.customization != null &&
                  item.customization!.isNotEmpty) ...[
                Gap(2),
                Text(
                  item.customization!,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: Colors.black45,
                  ),
                ),
              ],
              Gap(Space.xxs),
              Text(
                AppFormatters.rupees(item.price),
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        GapW(Space.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Stepper(quantity: item.quantity, onChange: onChange),
            Gap(Space.xxs),
            _AnimatedAmount(
              amount: item.price * item.quantity,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A compact − n + control. The number slides up or down as it changes.
class _Stepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChange;
  const _Stepper({required this.quantity, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget button(IconData icon, int to, String label) => Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () => onChange(to),
        borderRadius: BorderRadius.circular(8.r),
        child: SizedBox(
          width: 30.w,
          height: 30.h,
          child: Icon(icon, size: 14.sp, color: primary),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            quantity == 1 ? PhosphorIcons.trash() : PhosphorIcons.minus(),
            quantity - 1,
            quantity == 1 ? 'Remove' : 'One less',
          ),
          SizedBox(
            width: 22.w,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '$quantity',
                key: ValueKey(quantity),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ),
          button(PhosphorIcons.plus(), quantity + 1, 'One more'),
        ],
      ),
    );
  }
}

/// A rupee amount that counts to its new value instead of jumping.
class _AnimatedAmount extends StatelessWidget {
  final double amount;
  final TextStyle style;
  const _AnimatedAmount({required this.amount, required this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: amount),
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) =>
        // Settle on the exact figure; mid-flight values are rounded.
        Text(
          AppFormatters.rupees(v == amount ? amount : v.roundToDouble()),
          style: style,
        ),
  );
}

class _StoreSwitch extends StatelessWidget {
  final List<String> stores;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;

  const _StoreSwitch({
    required this.stores,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Space.xxs.r),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          for (final s in stores)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: s == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: s == selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8.r,
                        height: 8.r,
                        decoration: BoxDecoration(
                          color: Brands.color(s),
                          shape: BoxShape.circle,
                        ),
                      ),
                      GapW(Space.xs),
                      Flexible(
                        child: Text(
                          '${Brands.name(s)} · ${counts[s] ?? 0}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: s == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: s == selected
                                ? Colors.black87
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppliedCoupon extends StatelessWidget {
  final String code;
  final double saving;
  final VoidCallback onRemove;
  const _AppliedCoupon({
    required this.code,
    required this.saving,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final green = Colors.green.shade700;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Padding(
        padding: EdgeInsets.all(Space.md.r),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
              color: green,
              size: 20.sp,
            ),
            GapW(Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You save ${AppFormatters.rupees(saving)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: green,
                    ),
                  ),
                  Text(
                    '$code applied',
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRemove, child: const Text('Remove')),
          ],
        ),
      ),
    );
  }
}

class _Bill extends StatelessWidget {
  final double itemTotal;
  final _StorePricing? pricing;
  final bool failed;
  final double discount;
  final String? coupon;
  final VoidCallback onRetry;

  const _Bill({
    required this.itemTotal,
    required this.pricing,
    required this.failed,
    required this.discount,
    required this.coupon,
    required this.onRetry,
  });

  static double gst(double itemTotal, _StorePricing p) =>
      (itemTotal * p.gstRate / 100 * 100).roundToDouble() / 100;

  static double total(double itemTotal, _StorePricing p, double discount) =>
      max(0, itemTotal + p.deliveryCharge + gst(itemTotal, p) - discount);

  @override
  Widget build(BuildContext context) {
    final p = pricing;
    Widget row(String label, String value, {Color? color, bool bold = false}) =>
        Padding(
          padding: EdgeInsets.symmetric(vertical: 3.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: bold ? 14.sp : 13.sp,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? Colors.black87 : Colors.black54,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: bold ? 14.sp : 13.sp,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? Colors.black87,
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Bill details'),
        Gap(Space.xs),
        row('Item total', AppFormatters.rupees(itemTotal)),
        if (p == null)
          failed
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Couldn't load delivery fee and taxes.",
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                )
              : Padding(
                  padding: EdgeInsets.symmetric(vertical: Space.xs.h),
                  child: const LinearProgressIndicator(minHeight: 2),
                )
        else ...[
          row('Delivery fee', AppFormatters.rupees(p.deliveryCharge)),
          row(
            'GST (${p.gstRate % 1 == 0 ? p.gstRate.toInt() : p.gstRate}%)',
            AppFormatters.rupees(gst(itemTotal, p)),
          ),
          if (discount > 0)
            row(
              'Coupon $coupon',
              '− ${AppFormatters.rupees(discount)}',
              color: Colors.green.shade700,
            ),
          Divider(height: Space.md.h, color: Colors.black12),
          row(
            'To pay',
            AppFormatters.rupees(total(itemTotal, p, discount)),
            bold: true,
          ),
        ],
      ],
    );
  }
}

class _AddressStrip extends StatelessWidget {
  final bool loading;
  final SavedAddress? address;
  final VoidCallback onTap;

  const _AddressStrip({
    required this.loading,
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final title = address != null
        ? 'Delivering to ${address!.label.isEmpty ? 'this address' : address!.label}'
        : 'Where should we deliver?';
    final line = address?.fullText;

    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
            color: primary,
            size: 20.sp,
          ),
          GapW(Space.xs),
          Expanded(
            child: loading
                ? const LinearProgressIndicator(minHeight: 2)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (line != null)
                        Text(
                          line,
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
          Text(
            line == null ? 'Add' : 'Change',
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// Shows an × at the end of the field.
  final VoidCallback? onClear;

  const _CompactField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.autofocus = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
    );
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onChanged: onChanged,
      autofocus: autofocus,
      // A phone keypad has no return key; this puts a Done above it.
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.done,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: GoogleFonts.poppins(fontSize: 13.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black38),
        isDense: true,
        counterText: '',
        errorText: errorText,
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: 'Remove',
                icon: Icon(PhosphorIcons.x(), size: 16.sp),
                onPressed: onClear,
              ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: Space.sm.w,
          vertical: Space.sm.h,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class _EmptyBag extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyBag({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Space.xl.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                padding: EdgeInsets.all(Space.lg.r),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.shoppingBagOpen(),
                  size: 44.sp,
                  color: primary,
                ),
              ),
            ),
            Gap(Space.md),
            Text(
              'Your bag is empty',
              style: GoogleFonts.poppins(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            Gap(Space.xxs),
            Text(
              'Something warm, something sweet. Add a few things you like.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: Colors.black54,
              ),
            ),
            Gap(Space.lg),
            FilledButton(onPressed: onBrowse, child: const Text('Browse menu')),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ sheets ---

class _CouponSheet extends ConsumerStatefulWidget {
  final String store;
  final double itemTotal;
  const _CouponSheet({required this.store, required this.itemTotal});

  @override
  ConsumerState<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<_CouponSheet> {
  final _code = TextEditingController();
  String? _busyCode;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busyCode = code;
      _error = null;
    });
    try {
      final result = await CouponService.validate(
        code: code,
        orderValue: widget.itemTotal,
        brand: widget.store,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busyCode = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref
        .watch(customerStatusProvider)
        .maybeWhen(data: (s) => s.activeOffers, orElse: () => const <String>[]);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Space.md.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coupons',
                style: GoogleFonts.poppins(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap(Space.sm),
              Row(
                children: [
                  Expanded(
                    child: _CompactField(
                      controller: _code,
                      hint: 'Enter a coupon code',
                      errorText: _error,
                    ),
                  ),
                  GapW(Space.xs),
                  FilledButton(
                    onPressed: _busyCode != null
                        ? null
                        : () => _apply(_code.text),
                    child:
                        _busyCode != null &&
                            _busyCode == _code.text.trim().toUpperCase()
                        ? SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Apply'),
                  ),
                ],
              ),
              if (offers.isNotEmpty) ...[
                Gap(Space.md),
                Text(
                  'AVAILABLE FOR YOU',
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
                Gap(Space.xs),
                for (final code in offers)
                  Padding(
                    padding: EdgeInsets.only(bottom: Space.xs.h),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Space.sm.w,
                        vertical: Space.xs.h,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.3),
                        ),
                        color: primary.withValues(alpha: 0.04),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.tag(PhosphorIconsStyle.fill),
                            size: 16.sp,
                            color: primary,
                          ),
                          GapW(Space.xs),
                          Expanded(
                            child: Text(
                              code,
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _busyCode != null
                                ? null
                                : () => _apply(code),
                            child: _busyCode == code
                                ? SizedBox(
                                    width: 14.r,
                                    height: 14.r,
                                    child:
                                        const CircularProgressIndicator.adaptive(
                                          strokeWidth: 2,
                                        ),
                                  )
                                : const Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
