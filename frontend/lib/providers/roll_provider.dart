import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import 'package:flutter/material.dart';

class RollNotifier extends FamilyNotifier<Roll, String> {
  @override
  Roll build(String arg) {
    // In a real app, this would fetch from a repository or initial state
    return Roll(
      id: arg,
      brand: 'Kodak',
      name: 'Portra 400',
      color: Colors.yellow,
      status: RollStatus.shooting,
    );
  }

  void updateStatus(RollStatus newStatus) {
    state = state.copyWith(status: newStatus);
    // TODO: Sync with backend
    print('Updating Roll ${state.id} status to ${newStatus.label}');
  }
}

final rollProvider = NotifierProvider.family<RollNotifier, Roll, String>(() {
  return RollNotifier();
});
