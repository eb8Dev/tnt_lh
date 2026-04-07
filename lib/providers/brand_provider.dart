import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tnt_lh/core/config.dart';

class BrandNotifier extends Notifier<String> {
  @override
  String build() {
    _init();
    return AppConfig.defaultBrand;
  }

  final _storage = const FlutterSecureStorage();

  Future<void> _init() async {
    final lastStore = await _storage.read(key: 'last_visited_store');
    if (lastStore != null) {
      if (lastStore == 'cafe') {
        state = 'teasntrees';
      } else if (lastStore == 'bakery') {
        state = 'littleh';
      }
    }
  }

  Future<void> setBrand(String brand) async {
    state = brand;
    final storeId = brand == 'teasntrees' ? 'cafe' : 'bakery';
    await _storage.write(key: 'last_visited_store', value: storeId);
  }
}

final brandProvider = NotifierProvider<BrandNotifier, String>(() {
  return BrandNotifier();
});
