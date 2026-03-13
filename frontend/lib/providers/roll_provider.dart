import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../services/roll_service.dart';
import 'auth_provider.dart';

final rollServiceProvider = Provider<RollService>((ref) => RollService());

final userRollsProvider = FutureProvider<List<dynamic>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final rollService = ref.watch(rollServiceProvider);
  
  final user = authService.currentUser;
  if (user == null) return [];
  
  final token = await user.getIdToken();
  if (token == null) return [];
  
  return await rollService.fetchRolls(token);
});

class RollNotifier extends Notifier<Roll> {
  final String rollId;

  RollNotifier(this.rollId);

  @override
  Roll build() {
    // Current fallback, should ideally fetch from state or API
    return Roll(
      id: rollId,
      brand: 'Kodak',
      name: 'Portra 400',
      color: Colors.yellow,
      status: RollStatus.shooting,
    );
  }

  Future<void> updateStatus(RollStatus newStatus) async {
    state = state.copyWith(status: newStatus);
    
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        // TODO: Implement PATCH /rolls/{id} in RollService
        print('Updating Roll ${state.id} status to ${newStatus.label} on backend');
      }
    }
  }

  void addImages(List<String> urls) {
    state = state.copyWith(imageUrls: [...state.imageUrls, ...urls]);
  }
}

final rollProvider = NotifierProvider.family<RollNotifier, Roll, String>(
  (rollId) => RollNotifier(rollId),
);
