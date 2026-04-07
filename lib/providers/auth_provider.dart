import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/models/user_model.dart';

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
    User? user,
    fb.User? firebaseUser,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      requiresRegistration: requiresRegistration ?? this.requiresRegistration,
      user: user ?? this.user,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      error: error ?? this.error,
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

        final isGoogle = firebaseUser.providerData.any(
          (p) => p.providerId == 'google.com',
        );
        Map<String, dynamic> authResult;

        if (isGoogle) {
          debugPrint("Auth: Performing Google Login exchange...");
          authResult = await AuthService.googleLogin(
            idToken: idToken,
            email: firebaseUser.email!,
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

        User user = User.fromJson(userData);

        // ALWAYS fetch full profile to ensure email and address are populated
        // The login response often contains a minimal user object
        debugPrint(
          "Auth: Fetching full profile to ensure all fields are populated...",
        );
        try {
          final profileResult = await AuthService.getProfile();
          final fullUserData =
              profileResult['data']?['user'] ?? profileResult['user'];

          if (fullUserData != null) {
            user = User.fromJson(fullUserData);
            debugPrint(
              "Auth: Full profile loaded. Email: ${user.email}, Address: ${user.address}",
            );
          }
        } catch (e) {
          debugPrint("Auth: Profile fetch failed, using login data: $e");
          // If profile fetch fails but we have login data, we continue
        }

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: user.isProfileComplete,
          requiresRegistration: !user.isProfileComplete,
          user: user,
          error: null,
        );
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
      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: null,
        idToken: googleAuth.idToken,
      );
      await fb.FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
