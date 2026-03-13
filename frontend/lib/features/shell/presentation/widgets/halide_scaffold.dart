import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/frame_logging_bloc.dart';
import 'glass_navigation_dock.dart';

class HalideScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onTabSelected;

  const HalideScaffold({
    Key? key,
    required this.child,
    required this.currentIndex,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FrameLoggingBloc(),
      child: Scaffold(
        extendBody: true,
        body: child,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(top: 32),
          child: BlocBuilder<FrameLoggingBloc, FrameLoggingState>(
            builder: (context, state) {
              final isActive = state is FrameLoggingActive;
              return FloatingActionButton(
                onPressed: () {
                  if (isActive) {
                    context.read<FrameLoggingBloc>().add(LogFrame({}));
                  } else {
                    // In a real app, we'd pick a roll ID
                    context.read<FrameLoggingBloc>().add(StartFrameLogging('current_roll'));
                  }
                },
                backgroundColor: isActive ? Colors.redAccent : Colors.black,
                shape: const CircleBorder(),
                elevation: 4,
                child: Icon(
                  isActive ? Icons.camera : Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              );
            }
          ),
        ),
        bottomNavigationBar: GlassNavigationDock(
          currentIndex: currentIndex,
          onTabSelected: onTabSelected,
        ),
      ),
    );
  }
}
