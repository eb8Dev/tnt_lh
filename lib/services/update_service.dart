import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:tnt_lh/widgets/app_sheets.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Nudges the user to update when a newer build is out — with no per-release
/// bookkeeping on our side:
///  - **Android** asks the Play Store directly ([InAppUpdate]). A background
///    "flexible" download by default; a blocking "immediate" update when the
///    release was pushed with a high Play *update priority* (>= 4). So force vs
///    soft is decided at rollout time in the Play Console, not in code/config.
///  - **iOS** reads the live App Store version (iTunes lookup) and, if it's
///    newer than the installed one, offers a dismissible prompt to the store.
///    (Apple has no native force-update; that would need a separate flag.)
///
/// Every path is wrapped so an update check can never crash or block the app.
class UpdateService {
  UpdateService._();

  static const String _iosBundleId = 'com.manuen.tntLh';
  // App Store storefront to look up (matches the audience's region).
  static const String _appStoreCountry = 'in';

  /// Fire-and-forget from the home screen once it's on screen.
  static Future<void> check(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        await _checkAndroid(context);
      } else if (Platform.isIOS) {
        await _checkIOS(context);
      }
    } catch (e) {
      debugPrint('UpdateService: check failed: $e');
    }
  }

  static Future<void> _checkAndroid(BuildContext context) async {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

    // updatePriority is set per-release in the Play Console (0..5). Treat a high
    // priority as "make everyone update now".
    final isCritical = info.updatePriority >= 4;

    if (isCritical && info.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
      return;
    }

    if (info.flexibleUpdateAllowed) {
      // Downloads in the background while the user keeps using the app; when
      // it's ready we offer a one-tap restart to apply it.
      await InAppUpdate.startFlexibleUpdate();
      if (!context.mounted) return;
      final restart = await confirmSheet(
        context,
        title: 'Update ready',
        message: 'Restart the app now to use the new version.',
        confirmLabel: 'Restart now',
        cancelLabel: 'Later',
        icon: Icons.system_update_alt_rounded,
      );
      if (restart) await InAppUpdate.completeFlexibleUpdate();
    } else if (info.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
    }
  }

  static Future<void> _checkIOS(BuildContext context) async {
    final pkg = await PackageInfo.fromPlatform();
    final uri = Uri.parse(
      'https://itunes.apple.com/lookup?bundleId=$_iosBundleId&country=$_appStoreCountry',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if ((data['resultCount'] ?? 0) == 0) return; // not on the App Store (yet)

    final result = (data['results'] as List).first as Map<String, dynamic>;
    final storeVersion = (result['version'] ?? '').toString();
    final storeUrl = (result['trackViewUrl'] ?? '').toString();
    if (storeVersion.isEmpty || !_isNewer(storeVersion, pkg.version)) return;

    if (!context.mounted) return;
    final update = await confirmSheet(
      context,
      title: 'A new version is here',
      message:
          'Version $storeVersion is on the App Store, with the latest '
          'improvements and fixes.',
      confirmLabel: 'Update',
      cancelLabel: 'Later',
      icon: Icons.system_update_alt_rounded,
    );
    if (update && storeUrl.isNotEmpty) {
      await launchUrl(
        Uri.parse(storeUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  /// True when [store] is a higher dotted version than [current]
  /// (e.g. "1.2.0" > "1.1.9"). Missing/garbage segments count as 0.
  static bool _isNewer(String store, String current) {
    List<int> parse(String v) => v
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final s = parse(store);
    final c = parse(current);
    final len = s.length > c.length ? s.length : c.length;
    for (var i = 0; i < len; i++) {
      final sv = i < s.length ? s[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (sv != cv) return sv > cv;
    }
    return false;
  }
}
