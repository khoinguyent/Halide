import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/features/shell/presentation/bloc/frame_logging_bloc.dart';
import 'package:frontend/features/shell/presentation/widgets/glass_navigation_dock.dart';
import 'package:frontend/providers/rolls_provider.dart';
import 'package:frontend/providers/dashboard_provider.dart';
import 'package:frontend/features/rolls/presentation/widgets/add_roll_form.dart';
import 'package:frontend/features/rolls/presentation/bloc/rolls_bloc.dart';
import 'package:frontend/features/gear/presentation/widgets/add_gear_form.dart';
import 'package:frontend/providers/gear_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/ui_state_provider.dart';

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
      child: Stack(
        children: [
          Scaffold(
            extendBody: true,
            body: child,
            bottomNavigationBar: GlassNavigationDock(
              currentIndex: currentIndex,
              onTabSelected: (index) {
                // Keep the active tab provider in sync for individual views (like Light Meter camera)
                ref.read(homeTabIndexProvider.notifier).setIndex(index);
                onTabSelected(index);
              },
              plan: ref.watch(userPlanProvider),
            ),
          ),
          Positioned(
            bottom: 56,
            left: 0,
            right: 0,
            child: Center(
              child: BlocBuilder<FrameLoggingBloc, FrameLoggingState>(
                builder: (context, state) {
                  final isActive = state is FrameLoggingActive;
                  return FloatingActionButton(
                    onPressed: () {
                      if (isActive) {
                        context.read<FrameLoggingBloc>().add(LogFrame({}));
                      } else {
                        // Context-aware FAB: Add Roll on Home(0), Add Gear on Locker(1)
                        final isLocker = currentIndex == 1;
                        
                        showHalideDialog(
                          context: context,
                          builder: (context) {
                            if (isLocker) {
                              return AddGearForm(
                                onGearAdded: () => ref.invalidate(userGearProvider),
                              );
                            }
                            return BlocProvider.value(
                              value: ref.read(rollsBlocProvider),
                              child: AddRollForm(
                                repository: ref.read(rollsRepositoryProvider),
                                onRollAdded: () => ref.invalidate(dashboardRollsProvider),
                              ),
                            );
                          },
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
          ),
        ],
      ),
    );
  }
}
