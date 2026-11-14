import 'package:tnt_lh/widgets/auth_split.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;
  final String verificationId;
  final VoidCallback onBack;

  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.verificationId,
    required this.onBack,
  });

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();

  bool _canResend = false;
  int _resendSeconds = 30;
  Timer? _resendTimer;

  bool _isVerifying = false;
  String? _currentVerificationId;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _resendSeconds = 30;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_resendSeconds == 0) {
        if (mounted) setState(() => _canResend = true);
        timer.cancel();
      } else {
        if (mounted) setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    SnackBarUtils.showThemedSnackBar(
      context: context,
      message: msg,
      isError: isError,
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showSnack("Enter 6 digit OTP", isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId!,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnack(e.message ?? "Verification failed", isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack("Error: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _resendSeconds = 30;
    });
    _showSnack("Resending OTP...");

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            _showSnack("Resend Failed: ${e.message}", isError: true);
            setState(() => _canResend = true);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _currentVerificationId = verificationId;
            });
            _showSnack("OTP Resent!");
            _startResendTimer();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => _currentVerificationId = verificationId);
        },
      );
    } catch (e) {
      if (mounted) {
        _showSnack("Error resending: $e", isError: true);
        setState(() => _canResend = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String resendText;
    if (!_canResend) {
      resendText = "Resend in ${_resendSeconds}s";
    } else {
      resendText = "Resend OTP";
    }

    return CenteredPage(
      // Full width on tablets, where AuthSplit lays the page out.
      maxWidth: Responsive.isTablet(context) ? double.infinity : 640,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
              color: Colors.black,
            ),
            onPressed: widget.onBack,
          ),
        ),
        body: AuthSplit(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 30.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),
                Text(
                  "Verification",
                  style: GoogleFonts.poppins(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Enter the code sent to ${widget.phone}",
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 48.h),

                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  autoDisposeControllers: false,
                  animationType: AnimationType.fade,
                  textStyle: GoogleFonts.poppins(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(16.r),
                    fieldHeight: 56,
                    fieldWidth: 46,
                    activeFillColor: Colors.grey.shade50,
                    inactiveFillColor: Colors.grey.shade50,
                    selectedFillColor: Colors.white,
                    activeColor: Color(0xFFA9BCA4),
                    inactiveColor: Colors.black12,
                    selectedColor: Color(0xFFA9BCA4),
                    borderWidth: 1.5,
                  ),
                  cursorColor: Colors.black,
                  enableActiveFill: true,
                  onChanged: (value) {},
                  onCompleted: (value) {
                    _verifyOtp();
                  },
                ),

                SizedBox(height: 32.h),

                Center(
                  child: TextButton(
                    onPressed: _canResend ? _resendOtp : null,
                    child: Text(
                      resendText,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: _canResend ? Colors.black : Colors.black26,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40.h),

                SizedBox(
                  width: double.infinity,
                  height: 58.h,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      elevation: 0,
                    ),
                    child: _isVerifying
                        ? CircularProgressIndicator.adaptive(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : Text(
                            "Verify & Continue",
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
