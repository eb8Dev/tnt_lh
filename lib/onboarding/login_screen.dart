import 'package:tnt_lh/widgets/auth_split.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final Function(String phone, String verId) onOtpSent;

  const LoginScreen({super.key, required this.onBack, required this.onOtpSent});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: "Please enter a valid 10-digit mobile number",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        // Firebase caps repeated requests. Testers hit this fast on emulators.
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // This only happens on Android auto-verification
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        // These are Firebase callbacks. They can fire up to a minute later —
        // long after the customer has given up and pressed back. Touching
        // setState or `context` on a widget that's gone is a hard crash, on the
        // very first thing a new customer does in the app.
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          SnackBarUtils.showThemedSnackBar(
            context: context,
            message: _friendlyPhoneAuthError(e),
            isError: true,
          );
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          widget.onOtpSent(phone, verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      // Same reason: verifyPhoneNumber is awaited, so the screen may be gone.
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: "Couldn't send the code. Please try again.",
        isError: true,
      );
      setState(() => _isLoading = false);
    }
  }

  /// Firebase phone auth speaks in raw codes. Testers repeatedly requesting OTP
  /// from one device trip Firebase's abuse guard ("unusual activity"), which is
  /// device-side and clears after a wait — say so instead of parroting the code.
  String _friendlyPhoneAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return "Too many attempts from this device. Please wait a while and "
            "try again, or use a different sign-in method.";
      case 'invalid-phone-number':
        return "That phone number doesn't look right. Check and try again.";
      case 'quota-exceeded':
        return "SMS limit reached for now. Please try again later.";
      case 'network-request-failed':
        return "Network error. Check your connection and try again.";
      default:
        final msg = e.message ?? '';
        if (msg.toLowerCase().contains('unusual activity')) {
          return "Too many attempts from this device. Please wait a while "
              "before trying again.";
        }
        return msg.isNotEmpty ? msg : "Verification failed. Please try again.";
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithApple();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Google Sign-In failed: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return CenteredPage(
      // Full width on landscape tablets, where AuthSplit lays the page out.
      maxWidth: Responsive.isExpanded(context) ? double.infinity : 640,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AuthSplit(
          child: Stack(
            children: [
              // Header Gradient / Image
              Container(
                height: size.height * 0.45,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 60,
                      left: 20,
                      child: TactileButton(
                        onTap: widget.onBack,
                        child: Container(
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 120.h,
                            width: 120.w,
                            padding: EdgeInsets.all(20.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              "assets/images/teas_n_trees_no_bg.png",
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            "Welcome Back",
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Login Card
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: size.height * 0.6,
                  width: double.infinity,
                  padding: EdgeInsets.all(32.r),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(40.r),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Login with Mobile",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "We'll send you a verification code",
                          style: GoogleFonts.poppins(
                            color: Colors.black38,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(height: 32.h),

                        // Phone Input
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 4.h,
                          ),
                          child: Row(
                            children: [
                              Text(
                                "+91",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Container(
                                width: 1.w,
                                height: 24.h,
                                color: Colors.black12,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5.sp,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Mobile Number",
                                    hintStyle: TextStyle(
                                      color: Colors.black26,
                                      letterSpacing: 0.sp,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    border: InputBorder.none,
                                    counterText: "",
                                    prefixIcon: Icon(
                                      PhosphorIcons.deviceMobile(),
                                      color: Colors.black45,
                                      size: 20.sp,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32.h),

                        TactileButton(
                          onTap: _isLoading ? null : _sendOtp,
                          child: Container(
                            width: double.infinity,
                            height: 60.h,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: _isLoading
                                ? SizedBox(
                                    height: 24.h,
                                    width: 24.w,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    "Continue",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                          ),
                        ),

                        SizedBox(height: 24.h),
                        Center(
                          child: Text(
                            "OR",
                            style: GoogleFonts.poppins(
                              color: Colors.black26,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Google Login
                        TactileButton(
                          onTap: _isLoading ? null : _signInWithGoogle,
                          child: Container(
                            width: double.infinity,
                            height: 60.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  "assets/images/google_logo.png",
                                  height: 24.h,
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  "Sign in with Google",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Apple requires this next to any other social sign-in.
                        if (Platform.isIOS) ...[
                          SizedBox(height: 12.h),
                          TactileButton(
                            onTap: _isLoading ? null : _signInWithApple,
                            child: Container(
                              width: double.infinity,
                              height: 60.h,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.apple,
                                    color: Colors.white,
                                    size: 26.h,
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    "Sign in with Apple",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
