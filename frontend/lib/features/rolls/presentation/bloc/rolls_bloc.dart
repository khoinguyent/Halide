import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/models/roll.dart';
import 'package:frontend/features/rolls/data/rolls_repository.dart';

// Events
abstract class RollsEvent {}
class FetchRolls extends RollsEvent {}
class RefreshRolls extends RollsEvent {}
class AddRollEvent extends RollsEvent {
  final String filmStockId;
  final String userCameraId;
  final String? title;
  final String? description;
  final int? shotAtIso;
  final int? expiredYear;
  final int? maxFrames;

  AddRollEvent({
    required this.filmStockId,
    required this.userCameraId,
    this.title,
    this.description,
    this.shotAtIso,
    this.expiredYear,
    this.maxFrames,
  });
}
class UpdateRollStatusEvent extends RollsEvent {
  final String rollId;
  final String status;
  UpdateRollStatusEvent(this.rollId, this.status);
}

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
class RollActionSuccess extends RollsState {}

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

    on<AddRollEvent>((event, emit) async {
      try {
        await repository.createRoll(
          filmStockId: event.filmStockId,
          userCameraId: event.userCameraId,
          title: event.title,
          description: event.description,
          shotAtIso: event.shotAtIso,
          expiredYear: event.expiredYear,
          maxFrames: event.maxFrames,
        );
        emit(RollActionSuccess());
        add(RefreshRolls());
      } catch (e) {
        emit(RollsError(e.toString()));
      }
    });

    on<UpdateRollStatusEvent>((event, emit) async {
      try {
        await repository.updateRollStatus(event.rollId, event.status);
        add(RefreshRolls());
      } catch (e) {
        emit(RollsError(e.toString()));
      }
    });
  }
}
