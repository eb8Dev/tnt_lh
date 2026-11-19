import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the customer is in phone sign-in.
enum SignInStep { welcome, code }

/// Everything the sign-in screens show, in one place.
class PhoneSignInState {
  final SignInStep step;
  final String phone; // 10 digits, without +91
  final String? verificationId;
  final int? resendToken;
  final bool sending; // asking Firebase to text the code
  final bool verifying; // checking the code
  final int resendIn; // seconds until "Send again" is allowed
  final String? error;

  const PhoneSignInState({
    this.step = SignInStep.welcome,
    this.phone = '',
    this.verificationId,
    this.resendToken,
    this.sending = false,
    this.verifying = false,
    this.resendIn = 0,
    this.error,
  });

  bool get busy => sending || verifying;

  PhoneSignInState copyWith({
    SignInStep? step,
    String? phone,
    String? verificationId,
    int? resendToken,
    bool? sending,
    bool? verifying,
    int? resendIn,
    String? error,
    bool clearError = false,
  }) => PhoneSignInState(
    step: step ?? this.step,
    phone: phone ?? this.phone,
    verificationId: verificationId ?? this.verificationId,
    resendToken: resendToken ?? this.resendToken,
    sending: sending ?? this.sending,
    verifying: verifying ?? this.verifying,
    resendIn: resendIn ?? this.resendIn,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Phone sign-in with Firebase: send the code, check it, send it again.
/// A successful check signs in to Firebase; AuthNotifier takes over from there
/// (backend sign-in, registration), so this never navigates.
class PhoneSignIn extends Notifier<PhoneSignInState> {
  static const resendAfter = 30;
  Timer? _ticker;

  @override
  PhoneSignInState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const PhoneSignInState();
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Back to the number (to fix a typo).
  void editNumber() {
    _ticker?.cancel();
    state = state.copyWith(
      step: SignInStep.welcome,
      verifying: false,
      resendIn: 0,
      clearError: true,
    );
  }

  Future<void> sendCode(String phone, {bool resend = false}) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      state = state.copyWith(error: 'Enter your 10-digit mobile number.');
      return;
    }
    if (state.sending || (resend && state.resendIn > 0)) return;
    state = state.copyWith(phone: digits, sending: true, clearError: true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$digits',
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? state.resendToken : null,
        // Android can read the SMS and sign in by itself.
        verificationCompleted: (credential) async {
          if (!ref.mounted) return;
          state = state.copyWith(verifying: true);
          await _signIn(credential);
        },
        verificationFailed: (e) {
          if (!ref.mounted) return;
          state = state.copyWith(sending: false, error: _friendly(e));
        },
        codeSent: (verificationId, resendToken) {
          if (!ref.mounted) return;
          state = state.copyWith(
            step: SignInStep.code,
            verificationId: verificationId,
            resendToken: resendToken,
            sending: false,
          );
          _startCountdown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!ref.mounted) return;
          state = state.copyWith(verificationId: verificationId);
        },
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        sending: false,
        error: "We couldn't send the code. Please try again.",
      );
    }
  }

  Future<void> verify(String code) async {
    final id = state.verificationId;
    if (code.length != 6 || id == null || state.verifying) return;
    state = state.copyWith(verifying: true, clearError: true);
    await _signIn(
      PhoneAuthProvider.credential(verificationId: id, smsCode: code),
    );
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      // AuthNotifier now signs in with the backend and moves the app on.
    } on FirebaseAuthException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(verifying: false, error: _friendly(e));
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        verifying: false,
        error: "We couldn't check that code. Please try again.",
      );
    }
  }

  void _startCountdown() {
    _ticker?.cancel();
    state = state.copyWith(resendIn: resendAfter);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!ref.mounted || state.resendIn <= 1) {
        t.cancel();
        if (ref.mounted) state = state.copyWith(resendIn: 0);
        return;
      }
      state = state.copyWith(resendIn: state.resendIn - 1);
    });
  }

  /// Firebase speaks in codes; customers need a plain sentence.
  static String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return "That code isn't right. Check the SMS and try again.";
      case 'session-expired':
      case 'code-expired':
        return 'That code has expired. Tap "Send again" for a new one.';
      case 'too-many-requests':
        return 'Too many attempts from this phone. Please wait a while, or sign in with Google instead.';
      case 'invalid-phone-number':
        return "That number doesn't look right. Check it and try again.";
      case 'quota-exceeded':
        return 'We can\'t send more codes right now. Please try again in a little while.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      default:
        final msg = (e.message ?? '').toLowerCase();
        if (msg.contains('unusual activity')) {
          return 'Too many attempts from this phone. Please wait a while, or sign in with Google instead.';
        }
        return 'Sign-in did not work. Please try again.';
    }
  }
}

final phoneSignInProvider = NotifierProvider<PhoneSignIn, PhoneSignInState>(
  PhoneSignIn.new,
);
