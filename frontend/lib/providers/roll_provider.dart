import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';

class RollNotifier extends Notifier<Roll> {
  final String rollId;

  RollNotifier(this.rollId);

  @override
  Roll build() {
    return Roll(
      id: rollId,
      brand: 'Kodak',
      name: 'Portra 400',
      color: Colors.yellow,
      status: RollStatus.shooting,
    );
  }

  void updateStatus(RollStatus newStatus) {
    state = state.copyWith(status: newStatus);
    print('Updating Roll ${state.id} status to ${newStatus.label}');
  }

  void addImages(List<String> urls) {
    state = state.copyWith(imageUrls: [...state.imageUrls, ...urls]);
  }
}

final rollProvider = NotifierProvider.family<RollNotifier, Roll, String>(
  (rollId) => RollNotifier(rollId),
);
