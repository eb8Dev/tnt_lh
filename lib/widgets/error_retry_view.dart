import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Turns a thrown object into something a customer can act on. Screens used to
/// render `Text("Error: $err")`, which surfaced raw `SocketException` text and,
/// worse, offered no way back other than restarting the app.
String friendlyErrorMessage(Object error) {
  final raw = error.toString();
  if (raw.contains('SocketException') ||
      raw.contains('Network error') ||
      raw.contains('Failed host lookup') ||
      raw.contains('TimeoutException')) {
    return "We couldn't reach our kitchen. Check your connection and try again.";
  }
  if (raw.contains('401') || raw.contains('Unauthorized')) {
    return "Your session expired. Please sign in again.";
  }
  return "Something went wrong on our end. Please try again.";
}

class ErrorRetryView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorRetryView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48.sp,
              color: Colors.black.withValues(alpha: 0.25),
            ),
            SizedBox(height: 16.h),
            Text(
              friendlyErrorMessage(error),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, size: 18.sp),
              label: Text(
                "Try again",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
