import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the selected tab index for each roll/folder in a session using a map.
class RollTabNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  void setTab(String rollId, int index) {
    state = {...state, rollId: index};
  }
}

final rollTabStateProvider = NotifierProvider<RollTabNotifier, Map<String, int>>(RollTabNotifier.new);

class HomeTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final homeTabIndexProvider = NotifierProvider<HomeTabIndexNotifier, int>(HomeTabIndexNotifier.new);
