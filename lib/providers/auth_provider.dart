import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/models/user_model.dart';

// Sentinel to tell "argument not passed" apart from "explicitly set to null"
// in copyWith. Without this, nullable fields (user/firebaseUser/error) could
// never be cleared — a transient error would persist even after a later success.
const _unset = Object();

// State for Auth
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final bool requiresRegistration;
  final User? user;
  final fb.User? firebaseUser;
  final String? error;

  AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.requiresRegistration = false,
    this.user,
    this.firebaseUser,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? requiresRegistration,
    Object? user = _unset,
    Object? firebaseUser = _unset,
    Object? error = _unset,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      requiresRegistration: requiresRegistration ?? this.requiresRegistration,
      user: identical(user, _unset) ? this.user : user as User?,
      firebaseUser: identical(firebaseUser, _unset)
          ? this.firebaseUser
          : firebaseUser as fb.User?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<fb.User?>? _authStateChangesSubscription;

  @override
  AuthState build() {
    _authStateChangesSubscription?.cancel();
    _authStateChangesSubscription = fb.FirebaseAuth.instance
        .authStateChanges()
        .listen((user) {
          _handleAuthStateChange(user);
        });

    return AuthState(isLoading: true);
  }

  Future<void> _handleAuthStateChange(fb.User? firebaseUser) async {
    if (firebaseUser == null) {
      debugPrint("Auth: No Firebase user, setting unauthenticated");
      state = AuthState(isLoading: false, isAuthenticated: false);
    } else {
      debugPrint("Auth: Firebase user detected: ${firebaseUser.uid}");
      state = state.copyWith(
        isLoading: true,
        firebaseUser: firebaseUser,
        error: null,
      );
      try {
        final idToken = await firebaseUser.getIdToken();
        if (idToken == null) throw "Failed to get ID token";

        // Google and Apple both exchange through the same endpoint: the
        // backend reads the email out of the verified token either way.
        final isGoogle = firebaseUser.providerData.any(
          (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
        );
        Map<String, dynamic> authResult;

        if (isGoogle) {
          debugPrint("Auth: Performing Google Login exchange...");
          authResult = await AuthService.googleLogin(
            idToken: idToken,
            email: firebaseUser.email ?? '',
            name: firebaseUser.displayName,
            photoURL: firebaseUser.photoURL,
          );
        } else {
          debugPrint("Auth: Performing Firebase Phone Login exchange...");
          String? mobile = firebaseUser.phoneNumber;
          if (mobile != null) {
            mobile = mobile.replaceAll(RegExp(r'\D'), '');
            if (mobile.length > 10) {
              mobile = mobile.substring(mobile.length - 10);
            }
          }
          authResult = await AuthService.firebaseLogin(
            idToken,
            mobile: mobile!,
          );
        }

        final userData = authResult['user'] ?? authResult['data']?['user'];
        debugPrint(
          "Auth: Server returned user data. isProfileComplete: ${userData?['isProfileComplete']}",
        );

        if (userData == null) throw "No user data in login response";

        final User user = User.fromJson(userData);

        // Unblock the UI immediately with the login user. The login response is
        // partial (no address / PIN / prefs), so enrich it with the full
        // profile in the background instead of blocking startup on a second
        // sequential round-trip.
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: user.isProfileComplete,
          requiresRegistration: !user.isProfileComplete,
          user: user,
          error: null,
        );

        if (user.isProfileComplete) {
          _enrichProfileInBackground();
        }
      } catch (e) {
        debugPrint("Auth: Error during auth flow: $e");
        final errorStr = e.toString();
        final isRegistrationRequired =
            errorStr.contains('404') ||
            errorStr.contains('not found') ||
            errorStr.contains('required');

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          requiresRegistration: isRegistrationRequired,
          error: errorStr,
        );
      }
    }
  }

  /// Fetches the full profile (address, verification PIN, notification prefs)
  /// after login without blocking the initial render. Updates state.user in
  /// place when it arrives; failures are non-fatal (login data is kept).
  Future<void> _enrichProfileInBackground() async {
    try {
      final profileResult = await AuthService.getProfile();
      final fullUserData =
          profileResult['data']?['user'] ?? profileResult['user'];
      if (fullUserData != null) {
        state = state.copyWith(user: User.fromJson(fullUserData));
      }
    } catch (e) {
      debugPrint("Auth: background profile enrich failed: $e");
    }
  }

  /// Clears a surfaced auth error once a screen has shown it, so it doesn't
  /// replay on the next rebuild.
  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId:
            '138992055382-mqqiupgfm3qv1ihoi4e1oq2r6k65f12o.apps.googleusercontent.com',
      );
      final GoogleSignInAccount googleAccount = await googleSignIn
          .authenticate();
      final GoogleSignInAuthentication googleAuth =
          googleAccount.authentication;

      if (googleAuth.idToken == null) {
        // No idToken almost always means the Android signing SHA-1 or the
        // serverClientId isn't registered in Firebase for this build.
        throw 'Google sign-in is not configured for this build. '
            'Please try phone login.';
      }

      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: null,
        idToken: googleAuth.idToken,
      );
      // The authStateChanges listener takes over from here and flips isLoading
      // off once the backend exchange resolves.
      await fb.FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      // A user backing out of the Google sheet is not an error — just stop.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(isLoading: false, error: null);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Google sign-in failed. Please try phone login.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sign in with Apple (iOS). Apple requires it wherever another social
  /// sign-in is offered. Firebase drives the native Apple sheet itself.
  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final provider = fb.AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      // The authStateChanges listener takes over from here, as with Google.
      await fb.FirebaseAuth.instance.signInWithProvider(provider);
    } on fb.FirebaseAuthException catch (e) {
      // Backing out of the Apple sheet is not an error — just stop.
      final cancelled =
          e.code == 'canceled' ||
          e.code == 'web-context-canceled' ||
          (e.message ?? '').contains('1001');
      // The code goes into the message: one generic line for every failure
      // left nothing to diagnose when review rejected the app on it.
      debugPrint('Apple sign-in failed: ${e.code} ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: cancelled
            ? null
            : 'Apple sign-in failed (${e.code}). Please try phone login.',
      );
    } catch (e) {
      debugPrint('Apple sign-in failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Apple sign-in failed ($e). Please try phone login.',
      );
    }
  }

  /// Deletes the account for good. Returns null on success, or the reason it
  /// was refused. On success the customer is signed out.
  Future<String?> deleteAccount() async {
    final refused = await AuthService.deleteAccount();
    if (refused != null) return refused;
    await logout();
    return null;
  }

  Future<void> completeProfile({
    required String name,
    required String email,
    required String address,
    String? mobile,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      debugPrint("Auth: Completing profile for $name...");
      final result = await AuthService.completeProfile(
        name: name,
        email: email,
        address: address,
        mobile: mobile,
      );

      if (result['success'] == true) {
        debugPrint("Auth: Profile completion successful!");
        final userData = result['data']?['user'] ?? result['user'];
        if (userData != null) {
          final user = User.fromJson(userData);
          state = state.copyWith(
            isLoading: false,
            isAuthenticated: true,
            requiresRegistration: false,
            user: user,
            error: null,
          );
        } else {
          await refreshProfile();
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? "Failed to complete profile",
        );
      }
    } catch (e) {
      debugPrint("Auth: completeProfile error: $e");
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? address,
    String? profileImage,
    Map<String, bool>? notificationPreferences,
    bool isBackground = false,
  }) async {
    if (!isBackground) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final result = await AuthService.updateProfile(
        name: name,
        email: email,
        address: address,
        profileImage: profileImage,
        notificationPreferences: notificationPreferences,
      );

      if (result['success'] == true) {
        final userData = result['data']?['user'] ?? result['user'];
        if (userData != null) {
          state = state.copyWith(
            isLoading: false,
            user: User.fromJson(userData),
            error: null,
          );
        } else {
          await refreshProfile();
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? "Update failed",
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refreshProfile() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    await _handleAuthStateChange(user);
  }

  Future<void> logout() async {
    await AuthService.logout();
    await GoogleSignIn.instance.signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
