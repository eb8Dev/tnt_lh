import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the profile has edits the user hasn't saved. The profile is a tab
/// inside an IndexedStack, not a pushed route, so there's no Navigator pop to
/// hook — the shell reads this before letting them leave the tab.
class UnsavedChangesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool dirty) => state = dirty;
}

final profileHasUnsavedChangesProvider =
    NotifierProvider<UnsavedChangesNotifier, bool>(
      UnsavedChangesNotifier.new,
    );
