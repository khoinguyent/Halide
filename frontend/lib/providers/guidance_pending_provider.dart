import 'package:flutter_riverpod/flutter_riverpod.dart';

/// After saving a Drive URL from the sheet, set so Archive can show sync guidance.
class SyncGuidanceRollIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPending(String? rollId) => state = rollId;
}

final syncGuidanceRollIdProvider =
    NotifierProvider<SyncGuidanceRollIdNotifier, String?>(SyncGuidanceRollIdNotifier.new);
