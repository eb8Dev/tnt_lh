import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/address_model.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/services/address_service.dart';

/// The customer's address book, and where the next order goes.
class AddressBook {
  final List<SavedAddress> addresses;

  /// Chosen in the "Deliver to" switcher. Falls back to the default address,
  /// then the first one.
  final String? selectedId;

  const AddressBook({this.addresses = const [], this.selectedId});

  SavedAddress? get selected =>
      addresses.where((a) => a.id == selectedId).firstOrNull ??
      addresses.where((a) => a.isDefault).firstOrNull ??
      addresses.firstOrNull;
}

/// One place for addresses. The home header, the bag and the profile each
/// used to load their own copy, so picking an address in one never showed up
/// in the others.
class AddressBookNotifier extends AsyncNotifier<AddressBook> {
  @override
  FutureOr<AddressBook> build() async {
    final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));
    if (!signedIn) return const AddressBook();
    return AddressBook(addresses: await AddressService.getAddresses());
  }

  Future<void> refresh({String? select}) async {
    final keep = select ?? state.value?.selectedId;
    final list = await AddressService.getAddresses();
    state = AsyncData(AddressBook(addresses: list, selectedId: keep));
  }

  /// Deliver the next order here (this session only; the default is what a
  /// fresh start picks).
  void select(String id) {
    final book = state.value;
    if (book == null) return;
    state = AsyncData(AddressBook(addresses: book.addresses, selectedId: id));
  }

  Future<void> setDefault(String id) async {
    await AddressService.setDefault(id);
    await refresh();
  }

  Future<void> delete(String id) async {
    await AddressService.deleteAddress(id);
    final keep = state.value?.selectedId == id ? null : state.value?.selectedId;
    final list = await AddressService.getAddresses();
    state = AsyncData(AddressBook(addresses: list, selectedId: keep));
  }
}

final addressBookProvider =
    AsyncNotifierProvider<AddressBookNotifier, AddressBook>(
      AddressBookNotifier.new,
    );
