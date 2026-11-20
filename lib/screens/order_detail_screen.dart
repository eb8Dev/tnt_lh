import 'dart:async';
import 'package:tnt_lh/core/responsive.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tnt_lh/widgets/app_sheets.dart';
import 'package:flutter/services.dart';
import 'package:tnt_lh/providers/order_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/core/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tnt_lh/widgets/error_retry_view.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/screens/store_home.dart';
import 'package:tnt_lh/screens/bag_screen.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/orders/order_to_bag.dart';
import 'package:tnt_lh/screens/order_placed_screen.dart';
import 'package:tnt_lh/services/review_service.dart';
import 'package:tnt_lh/components/live_tracking_panel.dart';
import 'package:tnt_lh/screens/address_picker_screen.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/utils/formatters.dart';
import 'package:tnt_lh/payments/online_payment.dart';
import 'package:tnt_lh/providers/socket_provider.dart';
import 'package:tnt_lh/screens/rider_badge_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? brand;
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.brand,
    this.embedded = false,
  });

  /// Shown as the right-hand pane of the orders screen on landscape tablets:
  /// no back button, since the list stays beside it.
  final bool embedded;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Future<Order> _orderFuture;

  /// The last order successfully shown. A live refresh keeps it on screen while
  /// the new copy loads (and if that load fails), instead of blanking the page
  /// to a spinner or an error every time the status moves.
  Order? _shown;

  /// Distance / time to the customer, from the live map.
  final _eta = ValueNotifier<String?>(null);

  /// Whether the page's own top bar is hidden (live view). Kept in state and
  /// updated when the order changes: computed straight from the order, the
  /// bar lagged one load behind, so the live view had two back buttons and
  /// the delivered page none.
  bool _barHidden = false;

  /// While a rider has the order, a phone shows the map-first live view.
  bool _liveLayout(BuildContext context) =>
      !widget.embedded &&
      (_shown?.isRiderPhase ?? false) &&
      MediaQuery.sizeOf(context).width < 760;

  /// While a rider has the order, look again every 15 seconds. Live events
  /// should make this unnecessary, but a missed one (a dropped connection,
  /// a server restart) left the page minutes behind the rider.
  Timer? _livePoll;

  void _syncLivePoll() {
    final live = _shown?.isRiderPhase ?? false;
    if (live && _livePoll == null) {
      _livePoll = Timer.periodic(const Duration(seconds: 15), (_) => _reload());
    } else if (!live && _livePoll != null) {
      _livePoll!.cancel();
      _livePoll = null;
    }
  }

  /// The rider's badge drops in once per order, the first time this page
  /// sees a rider on it. Remembered on the device so it doesn't repeat.
  static const _storage = FlutterSecureStorage();
  static final _badgeShown = <String>{};

  Future<void> _maybeShowBadge(Order order) async {
    final rider = order.riderBadge;
    if (rider == null || !order.isRiderPhase || widget.embedded) return;
    if (!_badgeShown.add(order.id)) return;
    final key = 'rider_badge_seen_${order.id}';
    try {
      if (await _storage.read(key: key) != null) return;
      await _storage.write(key: key, value: '1');
    } catch (_) {
      // Storage unavailable: the in-memory set still stops repeats this session.
    }
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    RiderBadgeScreen.show(
      context,
      rider: rider,
      brand: order.brand,
      pin: order.deliveryOtp,
    );
  }

  @override
  void dispose() {
    _livePoll?.cancel();
    _eta.dispose();
    super.dispose();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const StoreHomeScreen(initialIndex: 0),
        ),
        (route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
  }

  @override
  void didUpdateWidget(covariant OrderDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The tablet layout reuses this screen as a side pane and swaps orders in.
    if (oldWidget.orderId != widget.orderId) {
      _shown = null;
      _orderFuture = _fetchOrder();
    }
  }

  Future<Order> _fetchOrder() =>
      OrderService.getOrderById(widget.orderId, brand: widget.brand);

  /// Re-issues the request so a failed load can recover without restarting.
  // Braces matter: `setState(() => _orderFuture = ...)` hands setState the
  // Future, which Flutter rejects with an error, so the screen never
  // refreshed (after a cancel, a live status change or a pull to refresh).
  void _reload() {
    if (!mounted) return;
    setState(() {
      _orderFuture = _fetchOrder();
    });
  }

  /// This screen used to load once and never again: the store accepted the
  /// order, the rider picked it up, and the status and timeline here stayed
  /// exactly where they were (while a pop-up announced the change on top).
  void _listenForLiveChanges() {
    ref.listen<SocketEvent?>(socketEventsProvider, (_, event) {
      if (event == null) return;
      final data = event.data;
      // The journey event carries a version: only a newer state reloads.
      if (event.name == 'order:update' && data is Map) {
        final id = data['orderId']?.toString();
        final v = (data['stageVersion'] as num?)?.toInt() ?? 0;
        debugPrint('[live] order:update $id -> ${data['stage']} v$v');
        if (id == widget.orderId && v > (_shown?.stageVersion ?? -1)) _reload();
        return;
      }
      if (event.name != 'order:status-updated') return;
      final id = data is Map ? data['orderId']?.toString() : null;
      debugPrint(
        '[live] order:status-updated $id -> ${data is Map ? data['status'] : '?'}',
      );
      if (id == widget.orderId) _reload();
    });
    // Back from the background, or the connection was restored.
    ref.listen<int>(liveRefreshProvider, (_, _) => _reload());
  }

  /// Edit-address is allowed until the rider picks up; report-issue appears once
  /// the order is dispatched (a rider is in play).
  Widget _buildOrderActions(Order order) {
    final status = order.status.toLowerCase();
    // The server's spelling is out_for_delivery; checking only the hyphenated
    // one left "Edit address" on while the rider was already on the way.
    const addressLocked = {
      'out_for_delivery',
      'out-for-delivery',
      'in_transit',
      'delivered',
      'cancelled',
    };
    const dispatched = {
      'assigned',
      'out_for_delivery',
      'out-for-delivery',
      'in_transit',
      'arrived',
    };
    final canEditAddress = !addressLocked.contains(status);
    final canReport = dispatched.contains(status);
    final isDelivered = status == 'delivered' || status == 'completed';
    final isCancelled = status == 'cancelled';
    final canReorder = isDelivered || isCancelled;
    // The server allows it only until the store accepts the order.
    final canCancel = status == 'pending' || status == 'awaiting_payment';
    final awaitingPayment = status == 'awaiting_payment';

    final buttons = <Widget>[
      if (awaitingPayment)
        _actionButton(
          label: 'Pay now',
          icon: PhosphorIcons.creditCard(),
          color: Theme.of(context).colorScheme.primary,
          onPressed: () => _payNow(order),
        ),
      if (canCancel)
        _actionButton(
          label: 'Cancel order',
          icon: PhosphorIcons.xCircle(),
          color: Colors.redAccent.shade400,
          onPressed: () => _cancelOrder(order),
        ),
      if (canEditAddress)
        _actionButton(
          label: 'Edit address',
          icon: PhosphorIcons.mapPinLine(),
          color: Theme.of(context).colorScheme.primary,
          onPressed: () => _editAddress(order),
        ),
      if (canReport)
        _actionButton(
          label: 'Report issue',
          icon: PhosphorIcons.warning(),
          color: Colors.redAccent.shade400,
          onPressed: () => _reportIssue(order),
        ),
      if (canReorder)
        _actionButton(
          label: 'Order again',
          icon: PhosphorIcons.arrowCounterClockwise(),
          color: Theme.of(context).colorScheme.primary,
          onPressed: () => _reorder(order),
        ),
      if (isDelivered)
        _actionButton(
          label: 'Invoice',
          icon: PhosphorIcons.receipt(),
          color: Colors.black87,
          onPressed: () => _downloadInvoice(order),
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 8.h,
        children: buttons.map((b) => SizedBox(width: 160.w, child: b)).toList(),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18.sp),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  /// Pay an order that's waiting for its online payment.
  Future<void> _payNow(Order order) async {
    final brand = widget.brand ?? order.brand;
    await completePayment(context, orderIds: [order.id], brand: brand);
    if (mounted) _reload();
  }

  static const _cancelReasons = [
    'Ordered by mistake',
    'Want to change the items',
    'Wrong delivery address',
    'Ordered from the wrong store',
    'It is taking too long',
    'Something else',
  ];

  /// Asks why, then cancels. Picking a reason is the confirmation; closing
  /// the sheet keeps the order.
  Future<void> _cancelOrder(Order order) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you cancelling?',
                style: GoogleFonts.poppins(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                "The store hasn't accepted it yet, so it can still be cancelled.",
                style: GoogleFonts.poppins(
                  fontSize: 12.5.sp,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8.h),
              for (final r in _cancelReasons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(r, style: GoogleFonts.poppins(fontSize: 14.sp)),
                  trailing: Icon(
                    PhosphorIcons.caretRight(),
                    size: 16.sp,
                    color: Colors.black38,
                  ),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              SizedBox(height: 6.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Keep my order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;

    // Try to save the order first: most reasons have a fix that's better
    // than starting over. Closing the sheet keeps the order.
    final fix = await _offerFix(order, reason);
    if (fix == null || fix == _CancelFix.keep || !mounted) return;
    switch (fix) {
      case _CancelFix.editAddress:
        await _editAddress(order);
        return;
      case _CancelFix.call:
        await _callStore(order);
        return;
      default:
        break;
    }

    HapticFeedback.mediumImpact();
    try {
      await OrderService.cancelOrder(
        orderId: order.id,
        reason: reason,
        brand: order.brand,
      );
    } catch (e) {
      // Most likely the store accepted it a moment ago; the refresh shows
      // where the order actually stands.
      if (mounted) {
        noticeSheet(context, title: "Couldn't cancel", message: errorText(e));
      }
      _reload();
      return;
    }
    _reload();
    ref.invalidate(orderProvider);
    if (!mounted) return;

    if (fix == _CancelFix.editItems) {
      final skipped = await addOrderToBag(ref, order);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BagScreen(store: order.brand)),
      );
      if (skipped > 0 && mounted) {
        noticeSheet(
          context,
          isError: false,
          title: 'Your items are in the bag',
          message:
              '$skipped ${skipped == 1 ? "item isn't" : "items aren't"} on the menu right now, so we left ${skipped == 1 ? 'it' : 'them'} out.',
        );
      }
    } else if (fix == _CancelFix.switchStore) {
      final other = Brands.isBakery(order.brand)
          ? Brands.cafeKey
          : Brands.bakeryKey;
      await ref.read(brandProvider.notifier).setBrand(other);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const StoreHomeScreen(initialIndex: StoreHomeScreen.homeTab),
        ),
        (route) => false,
      );
    }
  }

  /// The fix for a reason to cancel, offered before cancelling.
  Future<_CancelFix?> _offerFix(Order order, String reason) {
    final online =
        order.paymentMethod == 'Online' && order.paymentStatus == 'paid';
    final refund = online
        ? ' Your ${AppFormatters.rupees(order.total)} goes back to how you paid, in 5 to 7 working days.'
        : '';
    const cancel = SheetChoice(
      _CancelFix.cancel,
      'Cancel the order',
      destructive: true,
    );
    const keep = SheetChoice(_CancelFix.keep, 'Keep my order');
    final store = Brands.name(order.brand);
    final otherStore = Brands.name(
      Brands.isBakery(order.brand) ? Brands.cafeKey : Brands.bakeryKey,
    );

    switch (reason) {
      case 'Wrong delivery address':
        return choiceSheet(
          context,
          icon: PhosphorIcons.mapPin(),
          title: 'Change the address instead?',
          message:
              "Your order hasn't left the store, so you can move it to the right place and keep everything else.",
          choices: [
            const SheetChoice(
              _CancelFix.editAddress,
              'Change the address',
              primary: true,
            ),
            cancel,
          ],
        );
      case 'Want to change the items':
        return choiceSheet(
          context,
          icon: PhosphorIcons.pencilSimple(),
          title: 'Edit it in your bag',
          message:
              "We'll cancel this one and put the same items in your bag, so you can change them and order again.$refund",
          choices: [
            const SheetChoice(
              _CancelFix.editItems,
              'Cancel and edit in bag',
              primary: true,
            ),
            keep,
          ],
        );
      case 'Ordered from the wrong store':
        return choiceSheet(
          context,
          icon: PhosphorIcons.storefront(),
          title: 'Order from $otherStore instead?',
          message:
              "We'll cancel this $store order and take you to $otherStore.$refund",
          choices: [
            SheetChoice(
              _CancelFix.switchStore,
              'Cancel and go to $otherStore',
              primary: true,
            ),
            keep,
          ],
        );
      case 'It is taking too long':
        return choiceSheet(
          context,
          icon: PhosphorIcons.clock(),
          title: "The store hasn't seen it yet",
          message:
              'Orders are usually accepted within a few minutes. A call to $store often speeds it up.',
          choices: [
            SheetChoice(_CancelFix.call, 'Call $store', primary: true),
            keep,
            cancel,
          ],
        );
      default:
        return choiceSheet(
          context,
          icon: PhosphorIcons.xCircle(),
          title: 'Cancel this order?',
          message: "The store hasn't accepted it yet.$refund",
          choices: [
            const SheetChoice(
              _CancelFix.cancel,
              'Cancel the order',
              primary: true,
              destructive: true,
            ),
            keep,
          ],
        );
    }
  }

  Future<void> _callStore(Order order) async {
    final settings = await OrderService.getSettings(brand: order.brand);
    final phone = (settings['contactPhone'] ?? '').toString().trim();
    if (!mounted) return;
    if (phone.isEmpty) {
      noticeSheet(context, message: "We couldn't find the store's number.");
      return;
    }
    HapticFeedback.selectionClick();
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _editAddress(Order order) async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const AddressPickerScreen()),
    );
    if (picked == null || !mounted) return;

    final label = (picked['name'] as String?)?.trim() ?? '';
    final addr = (picked['address'] as String?)?.trim() ?? '';
    final fullAddress = label.isEmpty ? addr : '$label, $addr';

    try {
      await OrderService.updateAddress(
        orderId: order.id,
        address: fullAddress,
        latitude: picked['lat'] as double?,
        longitude: picked['lng'] as double?,
        brand: order.brand,
      );
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: 'Delivery address updated.',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _reorder(Order order) async {
    final confirm = await confirmSheet(
      context,
      title: 'Order this again?',
      message:
          'The same items, delivered to your last address, paid cash on '
          'delivery.',
      confirmLabel: 'Place order',
      cancelLabel: 'Not now',
      icon: PhosphorIcons.arrowCounterClockwise(),
    );
    if (!confirm || !mounted) return;

    try {
      final result = await OrderService.reorder(
        orderId: order.id,
        brand: order.brand,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // The same "order placed" moment as checkout, then on to the new order.
      // This read only '_id', but the server sends 'orderId', so nothing
      // happened on screen after the sheet closed.
      final data = (result['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final newId =
          (data['orderId'] ?? data['_id'] ?? data['id'])?.toString() ?? '';
      if (newId.isEmpty) {
        _reload();
        return;
      }
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, _, _) => OrderPlacedScreen(
            orderId: newId,
            orderNumber: data['orderNumber']?.toString(),
            store: order.brand,
          ),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _downloadInvoice(Order order) async {
    SnackBarUtils.showThemedSnackBar(
      context: context,
      message: 'Preparing invoice…',
    );
    try {
      final bytes = await OrderService.fetchInvoice(
        orderId: order.id,
        brand: order.brand,
      );
      if (!mounted) return;
      // Hand the PDF to the OS share/save sheet (no path_provider needed).
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              mimeType: 'application/pdf',
              name: 'invoice-${order.orderNumber}.pdf',
            ),
          ],
          fileNameOverrides: ['invoice-${order.orderNumber}.pdf'],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _reportIssue(Order order) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => _ReportIssueSheet(order: order),
    );
    if (submitted == true && mounted) {
      noticeSheet(
        context,
        isError: false,
        title: 'Issue reported',
        message: 'Our team will look into it and get back to you.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _listenForLiveChanges();

    return CenteredPage(
      // Room for the two-column layout on landscape tablets.
      maxWidth: Responsive.isExpanded(context) ? 1100 : 640,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _barHidden
            ? null
            : AppBar(
                title: Text(
                  'Order details',
                  style: GoogleFonts.poppins(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                centerTitle: true,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: Colors.grey[50],
                foregroundColor: Colors.black,
                // Always give a way out. When this screen is the only route (e.g. opened
                // straight from a notification), the automatic back button vanishes and
                // the customer is trapped — so fall back to the home menu.
                automaticallyImplyLeading: !widget.embedded,
                leading: widget.embedded
                    ? null
                    : IconButton(
                        icon: Icon(PhosphorIcons.caretLeft()),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const StoreHomeScreen(initialIndex: 0),
                              ),
                              (route) => false,
                            );
                          }
                        },
                      ),
              ),
        body: FutureBuilder<Order>(
          future: _orderFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              _shown = snapshot.data;
              final shown = _shown!;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _maybeShowBadge(shown),
              );
            }
            _syncLivePoll();
            final live = _liveLayout(context);
            if (live != _barHidden) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _barHidden = live);
              });
            }
            // A refresh in progress, or one that failed, keeps the last order
            // on screen. Only a first load shows the spinner or the error.
            if (_shown == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator.adaptive());
              }
              if (snapshot.hasError) {
                return ErrorRetryView(error: snapshot.error!, onRetry: _reload);
              }
              if (!snapshot.hasData) {
                return Center(child: Text("Order not found"));
              }
            }

            final order = _shown!;
            // Show tracking for ANY active post-dispatch state. The order's own
            // status lagged the live delivery, and delivery-only statuses
            // ('arrived', 'heading_to_pickup') never appeared on the order — so
            // the map vanished right when the rider was arriving. Gate by "not a
            // pre-dispatch or terminal state" instead; the panel self-hides if no
            // active delivery is found.
            const nonTrackable = {
              'pending',
              'confirmed',
              'preparing',
              'ready',
              'waiting_for_rider',
              'delivered',
              'cancelled',
            };
            final isTrackable = !nonTrackable.contains(
              order.status.toLowerCase(),
            );
            final status = order.status.toLowerCase();
            final finished = {
              'delivered',
              'completed',
              'cancelled',
              'rejected',
              'refunded',
            }.contains(status);
            final delivered = status == 'delivered' || status == 'completed';
            final storeTheme = themeFor(order.brand);
            final primary = storeTheme.colorScheme.primary;

            final statusPart = <Widget>[
              _OrderHeader(order: order, color: primary),
              Gap(Space.sm),
              if (isTrackable) ...[LiveTrackingPanel(order: order)],
              if (order.timeline.isNotEmpty) ...[
                _buildSection(
                  child: _Timeline(
                    order: order,
                    color: primary,
                    // Open while it's happening; folded away once it's done.
                    collapsed: finished,
                  ),
                ),
                Gap(Space.sm),
              ],
            ];
            final itemsPart = <Widget>[
              _buildSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      '${order.items.fold<int>(0, (n, i) => n + i.quantity)} '
                      '${order.items.fold<int>(0, (n, i) => n + i.quantity) == 1 ? 'item' : 'items'}',
                    ),
                    Gap(Space.xs),
                    for (final item in order.items)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 6.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(top: 1.h),
                              // Fixed width so item names line up.
                              width: 30.w,
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(vertical: 1.h),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.r),
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                '${item.quantity}×',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                            ),
                            GapW(Space.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if ((item.customization ?? '').isNotEmpty)
                                    Text(
                                      item.customization!,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black45,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              AppFormatters.rupees(item.price * item.quantity),
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Divider(height: Space.lg.h, color: Colors.black12),
                    _billRow('Item total', order.subtotal),
                    _billRow('Delivery fee', order.deliveryCharge),
                    _billRow('GST', order.tax),
                    if (order.discount > 0)
                      _billRow(
                        order.couponCode == null
                            ? 'Discount'
                            : 'Coupon ${order.couponCode}',
                        -order.discount,
                        color: Colors.green.shade700,
                      ),
                    Divider(height: Space.md.h, color: Colors.black12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            switch (order.paymentStatus) {
                              'refunded' || 'refund_pending' => 'Refund',
                              'paid' => 'Paid',
                              _ =>
                                delivered
                                    ? 'Paid'
                                    : order.status == 'cancelled'
                                    ? 'Order total'
                                    : 'To pay',
                            },
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          AppFormatters.rupees(order.total),
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Gap(Space.xxs),
                    Text(
                      order.paymentMethod.toUpperCase() == 'COD'
                          ? (delivered
                                ? 'Paid in cash on delivery'
                                : 'Cash on delivery')
                          : switch (order.paymentStatus) {
                              'paid' => 'Paid online',
                              'refund_pending' =>
                                'Refund on its way to your account',
                              'refunded' => 'Refunded to your account',
                              _ => 'Waiting for your payment',
                            },
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(Space.sm),
              if (order.deliveryAddress != null) ...[
                _buildSection(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                        size: 18.sp,
                        color: primary,
                      ),
                      GapW(Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              delivered ? 'Delivered to' : 'Delivering to',
                            ),
                            Gap(2),
                            Text(
                              order.deliveryAddress!.address,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(Space.sm),
              ],
              if (delivered) ...[
                _RateOrderSection(order: order),
                Gap(Space.sm),
              ],
              _buildOrderActions(order),
              Gap(Space.xl),
            ];

            if (_liveLayout(context)) {
              return Theme(
                data: storeTheme,
                child: _LiveOrderView(
                  order: order,
                  eta: _eta,
                  details: itemsPart,
                  onBack: _goBack,
                ),
              );
            }

            return Theme(
              data: storeTheme,
              child: RefreshIndicator.adaptive(
                onRefresh: () async {
                  _reload();
                  try {
                    await _orderFuture;
                  } catch (_) {
                    // The order stays on screen; nothing else to do.
                  }
                },
                child: LayoutBuilder(
                  builder: (context, box) {
                    Widget column(List<Widget> children) =>
                        SingleChildScrollView(
                          padding: EdgeInsets.all(16.r),
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: children,
                          ),
                        );
                    // Wide enough (landscape tablet, or the pane beside the
                    // orders list): status on the left, items and bill right.
                    if (box.maxWidth >= 760) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: column(statusPart)),
                          Expanded(child: column(itemsPart)),
                        ],
                      );
                    }
                    return column([...statusPart, ...itemsPart]);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _billRow(String label, double value, {Color? color}) => Padding(
    padding: EdgeInsets.symmetric(vertical: 2.h),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.black54),
          ),
        ),
        Text(
          value < 0
              ? '− ${AppFormatters.rupees(-value)}'
              : AppFormatters.rupees(value),
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    ),
  );

  Widget _buildSection({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

/// Bottom sheet to report an order issue: pick a reason + optional note. Shows a
/// busy state and returns true on success so the caller can confirm.
class _ReportIssueSheet extends StatefulWidget {
  final Order order;
  const _ReportIssueSheet({required this.order});

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  static const _reasons = <String, String>{
    'rider_unreachable': 'Rider unreachable',
    'item_wrong_missing': 'Item wrong or missing',
    'long_delay': 'Long delay',
    'other': 'Something else',
  };

  String? _reason;
  final _notesController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = 'Please choose what went wrong.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OrderService.raiseComplaint(
        orderId: widget.order.id,
        reason: _reason!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        brand: widget.order.brand,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          Text(
            'Report an issue',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.h),
          Text(
            'Order #${widget.order.orderNumber}',
            style: TextStyle(fontSize: 12.sp, color: Colors.black45),
          ),
          SizedBox(height: 12.h),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) {
              if (_busy) return;
              setState(() {
                _reason = v;
                _error = null;
              });
            },
            child: Column(
              children: [
                for (final e in _reasons.entries)
                  RadioListTile<String>(
                    value: e.key,
                    enabled: !_busy,
                    title: Text(e.value, style: TextStyle(fontSize: 14.sp)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _notesController,
            enabled: !_busy,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: 'Add details (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
              ),
            ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _busy
                  ? SizedBox(
                      height: 18.h,
                      width: 18.h,
                      child: const CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rate a delivered order — food + rider stars + an optional note. Collapses to
/// a "thanks" state once submitted (or if the order already carries a rating).
class _RateOrderSection extends StatefulWidget {
  final Order order;
  const _RateOrderSection({required this.order});

  @override
  State<_RateOrderSection> createState() => _RateOrderSectionState();
}

class _RateOrderSectionState extends State<_RateOrderSection> {
  int _foodRating = 0;
  int _riderRating = 0;
  final _commentController = TextEditingController();
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // If the order already has a rating, show the submitted state.
    if ((widget.order.foodRating ?? 0) > 0) {
      _done = true;
      _foodRating = (widget.order.foodRating ?? 0).round();
      _riderRating = (widget.order.riderRating ?? 0).round();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_foodRating == 0 || _riderRating == 0) {
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: 'Please rate both the food and the rider.',
        isError: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ReviewService.submitOrderReview(
        orderId: widget.order.id,
        foodRating: _foodRating,
        riderRating: _riderRating,
        review: _commentController.text.trim(),
        brand: widget.order.brand,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Widget _stars(int value, ValueChanged<int> onChanged) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: _done || _busy ? null : () => onChanged(i + 1),
          child: Padding(
            padding: EdgeInsets.only(left: 4.w),
            // A little pop as each star fills.
            child: TweenAnimationBuilder<double>(
              key: ValueKey('$i-$filled'),
              tween: Tween(begin: filled ? 0.6 : 1, end: 1),
              duration: Duration(milliseconds: 300 + i * 40),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Icon(
                filled
                    ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                    : PhosphorIcons.star(),
                color: filled ? const Color(0xFFF5A623) : Colors.black26,
                size: 24.sp,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _done ? 'Thanks for your feedback!' : 'How was it?',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Food', style: GoogleFonts.poppins(fontSize: 13.sp)),
              _stars(_foodRating, (v) => setState(() => _foodRating = v)),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery', style: GoogleFonts.poppins(fontSize: 13.sp)),
              _stars(_riderRating, (v) => setState(() => _riderRating = v)),
            ],
          ),
          if (!_done) ...[
            SizedBox(height: 12.h),
            TextField(
              controller: _commentController,
              enabled: !_busy,
              maxLines: 2,
              minLines: 1,
              style: GoogleFonts.poppins(fontSize: 13.sp),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                hintText: 'Tell us more (optional)',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: Colors.black38,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                ),
                contentPadding: EdgeInsets.all(12.r),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 11.h),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _busy
                    ? SizedBox(
                        height: 18.h,
                        width: 18.h,
                        child: const CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Submit rating'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w600),
  );
}

/// Store, order number, status, and how it went: "Delivered in 41 min".
class _OrderHeader extends StatelessWidget {
  final Order order;
  final Color color;
  const _OrderHeader({required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    final status = order.status.toLowerCase();
    final statusColor = AppFormatters.getStatusColor(order.displayStatus);
    final placed = DateTime.tryParse(order.createdAt ?? '')?.toLocal();
    final done = DateTime.tryParse(order.deliveredAt ?? '')?.toLocal();
    String? summary;
    if ((status == 'delivered' || status == 'completed') &&
        placed != null &&
        done != null) {
      summary = 'Delivered in ${done.difference(placed).inMinutes} min';
    } else if (status == 'cancelled') {
      summary = AppFormatters.customerNote(order.cancelReason) ?? 'Cancelled';
    }

    return Container(
      padding: EdgeInsets.all(Space.md.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Image.asset(Brands.logo(order.brand), fit: BoxFit.contain),
          ),
          GapW(Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Brands.name(order.brand),
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '#${order.orderNumber} · ${AppFormatters.formatDateTimeFull(order.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: Colors.black54,
                  ),
                ),
                if (summary != null)
                  Text(
                    summary,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              AppFormatters.statusLabel(order.displayStatus),
              style: GoogleFonts.poppins(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 11.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The order's progress. Done steps in the store colour, the latest one
/// highlighted; a step's note only when it says something the title doesn't
/// ("Delivered / Delivered" read as a glitch).
class _Timeline extends StatefulWidget {
  final Order order;
  final Color color;
  final bool collapsed;
  const _Timeline({
    required this.order,
    required this.color,
    required this.collapsed,
  });

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  late bool _open = !widget.collapsed;

  @override
  Widget build(BuildContext context) {
    final steps = widget.order.timeline.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              const Expanded(child: _SectionTitle('Order timeline')),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  PhosphorIcons.caretDown(),
                  size: 16.sp,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: EdgeInsets.only(top: Space.sm.h),
                  child: Column(
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        _step(
                          steps[i],
                          latest: i == 0,
                          last: i == steps.length - 1,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _step(OrderTimeline t, {required bool latest, required bool last}) {
    final label = AppFormatters.statusLabel(t.status);
    final note = AppFormatters.customerNote(t.description);
    final showNote =
        note != null && note.trim().toLowerCase() != label.toLowerCase();
    final cancelled = t.status.toLowerCase() == 'cancelled';
    final dot = cancelled ? Colors.red.shade400 : widget.color;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16.w,
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 4.h),
                  width: latest ? 12.r : 8.r,
                  height: latest ? 12.r : 8.r,
                  decoration: BoxDecoration(
                    color: latest ? dot : dot.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    boxShadow: latest
                        ? [
                            BoxShadow(
                              color: dot.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: widget.color.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          GapW(Space.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Space.sm.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: latest
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: latest ? Colors.black87 : Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        _time(t.timestamp),
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  if (showNote)
                    Text(
                      note,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.black45,
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

  /// "11:52 PM": the day is in the header already.
  String _time(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

// ------------------------------------------------------------ live view ---

/// While a rider has the order: the map fills the screen and a sheet you can
/// drag up holds what is happening (headline, progress, PIN, rider), then the
/// order itself. Modelled on how Rapido and Zomato track a trip.
class _LiveOrderView extends StatelessWidget {
  final Order order;
  final ValueNotifier<String?> eta;
  final List<Widget> details;
  final VoidCallback onBack;

  const _LiveOrderView({
    required this.order,
    required this.eta,
    required this.details,
    required this.onBack,
  });

  static const _initial = 0.46;

  int get _step {
    switch (order.displayStatus.toLowerCase()) {
      case 'arrived_at_pickup':
      case 'at_store':
        return 1;
      case 'picked_up':
      case 'out-for-delivery':
        return 2; // has the order, not yet riding to the customer
      case 'in_transit':
      case 'on_the_way':
        return 3;
      case 'arrived':
        return 4;
      default:
        return 0; // assigned, accepted, heading to the store
    }
  }

  ({String title, String sub}) get _headline {
    final rider = (order.riderName ?? '').split(' ').first;
    final who = rider.isEmpty ? 'Your rider' : rider;
    switch (order.displayStatus.toLowerCase()) {
      case 'heading_to_pickup':
        return (
          title: 'Heading to the store',
          sub: '$who is on the way to pick up your order',
        );
      case 'arrived_at_pickup':
      case 'at_store':
        return (title: 'At the store', sub: '$who is collecting your order');
      case 'picked_up':
      case 'out-for-delivery':
        return (
          title: 'Order picked up',
          sub: '$who will set off towards you shortly',
        );
      case 'in_transit':
      case 'on_the_way':
        return (title: 'On the way to you', sub: '$who has your order');
      case 'arrived':
        return (
          title: "Your rider's here",
          sub: 'Share the PIN below to collect your order',
        );
      default:
        return (
          title: 'Rider assigned',
          sub: '$who will pick up your order soon',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final h = _headline;
    final showPin = (order.deliveryOtp ?? '').isNotEmpty && _step >= 2;

    return Stack(
      children: [
        Positioned.fill(
          child: LiveTrackingPanel(
            order: order,
            fullBleed: true,
            eta: eta,
            mapBottomPadding: media.size.height * (_initial - 0.04),
          ),
        ),
        Positioned(
          top: media.padding.top + 8.h,
          left: 12.w,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            shadowColor: Colors.black26,
            child: IconButton(
              icon: Icon(PhosphorIcons.caretLeft(), color: Colors.black87),
              onPressed: onBack,
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: _initial,
          minChildSize: 0.28,
          maxChildSize: 0.94,
          snap: true,
          snapSizes: const [_initial],
          builder: (context, controller) => DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 18,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(
                16.w,
                8.h,
                16.w,
                24.h + media.padding.bottom,
              ),
              children: [
                Center(
                  child: Container(
                    width: 38.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    h.title,
                                    key: ValueKey(h.title),
                                    style: GoogleFonts.poppins(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  h.sub,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5.sp,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_step == 3)
                            ValueListenableBuilder<String?>(
                              valueListenable: eta,
                              builder: (_, v, _) => v == null
                                  ? const SizedBox.shrink()
                                  : Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                      ),
                                      child: Text(
                                        v,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: primary,
                                        ),
                                      ),
                                    ),
                            ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      _StepBar(step: _step, color: primary),
                      if (showPin) ...[
                        SizedBox(height: 14.h),
                        _PinStrip(pin: order.deliveryOtp!, color: primary),
                      ],
                      SizedBox(height: 14.h),
                      Divider(
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                      SizedBox(height: 12.h),
                      _RiderRow(
                        name: order.riderName,
                        phone: order.riderPhone,
                        color: primary,
                        onOpen: order.riderBadge == null
                            ? null
                            : () => RiderBadgeScreen.show(
                                context,
                                rider: order.riderBadge!,
                                brand: order.brand,
                                pin: order.deliveryOtp,
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                ...details,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Five steps: assigned, at the store, picked up, on the way, arrived.
class _StepBar extends StatelessWidget {
  final int step;
  final Color color;
  const _StepBar({required this.step, required this.color});

  static const _labels = [
    'Assigned',
    'At store',
    'Picked up',
    'On the way',
    'Arrived',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: i <= step ? 1 : 0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3.r),
                    child: LinearProgressIndicator(
                      value: t,
                      minHeight: 5.h,
                      backgroundColor: Colors.black.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ),
              if (i < _labels.length - 1) SizedBox(width: 4.w),
            ],
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: Text(
                  _labels[i],
                  textAlign: i == 0
                      ? TextAlign.start
                      : i == _labels.length - 1
                      ? TextAlign.end
                      : TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                    color: i <= step ? Colors.black87 : Colors.black38,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PinStrip extends StatelessWidget {
  final String pin;
  final Color color;
  const _PinStrip({required this.pin, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.lockKey(PhosphorIconsStyle.fill),
            color: color,
            size: 20.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Delivery PIN, share it with the rider',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            pin.split('').join(' '),
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  final String? name;
  final String? phone;
  final Color color;
  final VoidCallback? onOpen;
  const _RiderRow({
    required this.name,
    required this.phone,
    required this.color,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final n = (name ?? '').trim();
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(12.r),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(
                    n.isEmpty ? '?' : n[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.isEmpty ? 'Your rider' : n,
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        onOpen == null
                            ? 'Delivery partner'
                            : 'Delivery partner · See ID',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5.sp,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if ((phone ?? '').isNotEmpty)
          Material(
            color: color,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Call rider',
              icon: Icon(
                PhosphorIcons.phone(PhosphorIconsStyle.fill),
                color: Colors.white,
                size: 20.sp,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
          ),
      ],
    );
  }
}

/// What to do instead of (or as well as) cancelling.
enum _CancelFix { keep, cancel, editAddress, editItems, switchStore, call }
