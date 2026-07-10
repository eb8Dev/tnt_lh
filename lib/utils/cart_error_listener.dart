import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';

/// Cart writes return immediately and settle in the background, so a failure has
/// no call site left to throw at. Call this from `build` on any screen with cart
/// controls and the failure surfaces as a snackbar instead of vanishing.
void listenForCartErrors(WidgetRef ref, BuildContext context) {
  ref.listen<String?>(cartErrorProvider, (_, message) {
    if (message == null) return;
    SnackBarUtils.showThemedSnackBar(
      context: context,
      message: message,
      isError: true,
    );
    // Clear it so the same failure doesn't replay on the next screen.
    ref.read(cartErrorProvider.notifier).report(null);
  });
}
