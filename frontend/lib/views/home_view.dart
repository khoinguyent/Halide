import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/roll_card.dart';
import '../models/film_stock.dart';

class HomeView extends StatelessWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock data for UI
    final mockRolls = [
      FilmStock(brand: 'Kodak', name: 'Portra 400', color: Colors.yellow, id: '1'),
      FilmStock(brand: 'Fujifilm', name: 'Superia X-TRA 400', color: Colors.green, id: '2'),
      FilmStock(brand: 'Ilford', name: 'HP5 Plus 400', color: Colors.grey, id: '3'),
    ];

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
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: mockRolls.length,
        itemBuilder: (context, index) {
          final roll = mockRolls[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: GestureDetector(
              onTap: () => context.push('/roll/${roll.id}'),
              child: RollCard(filmStock: roll),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
