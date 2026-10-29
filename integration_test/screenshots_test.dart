// Walks the app for App Store screenshots. Run with tool/screenshots.py, which
// takes a real simulator screenshot (iOS status bar included) whenever this
// prints `SHOT:<name>`.
//
// Signs in with a Firebase test phone number, so no SMS is sent. Pass it as
//   --dart-define=SHOT_PHONE=9515409973 --dart-define=SHOT_CODE=123456
//   --dart-define=SCREENSHOT_MODE=true   (skips the notification prompt)
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/main.dart' as app;

const _phone = String.fromEnvironment('SHOT_PHONE');
const _code = String.fromEnvironment('SHOT_CODE');
// Start from a fresh install (clear the app's data first) to capture the
// signed-out screens: onboarding and login.
const _signedOut = bool.fromEnvironment('SHOT_SIGNED_OUT');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 3]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<bool> waitFor(
    WidgetTester tester,
    Finder f, {
    int seconds = 40,
  }) async {
    for (var i = 0; i < seconds * 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (f.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, 2);
    // ignore: avoid_print
    print('SHOT:$name');
    await settle(tester, 4); // the host captures during this pause
  }

  // Pages here use custom back buttons, which tester.pageBack() cannot find.
  Future<void> goBack(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
    await settle(tester, 3);
  }

  Future<void> tapIfThere(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      // ignore: avoid_print
      print('MISSING:$f');
      return;
    }
    await tester.tap(f.first, warnIfMissed: false);
    await settle(tester, 3);
  }

  testWidgets('store screenshots', (tester) async {
    app.main();
    await settle(tester, 6);

    if (_signedOut) {
      await shot(tester, '00_onboarding');
      for (var i = 0; i < 4; i++) {
        if (find.text('Get Started').evaluate().isNotEmpty) break;
        await tapIfThere(
          tester,
          find.byIcon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold)),
        );
      }
      await tapIfThere(tester, find.text('Get Started'));
      await settle(tester, 3);
      await shot(tester, '00_login');
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
      final sent = Completer<String>();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$_phone',
        verificationCompleted: (_) {},
        verificationFailed: (e) => sent.completeError(e),
        codeSent: (id, _) => sent.complete(id),
        codeAutoRetrievalTimeout: (_) {},
      );
      final id = await sent.future;
      await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: _code),
      );
    }

    final home = find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill));
    expect(await waitFor(tester, home), isTrue, reason: 'home never showed');
    await settle(tester, 5); // images
    await shot(tester, '01_cafe_home');

    // A product's details: the first price on the page opens its card.
    await tapIfThere(tester, find.textContaining('₹'));
    await settle(tester, 3);
    await shot(tester, '02_item_details');

    // Add it, so the bag has something in it.
    await tapIfThere(tester, find.textContaining('Add to Bag'));
    await settle(tester, 3);
    if (find
        .byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill))
        .evaluate()
        .isEmpty) {
      await goBack(tester);
    }

    // The switcher scrolls away with the header; bring it back first.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await settle(tester, 2);
    await tapIfThere(tester, find.text(Brands.bakeryName));
    await settle(tester, 5);
    await shot(tester, '03_bakery_home');

    await tapIfThere(tester, find.byIcon(PhosphorIcons.shoppingBag()));
    await tapIfThere(tester, find.byIcon(PhosphorIcons.basket()));
    await settle(tester, 4);
    await shot(tester, '04_bag');

    // Beyond the store set: the rest of the screens, for design review.
    await tapIfThere(tester, find.text('Checkout Store'));
    await settle(tester, 4);
    await shot(tester, '05_checkout');
    await goBack(tester);

    await tapIfThere(tester, find.byIcon(PhosphorIcons.receipt()));
    await settle(tester, 4);
    await shot(tester, '06_orders');
    await tapIfThere(tester, find.textContaining('Order #'));
    await settle(tester, 4);
    await shot(tester, '07_order_detail');
    await goBack(tester);

    await tapIfThere(tester, find.byIcon(PhosphorIcons.user()));
    await settle(tester, 4);
    await shot(tester, '08_profile');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(tester, 3);
    await shot(tester, '09_profile_lower');

    await tapIfThere(tester, find.text('Add'));
    await settle(tester, 5);
    await shot(tester, '10_address_picker');
    await goBack(tester);

    await tapIfThere(tester, find.byIcon(PhosphorIcons.house()));
    await settle(tester, 3);
    final filledHeart = find.byIcon(
      PhosphorIcons.heart(PhosphorIconsStyle.fill),
    );
    await tapIfThere(
      tester,
      filledHeart.evaluate().isNotEmpty
          ? filledHeart
          : find.byIcon(PhosphorIcons.heart()),
    );
    await settle(tester, 4);
    await shot(tester, '11_wishlist');
    await goBack(tester);
  });
}
