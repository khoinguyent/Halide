import 'package:flutter/material.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halide - Rolls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
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
        ),
      ),
      // FAB is now managed by HalideScaffold in the main shell
    );
  }
}
