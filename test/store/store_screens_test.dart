// Renders the real TAC Eats screens for the App Store and Play listings, with
// the shops' real menus (recorded in test/store/fixtures) and a fictional
// signed-in customer. Raw screens land in store/raw/; tool/store/frame.py then
// adds the headline and device frame for each store size.
//
//   flutter test test/store/store_screens_test.dart --update-goldens
//
// Refresh the menu snapshot with tool/store/record_fixtures.sh.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'package:tnt_lh/core/theme.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/models/user_model.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/auth/phone_sign_in.dart';
import 'package:tnt_lh/auth/welcome_screen.dart';
import 'package:tnt_lh/screens/cafe/cafe_item_details_screen.dart';
import 'package:tnt_lh/screens/store_home.dart';

const _fixtures = 'test/store/fixtures';

Future<void> _font(String family, String path) async {
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await l.load();
}

/// A fictional customer, signed in. Nothing reaches Firebase.
class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoading: false,
        isAuthenticated: true,
        user: User(
          id: 'demo',
          name: 'Ananya Rao',
          mobile: '9000000000',
          email: 'ananya@example.com',
          isProfileComplete: true,
        ),
      );
}

/// The sign-in screen, waiting for a number. Nothing reaches Firebase.
class _SignInIdle extends PhoneSignIn {
  @override
  PhoneSignInState build() => const PhoneSignInState();
}

/// Photos for the listing (test/store/photos): the cafe's own photos and the
/// bakery's product shots, matched to items by name. The live menu has none
/// yet. First match wins, so specific words come before general ones.
const _photoFor = <String, String>{
  'matcha': 'matcha.jpg',
  'frappe': 'frappe.jpg',
  'shake': 'frappe.jpg',
  'iced latte': 'frappe.jpg',
  'iced caramel': 'frappe.jpg',
  'iced irish': 'frappe.jpg',
  'iced hazelnut': 'frappe.jpg',
  'iced mocha': 'frappe.jpg',
  'falooda': 'sundae.jpg',
  'ice cream': 'sundae.jpg',
  'mojito': 'cold_drinks.jpg',
  'iced tea': 'cold_drinks.jpg',
  'ice tea': 'cold_drinks.jpg',
  'juice': 'cold_drinks.jpg',
  'lassi': 'cold_drinks.jpg',
  'chaas': 'cold_drinks.jpg',
  'latte': 'latte.jpg',
  'coffee': 'latte.jpg',
  'cappuccino': 'latte.jpg',
  'americano': 'latte.jpg',
  ' tea': 'tea_pot.jpg',
  'cheese cake': 'cheesecake.png',
  'cheesecake': 'cheesecake.png',
  'strawberry cake': 'cheesecake.png',
  'blueberry cake': 'cheesecake.png',
  'cupcake': 'cupcakes.jpg',
  'brownie': 'brownie.jpg',
  'cookie': 'cookies.png',
  'biscotti': 'cookies.png',
  'croissant': 'croissant.png',
  'pain au chocolat': 'croissant.png',
  'macaron': 'macarons.png',
  'hot dog': 'hotdog.png',
  'buns': 'buns.png',
  'puff': 'buns.png',
  'pav': 'buns.png',
  'cake': 'cake.png',
  'sandwich': 'sandwich.jpg',
  'toast': 'sandwich.jpg',
  'garlic bread': 'sandwich.jpg',
  'pasta': 'pasta.jpg',
  'pizza': 'pizza.jpg',
  'bites': 'bites.jpg',
  'fries': 'fries.jpg',
  'wrap': 'rolls.png',
  'roll': 'rolls.png',
};

String _photo(String name) {
  final n = ' ${name.toLowerCase()}';
  for (final e in _photoFor.entries) {
    if (n.contains(e.key)) return 'https://store.test/${e.value}';
  }
  return '';
}

