import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/shell/presentation/widgets/halide_scaffold.dart';
import 'package:frontend/features/shell/presentation/widgets/glass_navigation_dock.dart';
import 'package:frontend/features/rolls/presentation/widgets/add_roll_form.dart';
import 'package:frontend/providers/rolls_provider.dart';
import 'package:frontend/features/rolls/data/rolls_repository.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/camera.dart';
import 'package:frontend/models/roll.dart';

class MockRollsRepository implements RollsRepository {
  @override
  Future<List<Roll>> getRolls() async => [];
  
  @override
  Future<List<FilmStock>> getFilmStocks() async => [];
  
  @override
  Future<List<Camera>> getCameras() async => [];
  
  @override
  Future<Roll> createRoll({required String filmStockId, required String userCameraId, int? shotAtIso, int? expiredYear}) async {
    return Roll(
      id: 'new_id',
      userId: 'user',
      filmStockId: filmStockId,
      userCameraId: userCameraId,
      status: 'shooting',
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  testWidgets('HalideScaffold renders with GlassNavigationDock and FAB', (WidgetTester tester) async {
    int selectedIndex = 0;
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rollsRepositoryProvider.overrideWithValue(MockRollsRepository()),
        ],
        child: MaterialApp(
          home: HalideScaffold(
            currentIndex: selectedIndex,
            onTabSelected: (index) => selectedIndex = index,
            child: const Center(child: Text('Home Content')),
          ),
        ),
      ),
    );

    // Verify content
    expect(find.text('Home Content'), findsOneWidget);

    // Verify GlassNavigationDock
    expect(find.byType(GlassNavigationDock), findsOneWidget);

    // Verify FAB
    expect(find.byType(FloatingActionButton), findsOneWidget);
    
    // Tap FAB and trigger rebuild
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle(); // Wait for dialog animation

    // Verify AddRollForm dialog appears
    expect(find.byType(AddRollForm), findsOneWidget);
    expect(find.text('ADD NEW ROLL'), findsOneWidget);
  });
}
