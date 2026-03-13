import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/features/rolls/data/rolls_repository.dart';
import 'package:frontend/features/rolls/presentation/bloc/rolls_bloc.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final rollsRepositoryProvider = Provider<RollsRepository>((ref) {
  return RollsRepository(ref.watch(apiServiceProvider));
});

final rollsBlocProvider = Provider<RollsBloc>((ref) {
  final bloc = RollsBloc(ref.watch(rollsRepositoryProvider));
  bloc.add(FetchRolls());
  return bloc;
});
