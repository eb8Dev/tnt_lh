import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/components/live_tracking_panel.dart';
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
    _orderFuture = OrderService.getOrderById(
      widget.orderId,
      brand: widget.brand,
    );
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
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return Center(child: Text("Order not found"));
          }

          final order = snapshot.data!;
          final trackableStatuses = [
            'assigned',
            'out-for-delivery',
            'in_transit',
            'arrived',
          ];
          final isTrackable = trackableStatuses.contains(
            order.status.toLowerCase(),
          );
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
