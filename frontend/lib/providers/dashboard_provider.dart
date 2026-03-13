import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../services/roll_service.dart';
import 'auth_provider.dart';
import 'roll_provider.dart';

final dashboardRollsProvider = FutureProvider<List<Roll>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final rollService = ref.watch(rollServiceProvider);
  
  final user = authService.currentUser;
  if (user == null) {
    // For demo/unauthenticated development, return mock data
    return _mockDashboardData();
  }
  
  try {
    final token = await user.getIdToken();
    if (token == null) return _mockDashboardData();
    
    final rawRolls = await rollService.fetchRolls(token);
    return rawRolls.map((e) => Roll.fromJson(e)).toList();
  } catch (e) {
    // Fail gracefully for now
    return _mockDashboardData();
  }
});

List<Roll> _mockDashboardData() {
  return [
    Roll(
      id: '1',
      brand: 'Kodak',
      name: 'Portra 400',
      color: const Color(0xFFFFCC33),
      status: RollStatus.shooting,
      nickname: 'Birthday Roll',
      cameraName: 'Leica M6',
      lensName: '35mm Summicron',
      frameCount: 24,
      maxFrames: 36,
    ),
    Roll(
      id: '2',
      brand: 'Fujifilm',
      name: 'Superia 400',
      color: const Color(0xFF00AA55),
      status: RollStatus.lab,
      nickname: 'Japan Trip',
      cameraName: 'Contax T2',
    ),
    Roll(
      id: '3',
      brand: 'Ilford',
      name: 'HP5 Plus',
      color: const Color(0xFF333333),
      status: RollStatus.scanned,
      nickname: 'Street 01',
      cameraName: 'Leica M6',
      imageUrls: [
        'https://images.unsplash.com/photo-1554080353-a576cf803bda',
        'https://images.unsplash.com/photo-1508919892451-4e83f94c450a',
        'https://images.unsplash.com/photo-1542038784456-1ea8e935640e',
      ],
    ),
  ];
}
