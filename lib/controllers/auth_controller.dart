import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authProvider = Provider<AuthController>((ref) {
  return AuthController();
});

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// -------------------------
  /// GOOGLE SIGN-IN (NEW WAY)
  /// -------------------------
  Future<Map<String, dynamic>> signInWithGoogle({String? brand}) async {
    try {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');

      final userCredential = await _auth.signInWithProvider(googleProvider);

      // Get Firebase ID Token
      final String? idToken = await userCredential.user?.getIdToken();
      final user = userCredential.user;

      if (idToken != null && user != null) {
        // Exchange for Backend Token using googleLogin endpoint
        return await AuthService.googleLogin(
          idToken: idToken,
          email: user.email ?? '',
          name: user.displayName,
          photoURL: user.photoURL,
          brand: brand,
        );
      } else {
        throw Exception("Failed to retrieve ID Token from Google Sign-In");
      }
    } catch (e) {
      throw Exception("Google sign-in failed: $e");
    }
  }

  /// -------------------------
  /// PHONE AUTH
  /// -------------------------
  Future<void> signInWithPhone({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(Map<String, dynamic> data)
    onAutoVerified, // Callback for auto-verification
    String? brand,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final userCredential = await _auth.signInWithCredential(credential);
          final String? idToken = await userCredential.user?.getIdToken();
          if (idToken != null) {
            final data = await AuthService.firebaseLogin(idToken, brand: brand);
            onAutoVerified(data);
          }
        } catch (e) {
          onError(e.toString());
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Phone verification failed');
      },

      codeSent: (verificationId, _) {
        onCodeSent(verificationId);
      },

      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// -------------------------
  /// VERIFY OTP
  /// -------------------------
  Future<Map<String, dynamic>> verifyOtp({
    required String verificationId,
    required String smsCode,
    String? brand,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Get Firebase ID Token
    final String? idToken = await userCredential.user?.getIdToken();

    if (idToken != null) {
      // Exchange for Backend Token
      return await AuthService.firebaseLogin(idToken, brand: brand);
    } else {
      throw Exception("Failed to retrieve ID Token from Phone Auth");
    }
  }

  /// -------------------------
  /// COMPLETE PROFILE
  /// -------------------------
  Future<Map<String, dynamic>> completeProfile({
    required String name,
    required String email,
    required String address,
    Map<String, dynamic>? location,
    String? brand,
  }) async {
    return await AuthService.completeProfile(
      name: name,
      email: email,
      address: address,
      location: location,
      brand: brand,
    );
  }

  /// -------------------------
  /// SIGN OUT
  /// -------------------------
  Future<void> signOut({String? brand}) async {
    await AuthService.logout(brand: brand);
  }

  User? get currentUser => _auth.currentUser;
}
