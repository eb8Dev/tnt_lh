import 'package:flutter/material.dart';
import 'package:tnt_lh/widgets/app_sheets.dart';

/// Kept under its old name so every caller goes through one place. There are
/// no snackbars any more: an error opens a short bottom sheet, and a success
/// message shows nothing, because the screen itself already shows the result
/// (the address changed, the photo changed, the order moved on).
class SnackBarUtils {
  static void showThemedSnackBar({
    required BuildContext context,
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!isError || !context.mounted) return;
    noticeSheet(context, message: message);
  }
}
