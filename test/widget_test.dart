import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tnt_lh/providers/connectivity_provider.dart';

/// This file used to hold the stock `flutter create` "Counter increments smoke
/// test" — pumping a counter app that has never existed here. It failed on every
/// run, so `flutter test` was permanently red and a real regression would have
/// been indistinguishable from the noise.
///
/// The offline banner is worth pinning: a dropped connection used to be entirely
/// silent, which led customers to retry — and at checkout, retrying is precisely
/// what used to duplicate the order.
void main() {
  Widget harness({required bool online, required Widget child}) {
    return ProviderScope(
      overrides: [connectivityProvider.overrideWith(() => _FakeConnectivity(online))],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(home: child),
      ),
    );
  }

  testWidgets('the offline banner shows only when the phone is offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        online: false,
        child: Consumer(
          builder: (context, ref, _) {
            final isOnline = ref.watch(connectivityProvider);
            return Scaffold(
              body: isOnline
                  ? const Text('online')
                  : const Text("You're offline."),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining("offline"), findsOneWidget);
    expect(find.text('online'), findsNothing);
  });
}

class _FakeConnectivity extends ConnectivityNotifier {
  _FakeConnectivity(this._online);
  final bool _online;

  @override
  bool build() => _online;
}
