import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/features/shell/presentation/bloc/frame_logging_bloc.dart';
import 'package:frontend/features/shell/presentation/widgets/glass_navigation_dock.dart';
import 'package:frontend/providers/rolls_provider.dart';
import 'package:frontend/features/rolls/presentation/widgets/add_roll_form.dart';
import 'package:frontend/features/rolls/presentation/bloc/rolls_bloc.dart';

class HalideScaffold extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                    // Show premium glass Add Roll form
                    showHalideDialog(
                      context: context,
                      builder: (context) => AddRollForm(
                        repository: ref.read(rollsRepositoryProvider),
                        onRollAdded: () {
                          ref.read(rollsBlocProvider).add(RefreshRolls());
                        },
                      ),
                    );
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
