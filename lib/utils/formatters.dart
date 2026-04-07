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
