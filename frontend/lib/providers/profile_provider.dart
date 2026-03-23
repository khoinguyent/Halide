import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());