/// Serves the listing photos from disk in place of the network.
class _LocalPhotos implements BaseCacheManager {
  FileInfo _info(String url) => FileInfo(
        const LocalFileSystem().file('test/store/photos/${Uri.parse(url).pathSegments.last}'),
        FileSource.Cache,
        DateTime.now().add(const Duration(days: 1)),
        url,
      );
  @override
  Stream<FileResponse> getFileStream(String url, {String? key, Map<String, String>? headers, bool withProgress = false}) =>
      Stream.value(_info(url));
  @override
  Future<FileInfo?> getFileFromCache(String key, {bool ignoreMemCache = false}) async => _info(key);
  @override
  Future<FileInfo?> getFileFromMemory(String key) async => _info(key);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Sections and bestsellers lead with dishes that have photos (demo data,
/// curated like any store listing); the menu itself is the shops' real one.
const _leadWith = {
  'teasntrees': ['Almond Gum Special', 'Mojitos', 'Iced Coffee', 'Falooda', 'Cold Coffee', 'Pizza', 'Pasta', 'Sandwich'],
  'littleh': ['Premium Cakes', 'Desserts', 'Cookies', 'Savoury', 'Bento Cake', 'Fresh Cream Cakes'],
};

String _fixture(String brand, String name) {
  final raw = File('$_fixtures/${brand}__$name.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final data = json['data'];
  if (name.startsWith('products')) {
    final list = (data is Map ? data['products'] : data) as List;
    for (final p in list.cast<Map<String, dynamic>>()) {
      p['image'] = _photo(p['name'] as String);
      p['images'] = <String>[];
    }
    if (name.contains('popular')) {
      // Bestsellers: the popular ones that have a photo first.
      list.sort((a, b) => (_photo(b['name']).isEmpty ? 0 : 1).compareTo(_photo(a['name']).isEmpty ? 0 : 1));
    }
  }
  if (name == 'categories' && data is List) {
    final lead = _leadWith[brand]!;
    int rank(dynamic c) {
      final i = lead.indexOf(c['name'] as String);
      return i < 0 ? lead.length : i;
    }
    data.sort((a, b) => rank(a).compareTo(rank(b)));
  }
  return jsonEncode(json);
}

Map<String, dynamic> _products(String brand) =>
    jsonDecode(_fixture(brand, 'products_limit_100_page_1')) as Map<String, dynamic>;

Map<String, dynamic> _product(String brand, String name) {
  final data = _products(brand)['data'];
  final list = (data is Map ? data['products'] : data) as List;
  return list.cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == name);
}

/// The bag: two Teas N Trees items, as a customer would have it.
Map<String, dynamic> _cart() {
  Map<String, dynamic> line(String id, String name, int qty) {
    final p = _product('teasntrees', name);
    return {'_id': id, 'product': p, 'quantity': qty, 'price': p['price'], 'brand': 'teasntrees'};
  }

  final items = [line('c1', 'Spicy Mango Mojito', 2), line('c2', 'Iced caramel Latte', 1), line('c3', 'Mango Falooda', 1)];
  final subtotal = items.fold<num>(0, (s, i) => s + (i['price'] as num) * (i['quantity'] as num));
  return {'success': true, 'data': {'items': items, 'subtotal': subtotal, 'itemCount': 4}};
}

const _address = {
  '_id': 'a1',
  'label': 'Home',
  'addressLine': '12-4-56, Lakshmipuram Main Road, Guntur',
  'isDefault': true,
  'location': {'type': 'Point', 'coordinates': [80.4365, 16.3008]},
};

/// Answers every request the screens make: the shops' real menus from the
/// recorded snapshot, the fictional customer's bag and address, and an empty
/// list for anything else.
MockClient _api() => MockClient((req) async {
      final segs = req.url.pathSegments; // api, <brand>, customer, ...
      final brand = segs.length > 1 ? segs[1] : 'teasntrees';
      final path = segs.skip(3).join('/');
      final q = req.url.queryParameters;
      String? body;
      switch (path) {
        case 'products':
          if (q['sort'] == 'popular') {
            body = _fixture(brand, 'products_limit_10_sort_popular');
          } else if ((q['page'] ?? '1') == '1' && q['category'] == null && q['search'] == null) {
            body = _fixture(brand, 'products_limit_100_page_1');
          } else if (q['category'] != null) {
            final data = _products(brand)['data'];
            final list = (data is Map ? data['products'] : data) as List;
            final inCat = list.where((p) {
              final c = p['category'];
              return (c is Map ? c['_id'] : c) == q['category'];
            }).toList();
            body = jsonEncode({'success': true, 'data': inCat});
          }
        case 'categories':
        case 'settings':
        case 'status':
        case 'promotions':
          body = _fixture(brand, path);
        case 'cart':
          body = jsonEncode(_cart());
        case 'address':
          body = jsonEncode({'success': true, 'data': [_address]});
      }
      return http.Response(body ?? jsonEncode({'success': true, 'data': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    CachedNetworkImageProvider.defaultCacheManager = _LocalPhotos();
    await _font('PleaseDontTakeMyMan', 'assets/fonts/PleaseDontTakeMyMan.ttf');
    // Material icons (back arrows and the like) aren't loaded in widget tests by default.
    final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    await _font('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    for (final w in ['Regular', 'Bold', 'Fill', 'Duotone', 'Light', 'Thin']) {
      final f = 'packages/phosphor_flutter/lib/fonts/Phosphor${w == 'Regular' ? '' : '-$w'}.ttf';
      await _font('packages/phosphor_flutter/Phosphor$w', f);
    }
    // The app's Google fonts (bundled under google_fonts/), loaded up front so
    // the first frame isn't laid out in the test font.
    for (final f in Directory('google_fonts').listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
      final name = f.uri.pathSegments.last.replaceAll('.ttf', ''); // e.g. Poppins-SemiBold
      final family = name.split('-').first;
      final style = name.split('-').last;
      const weights = {'Thin': 100, 'ExtraLight': 200, 'Light': 300, 'Regular': 400, 'Medium': 500, 'SemiBold': 600, 'Bold': 700, 'ExtraBold': 800, 'Black': 900};
      final w = weights[style.replaceAll('Italic', '')] ?? 400;
      final key = w == 400 ? 'regular' : '$w';
      await _font('${family}_$key${style.contains('Italic') ? 'italic' : ''}', f.path);
    }
    // Plugins a widget test has no implementation for.
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (call) async => Directory.systemTemp.path);
  });

  Future<void> render(WidgetTester tester, String name, Widget screen,
      {String brand = 'teasntrees', bool signedOut = false, Future<void> Function()? then}) async {
    // iPhone 6.9": 440 x 956 pt @3x = 1320 x 2868.
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'demo',
      'refresh_token': 'demo',
      'last_visited_store': brand == 'littleh' ? 'bakery' : 'cafe',
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          if (!signedOut) authProvider.overrideWith(_SignedIn.new),
          if (signedOut) phoneSignInProvider.overrideWith(_SignInIdle.new),
        ],
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: Responsive.designSizeFor(MediaQuery.sizeOf(context)),
            minTextAdapt: true,
            // The app follows the selected shop: green for the cafe, rust for the bakery.
            builder: (_, _) => Consumer(
              builder: (_, ref, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: themeFor(ref.watch(brandProvider)),
                home: screen,
              ),
            ),
          ),
        ),
      ));
      // Let the menu load and animations settle (some loop forever, so no pumpAndSettle).
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (then != null) {
        await then();
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump(const Duration(milliseconds: 250));
        }
      }
      // Entrance animations (the welcome headline) take a few seconds to land.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../store/raw/$name.png'));
    }, _api);
  }

  testWidgets('00 welcome', (t) => render(t, '00_welcome', const WelcomeScreen(), signedOut: true));

  testWidgets('01 cafe home', (t) => render(t, '01_cafe', const StoreHomeScreen()));

  testWidgets('02 bakery home', (t) => render(t, '02_bakery', const StoreHomeScreen(), brand: 'littleh'));

  testWidgets('03 menu filter', (t) => render(t, '03_filter', const StoreHomeScreen(), brand: 'littleh', then: () async {
        await t.tap(find.text('Egg').first);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.text('Price').first);
      }));

  testWidgets('04 item', (t) => render(
        t,
        '04_item',
        ItemDetailsScreen(product: Product.fromJson(_product('teasntrees', 'Iced caramel Latte')..['image'] = _photo('Iced caramel Latte'))),
      ));

  // The bag, opened from the menu's View bag bar as a customer would.
  testWidgets('05 bag', (t) => render(t, '05_bag', const StoreHomeScreen(), then: () async {
        await t.tap(find.text('View bag').first);
      }));
}
