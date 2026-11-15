import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The app's one way of asking or telling something: a bottom sheet, in the
/// app's own type and colours, like Zomato or Rapido. No system dialogs (they
/// came in the platform's font and shape) and no snackbars.

Future<T?> _sheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
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
        child: builder(ctx),
      ),
    ),
  );
}

Widget _icon(IconData icon, Color color) => Container(
  width: 48.r,
  height: 48.r,
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.10),
    shape: BoxShape.circle,
  ),
  child: Icon(icon, color: color, size: 24.r),
);

Widget _title(String text) => Text(
  text,
  style: GoogleFonts.poppins(
    fontSize: 18.sp,
    fontWeight: FontWeight.w700,
    color: Colors.black87,
    height: 1.25,
  ),
);

Widget _body(String text) => Text(
  text,
  style: GoogleFonts.poppins(
    fontSize: 13.5.sp,
    color: Colors.black54,
    height: 1.45,
  ),
);

/// A full-width button in the sheet style.
class SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Color? color;
  const SheetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final style = GoogleFonts.poppins(
      fontSize: 15.sp,
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: c,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(label, style: style),
            )
          : TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(label, style: style),
            ),
    );
  }
}

/// Ask before doing something. Returns true only when confirmed.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Not now',
  bool destructive = false,
  IconData? icon,
}) async {
  final danger = Colors.red.shade600;
  final ok = await _sheet<bool>(context, (ctx) {
    final accent = destructive ? danger : Theme.of(ctx).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[_icon(icon, accent), SizedBox(height: 14.h)],
        _title(title),
        if (message != null) ...[SizedBox(height: 6.h), _body(message)],
        SizedBox(height: 22.h),
        SheetButton(
          label: confirmLabel,
          color: accent,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(ctx, true);
          },
        ),
        SizedBox(height: 6.h),
        SheetButton(
          label: cancelLabel,
          primary: false,
          onPressed: () => Navigator.pop(ctx, false),
        ),
      ],
    );
  });
  return ok == true;
}

/// Something went wrong (or something the customer must know). Replaces the
/// snackbars: a short sheet with what happened and one button.
Future<void> noticeSheet(
  BuildContext context, {
  required String message,
  String? title,
  bool isError = true,
  String buttonLabel = 'OK',
}) {
  return _sheet<void>(context, (ctx) {
    final accent = isError
        ? Colors.red.shade600
        : Theme.of(ctx).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _icon(
          isError
              ? PhosphorIcons.warningCircle(PhosphorIconsStyle.fill)
              : PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
          accent,
        ),
        SizedBox(height: 14.h),
        _title(title ?? (isError ? 'That didn\'t work' : 'Done')),
        SizedBox(height: 6.h),
        _body(message),
        SizedBox(height: 22.h),
        SheetButton(label: buttonLabel, onPressed: () => Navigator.pop(ctx)),
      ],
    );
  });
}

/// The message inside an exception, without Dart's "Exception: " prefix.
String errorText(Object e) =>
    e.toString().replaceFirst(RegExp(r'^(Exception|Network error): ?'), '');
