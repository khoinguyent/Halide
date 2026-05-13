import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after a successful storage IAP so [StorageStrategyView] rebuilds its
/// [StorageAccountsBloc] and refetches `/api/v1/storage/.../connections`.
class StorageAccountsListVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final storageAccountsListVersionProvider =
    NotifierProvider<StorageAccountsListVersion, int>(StorageAccountsListVersion.new);
