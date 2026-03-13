import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class FrameLoggingEvent {}
class StartFrameLogging extends FrameLoggingEvent {
  final String rollId;
  StartFrameLogging(this.rollId);
}
class StopFrameLogging extends FrameLoggingEvent {}
class LogFrame extends FrameLoggingEvent {
  final Map<String, dynamic> metadata;
  LogFrame(this.metadata);
}

// States
abstract class FrameLoggingState {}
class FrameLoggingInitial extends FrameLoggingState {}
class FrameLoggingActive extends FrameLoggingState {
  final String rollId;
  final int frameCount;
  FrameLoggingActive({required this.rollId, this.frameCount = 0});
}
class FrameLoggingSuccess extends FrameLoggingState {}
class FrameLoggingFailure extends FrameLoggingState {
  final String error;
  FrameLoggingFailure(this.error);
}

// BLoC
class FrameLoggingBloc extends Bloc<FrameLoggingEvent, FrameLoggingState> {
  FrameLoggingBloc() : super(FrameLoggingInitial()) {
    on<StartFrameLogging>((event, emit) {
      emit(FrameLoggingActive(rollId: event.rollId));
    });
    
    on<StopFrameLogging>((event, emit) {
      emit(FrameLoggingInitial());
    });

    on<LogFrame>((event, emit) {
      if (state is FrameLoggingActive) {
        final activeState = state as FrameLoggingActive;
        emit(FrameLoggingActive(
          rollId: activeState.rollId,
          frameCount: activeState.frameCount + 1,
        ));
      }
    });
  }
}
