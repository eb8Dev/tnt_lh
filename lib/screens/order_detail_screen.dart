import 'package:flutter/material.dart';
import 'package:tnt_lh/widgets/error_retry_view.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/components/live_tracking_panel.dart';
import 'package:tnt_lh/screens/address_picker_screen.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/utils/formatters.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? brand;
  const OrderDetailScreen({super.key, required this.orderId, this.brand});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Future<Order> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
  }

  Future<Order> _fetchOrder() =>
      OrderService.getOrderById(widget.orderId, brand: widget.brand);

  /// Re-issues the request so a failed load can recover without restarting.
  void _reload() => setState(() => _orderFuture = _fetchOrder());

  /// Edit-address is allowed until the rider picks up; report-issue appears once
  /// the order is dispatched (a rider is in play).
  Widget _buildOrderActions(Order order) {
    final status = order.status.toLowerCase();
    const addressLocked = {
      'out-for-delivery',
      'in_transit',
      'delivered',
      'cancelled',
    };
    const dispatched = {
      'assigned',
      'out-for-delivery',
      'in_transit',
      'arrived',
    };
    final canEditAddress = !addressLocked.contains(status);
    final canReport = dispatched.contains(status);

    if (!canEditAddress && !canReport) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          if (canEditAddress)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _editAddress(order),
                icon: Icon(Icons.edit_location_alt_outlined, size: 18.sp),
                label: const Text('Edit address'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          if (canEditAddress && canReport) SizedBox(width: 12.w),
          if (canReport)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _reportIssue(order),
                icon: Icon(Icons.report_gmailerrorred_outlined, size: 18.sp),
                label: const Text('Report issue'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent.shade400,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: 'Reported. Our team will look into it.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Order Details"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<Order>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorRetryView(error: snapshot.error!, onRetry: _reload);
          }
          if (!snapshot.hasData) {
            return Center(child: Text("Order not found"));
          }

          final order = snapshot.data!;
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
          final isTrackable = !nonTrackable.contains(order.status.toLowerCase());
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _orderFuture = OrderService.getOrderById(
                  widget.orderId,
                  brand: widget.brand,
                );
              });
              await _orderFuture;
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isTrackable) LiveTrackingPanel(order: order),

                  _buildOrderActions(order),

                  /// Order ID & Status
                  _buildSection(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNumber,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              AppFormatters.formatDateTimeFull(order.createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppFormatters.getStatusColor(
                              order.status,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            order.status.toUpperCase().replaceAll('_', ' '),
                            style: TextStyle(
                              color: AppFormatters.getStatusColor(order.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  /// Status Timeline
                  if (order.timeline.isNotEmpty) ...[
                    Text(
                      "Order Status",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8.h),
                    _buildSection(
                      child: Column(
                        children: order.timeline.reversed.map((t) {
                          final isLast = order.timeline.first == t;
                          return IntrinsicHeight(
                            child: Row(
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 12.w,
                                      height: 12.h,
                                      decoration: BoxDecoration(
                                        color: AppFormatters.getStatusColor(
                                          t.status,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(
                                          width: 2.w,
                                          color: Colors.grey[300],
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.status.toUpperCase().replaceAll(
                                            '_',
                                            ' ',
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                        if (t.description != null)
                                          Text(
                                            t.description!,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12.sp,
                                            ),
                                          ),
                                        Text(
                                          AppFormatters.formatDateTimeFull(
                                            t.timestamp,
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 10.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  /// Items List
                  Text(
                    "Order Items",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  _buildSection(
                    child: Column(
                      children: order.items.map((item) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.h,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Icon(
                                  Icons.local_cafe_rounded,
                                  size: 20.sp,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (item.customization != null)
                                      Text(
                                        item.customization!,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                "${item.quantity} x ₹${item.price.toStringAsFixed(0)}",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  /// Delivery Address
                  if (order.deliveryAddress != null) ...[
                    Text(
                      "Delivery Address",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8.h),
                    _buildSection(
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 20.sp,
                            color: Colors.black,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              order.deliveryAddress!.address,
                              style: TextStyle(fontSize: 13.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  /// Payment & Summary
                  Text(
                    "Bill Summary",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  _buildSection(
                    child: Column(
                      children: [
                        _buildSummaryRow("Subtotal", order.subtotal),
                        _buildSummaryRow(
                          "Delivery Charge",
                          order.deliveryCharge,
                        ),
                        _buildSummaryRow("Tax", order.tax),
                        Divider(height: 24.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Paid",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "₹${order.total.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.sp,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Icon(
                              order.paymentStatus == 'paid'
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.info_outline_rounded,
                              size: 16.sp,
                              color: order.paymentStatus == 'paid'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              "Payment: ${order.paymentMethod} (${order.paymentStatus})",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: order.paymentStatus == 'paid'
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text("₹${value.toStringAsFixed(2)}"),
        ],
      ),
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
          ..._reasons.entries.map(
            (e) => RadioListTile<String>(
              value: e.key,
              groupValue: _reason,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _reason = v;
                      _error = null;
                    }),
              title: Text(e.value, style: TextStyle(fontSize: 14.sp)),
              contentPadding: EdgeInsets.zero,
              dense: true,
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
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
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
