import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/rolls_provider.dart';
import 'package:frontend/features/rolls/presentation/bloc/rolls_bloc.dart';
import 'package:frontend/widgets/full_screen_viewer.dart';
import 'package:frontend/models/roll.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/camera.dart';

class RollDetailView extends ConsumerWidget {
  final String rollId;

  const RollDetailView({Key? key, required this.rollId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rollsState = ref.watch(rollsBlocProvider).state;
    
    Roll? roll;
    if (rollsState is RollsLoaded) {
      try {
        roll = rollsState.rolls.firstWhere((r) => r.id == rollId);
      } catch (_) {}
    }

    if (roll == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Roll not found')),
      );
    }

    // Dummy images for gallery
    final isScanned = roll.status.toUpperCase() == 'SCANNED';
    final dummyImages = List.generate(
      24, 
      (i) => 'https://picsum.photos/seed/${roll!.id}_$i/800/600'
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(roll.title ?? 'Roll Detail'),
        backgroundColor: Colors.black,
      ),
      body: isScanned 
          ? _buildGalleryGrid(context, roll, dummyImages)
          : const Center(child: Text('This roll is not yet SCANNED', style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildGalleryGrid(BuildContext context, Roll roll, List<String> images) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            // Push FullScreenViewer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FullScreenViewer(
                  imageUrls: images,
                  initialIndex: index,
                  iso: roll.shotAtIso,
                  dateScanned: DateTime.now(),
                  // Dummy metadata for visual tokens
                  filmStock: FilmStock(id: '', brand: 'KODAK', name: 'PORTRA 400', iso: 400, format: '135', colorType: 'Color'),
                  camera: Camera(id: '', brand: 'LEICA', model: 'M6', cameraType: 'Rangefinder', nickname: 'My Leica'),
                ),
              ),
            );
          },
          child: Hero(
            tag: images[index],
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(images[index]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
