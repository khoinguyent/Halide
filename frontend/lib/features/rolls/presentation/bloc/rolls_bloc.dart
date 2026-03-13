import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/models/roll.dart';
import 'package:frontend/features/rolls/data/rolls_repository.dart';

// Events
abstract class RollsEvent {}
class FetchRolls extends RollsEvent {}
class RefreshRolls extends RollsEvent {}

// States
abstract class RollsState {}
class RollsInitial extends RollsState {}
class RollsLoading extends RollsState {}
class RollsLoaded extends RollsState {
  final List<Roll> rolls;
  RollsLoaded(this.rolls);
}
class RollsError extends RollsState {
  final String message;
  RollsError(this.message);
}

// BLoC
class RollsBloc extends Bloc<RollsEvent, RollsState> {
  final RollsRepository repository;

  RollsBloc(this.repository) : super(RollsInitial()) {
    on<FetchRolls>((event, emit) async {
      emit(RollsLoading());
      try {
        final rolls = await repository.getRolls();
        emit(RollsLoaded(rolls));
      } catch (e) {
        emit(RollsError(e.toString()));
      }
    });

    on<RefreshRolls>((event, emit) async {
      try {
        final rolls = await repository.getRolls();
        emit(RollsLoaded(rolls));
      } catch (e) {
        // Option: keep current state or show error snackbar
        emit(RollsError(e.toString()));
      }
    });
  }
}
