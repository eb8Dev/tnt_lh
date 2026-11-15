import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppFormatters {
  static String parseId(dynamic idData) {
    if (idData == null) return '';
    if (idData is String) return idData;
    if (idData is Map && idData.containsKey('\$oid')) {
      return idData['\$oid'].toString();
    }
    return idData.toString();
  }

  /// What a customer should read for an order status. The raw values
  /// (`in_transit`, `out-for-delivery`) were printed as-is.
  /// A price the way people write it: ₹189, ₹189.50. Prices used to print
  /// straight from a double ("₹189.0", "₹378.0") or with forced paise
  /// ("₹40.00") depending on the screen.
  static String rupees(num amount) {
    final whole = amount == amount.roundToDouble();
    return whole ? '₹${amount.round()}' : '₹${amount.toStringAsFixed(2)}';
  }

  static String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Order placed';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Being prepared';
      case 'ready':
        return 'Ready';
      case 'waiting_for_rider':
        return 'Finding a rider';
      case 'assigned':
      case 'accepted':
        return 'Rider assigned';
      case 'heading_to_pickup':
        return 'Rider heading to store';
      case 'arrived_at_pickup':
        return 'Rider at the store';
      case 'out-for-delivery':
      case 'picked_up':
        return 'Picked up';
      case 'in_transit':
        return 'On the way';
      case 'arrived':
        return 'Rider has arrived';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        final s = status.replaceAll(RegExp(r'[_-]'), ' ').trim();
        return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    }
  }

  /// A status-history note worth showing a customer. The backend also writes
  /// its own bookkeeping there ("Updated via delivery (in_transit)").
  static String? customerNote(String? note) {
    final n = note?.trim() ?? '';
    if (n.isEmpty ||
        n.startsWith('Updated via') ||
        RegExp(r'\([a-z_-]+\)').hasMatch(n)) {
      return null;
    }
    return n;
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'preparing':
      case 'confirmed':
        return Colors.blue;
      case 'ready':
      case 'out-for-delivery':
      case 'in_transit':
      case 'assigned':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static String formatDate(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  static String formatDateTimeFull(String? dateStr) {
    if (dateStr == null) return "N/A";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
