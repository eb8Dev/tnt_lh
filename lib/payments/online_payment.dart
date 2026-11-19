import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:tnt_lh/services/payment_service.dart';
import 'package:tnt_lh/widgets/app_sheets.dart';

/// How a payment attempt ended for the customer.
enum PaymentResult {
  /// Paid: the order is placed.
  paid,

  /// They chose cash on delivery instead: the order is placed.
  cash,

  /// Not paid yet: the order waits (it can be paid from its page for a while).
  unpaid,
}

sealed class _Outcome {}

class _Succeeded extends _Outcome {
  final PaymentSuccessResponse response;
  _Succeeded(this.response);
}

class _Stopped extends _Outcome {
  /// Null when the customer closed the payment screen themselves.
  final String? reason;
  _Stopped(this.reason);
}

/// Opens Razorpay for [checkout] (from PaymentService.start) and waits for it.
Future<_Outcome> _openRazorpay(Map<String, dynamic> checkout, Color color) {
  final razorpay = Razorpay();
  final done = Completer<_Outcome>();
  void finish(_Outcome o) {
    if (!done.isCompleted) done.complete(o);
  }

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
    finish(_Succeeded(r));
  });
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
    finish(_Stopped(cancelled ? null : r.message));
  });
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
    finish(_Stopped('Payment with ${r.walletName ?? 'that wallet'} is not supported. Please choose another way to pay.'));
  });

  final prefill = (checkout['prefill'] as Map?)?.cast<String, dynamic>() ?? {};
  razorpay.open({
    'key': checkout['keyId'],
    'order_id': checkout['razorpayOrderId'],
    'amount': checkout['amount'],
    'currency': checkout['currency'] ?? 'INR',
    'name': checkout['name'],
    'description': checkout['description'],
    'prefill': {
      'contact': prefill['contact'] ?? '',
      'email': prefill['email'] ?? '',
      'name': prefill['name'] ?? '',
    },
    'theme': {
      'color': '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
    },
    'retry': {'enabled': true, 'max_count': 2},
  });
  return done.future.whenComplete(razorpay.clear);
}

/// What to do after a payment didn't go through: try again, cash, or later.
Future<String?> _unpaidSheet(BuildContext context, String? reason) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              PhosphorIcons.creditCard(PhosphorIconsStyle.duotone),
              size: 40.r,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            SizedBox(height: 12.h),
            Text(
              reason == null ? 'Payment not completed' : "The payment didn't go through",
              style: GoogleFonts.poppins(fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6.h),
            Text(
              '${reason == null ? '' : '$reason '}Your order is saved. Pay now, or switch to cash on delivery.',
              style: GoogleFonts.poppins(fontSize: 13.5.sp, color: Colors.black54, height: 1.45),
            ),
            SizedBox(height: 20.h),
            SheetButton(label: 'Try paying again', onPressed: () => Navigator.pop(ctx, 'retry')),
            SizedBox(height: 8.h),
            SheetButton(label: 'Pay cash on delivery instead', primary: false, onPressed: () => Navigator.pop(ctx, 'cash')),
            SheetButton(label: 'Decide later', primary: false, onPressed: () => Navigator.pop(ctx, 'later')),
          ],
        ),
      ),
    ),
  );
}

/// Pays for orders that are waiting for an online payment, from checkout or
/// from the order's page. Handles a closed or failed payment by offering to
/// try again or to pay cash. Never throws: problems are shown in a sheet.
Future<PaymentResult> completePayment(
  BuildContext context, {
  required List<String> orderIds,
  required String brand,
}) async {
  final color = Theme.of(context).colorScheme.primary;
  while (true) {
    String? reason;
    try {
      final checkout = await PaymentService.start(orderIds, brand);
      final outcome = await _openRazorpay(checkout, color);
      if (outcome is _Succeeded) {
        final r = outcome.response;
        await PaymentService.verify(
          razorpayOrderId: r.orderId ?? checkout['razorpayOrderId'],
          razorpayPaymentId: r.paymentId ?? '',
          signature: r.signature ?? '',
          brand: brand,
        );
        HapticFeedback.heavyImpact();
        return PaymentResult.paid;
      }
      reason = (outcome as _Stopped).reason;
    } catch (e) {
      reason = errorText(e);
    }

    if (!context.mounted) return PaymentResult.unpaid;
    final choice = await _unpaidSheet(context, reason);
    if (choice == 'retry') continue;
    if (choice == 'cash') {
      try {
        await PaymentService.payCash(orderIds, brand);
        return PaymentResult.cash;
      } catch (e) {
        if (context.mounted) {
          await noticeSheet(context, title: "Couldn't switch to cash", message: errorText(e));
        }
      }
    }
    return PaymentResult.unpaid;
  }
}
