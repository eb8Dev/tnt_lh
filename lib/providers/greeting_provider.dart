import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/services/order_service.dart';

/// One greeting line. [text] holds `{dish}`, which becomes the store's
/// current bestseller: "Afternoon slump? {dish} has a crush on you".
typedef GreetingLine = ({String period, String text});

/// Time of day, as the greeting lines are grouped.
String greetingPeriod(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'morning';
  if (h >= 12 && h < 17) return 'afternoon';
  if (h >= 17 && h < 22) return 'evening';
  return 'night';
}

/// Built-in lines, used until the store sets its own in the admin panel. The
/// dish does the flirting; we never greet the dish.
const Map<String, List<GreetingLine>> _defaults = {
  Brands.cafeKey: [
    (period: 'morning', text: 'Rise and sip. {dish} saved you a seat'),
    (period: 'morning', text: 'Mornings look better with {dish}'),
    (period: 'afternoon', text: 'Afternoon slump? {dish} has a crush on you'),
    (period: 'afternoon', text: '{dish} is calling your name this afternoon'),
    (period: 'evening', text: 'Evening plans? {dish} would love to join'),
    (period: 'evening', text: 'Unwind with {dish}. It has been waiting'),
    (period: 'night', text: "Late-night craving? {dish} won't judge"),
  ],
  Brands.bakeryKey: [
    (period: 'morning', text: '{dish}, fresh out of the oven, just for you'),
    (period: 'morning', text: 'Good mornings start with {dish}'),
    (period: 'afternoon', text: 'Sweet tooth calling? {dish} picked up'),
    (period: 'afternoon', text: '{dish} thinks you deserve a treat'),
    (period: 'evening', text: 'Treat yourself tonight. {dish} insists'),
    (period: 'evening', text: '{dish} has been thinking about you'),
    (period: 'night', text: 'Midnight craving? {dish} is still up'),
  ],
};

/// The lines for a store: the admin's own if set, otherwise the built-ins.
final greetingLinesProvider = FutureProvider.family<List<GreetingLine>, String>(
  (ref, brand) async {
    final key = Brands.isBakery(brand) ? Brands.bakeryKey : Brands.cafeKey;
    try {
      final settings = await OrderService.getSettings(brand: brand);
      final raw = settings['greetings'];
      if (raw is List) {
        final lines = <GreetingLine>[
          for (final g in raw)
            if (g is Map && (g['text'] ?? '').toString().contains('{dish}'))
              (
                period: (g['period'] ?? 'any').toString(),
                text: g['text'].toString().trim(),
              ),
        ];
        if (lines.isNotEmpty) return lines;
      }
    } catch (_) {
      // Fall back to the built-in lines.
    }
    return _defaults[key]!;
  },
);

/// Today's line for this time of day. Stable through the day and period, so
/// it doesn't change on every rebuild, but varies day to day.
GreetingLine pickGreeting(List<GreetingLine> lines, DateTime now) {
  final period = greetingPeriod(now);
  var pool = lines.where((l) => l.period == period).toList();
  if (pool.isEmpty) pool = lines.where((l) => l.period == 'any').toList();
  if (pool.isEmpty) pool = lines;
  final day = now.difference(DateTime(now.year)).inDays;
  return pool[day % pool.length];
}
