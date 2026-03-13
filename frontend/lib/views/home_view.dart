import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/roll_card.dart';
import '../providers/dashboard_provider.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../models/roll_status.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}
=======
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/widgets/roll_card.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/providers/rolls_provider.dart';
import 'package:frontend/features/rolls/presentation/bloc/rolls_bloc.dart';

class HomeView extends ConsumerWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rollsBloc = ref.watch(rollsBlocProvider);
>>>>>>> feat/sprint_03/fe_dev_1

class _HomeViewState extends ConsumerState<HomeView> {
  RollStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final rollsAsync = ref.watch(dashboardRollsProvider);

    return HalideScaffold(
      appBar: AppBar(
        title: const Text(
          'YOUR ROLLS',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add roll',
            onPressed: () {
              // TODO: navigate to add-roll flow or show bottom sheet
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
<<<<<<< HEAD
      child: rollsAsync.when(
        data: (rolls) {
          final filtered = _statusFilter == null
              ? rolls
              : rolls.where((r) => r.status == _statusFilter).toList();
          if (filtered.isEmpty) {
            return _buildEmptyOrNoMatch(rolls.isEmpty);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(dashboardRollsProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildStatusFilter(),
                const SizedBox(height: 16),
                ...List.generate(filtered.length, (index) {
                  final roll = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: GestureDetector(
                      onTap: () => context.push('/roll/${roll.id}'),
                      child: RollCard(roll: roll),
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (err, stack) => _ErrorState(
          error: err.toString(),
          onRetry: () => ref.refresh(dashboardRollsProvider),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: _statusFilter == null,
            onTap: () => setState(() => _statusFilter = null),
          ),
          const SizedBox(width: 8),
          ...RollStatus.values.map((status) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _FilterChip(
                  label: status.label,
                  selected: _statusFilter == status,
                  onTap: () => setState(() => _statusFilter = status),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyOrNoMatch(bool noRollsAtAll) {
    if (noRollsAtAll) return const _EmptyState();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'No rolls with status "${_statusFilter!.label}"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _statusFilter = null),
              child: const Text('Clear filter', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Colors.white38 : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_roll_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 20),
              const Text(
                'No rolls yet',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your first roll of film to start tracking your frames.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ADD FIRST ROLL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({Key? key, required this.error, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('RETRY'),
              ),
            ],
          ),
=======
      body: BlocProvider.value(
        value: rollsBloc,
        child: BlocBuilder<RollsBloc, RollsState>(
          builder: (context, state) {
            if (state is RollsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is RollsError) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is RollsLoaded) {
              if (state.rolls.isEmpty) {
                return const Center(child: Text('No rolls found. Start one!'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  rollsBloc.add(RefreshRolls());
                  // Wait for first state change or timeout
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: state.rolls.length,
                  itemBuilder: (context, index) {
                    final roll = state.rolls[index];
                    // Temporary: Map roll to a dummy FilmStock for the UI card
                    final dummyStock = FilmStock(
                      id: roll.filmStockId,
                      brand: 'Kodak', 
                      name: 'Portra 400', 
                      iso: 400, 
                      format: '135', 
                      colorType: 'Color Negative'
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GestureDetector(
                        onTap: () => context.push('/roll/${roll.id}'),
                        child: RollCard(filmStock: dummyStock),
                      ),
                    );
                  },
                ),
              );
            }
            return const Center(child: Text('Initialize to load rolls.'));
          },
>>>>>>> feat/sprint_03/fe_dev_1
        ),
      ),
      // FAB is now managed by HalideScaffold in the main shell
    );
  }
}
