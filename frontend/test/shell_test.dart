import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/shell/presentation/widgets/halide_scaffold.dart';
import 'package:frontend/features/shell/presentation/widgets/glass_navigation_dock.dart';

void main() {
  testWidgets('HalideScaffold renders with GlassNavigationDock and FAB', (WidgetTester tester) async {
    int selectedIndex = 0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: HalideScaffold(
          currentIndex: selectedIndex,
          onTabSelected: (index) => selectedIndex = index,
          child: const Center(child: Text('Home Content')),
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
    await tester.pump();

    // Verify FAB color change (active state)
    final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    expect(fab.backgroundColor, Colors.redAccent);
  });
}
