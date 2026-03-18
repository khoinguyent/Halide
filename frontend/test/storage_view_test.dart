import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/storage/presentation/views/storage_account_list_view.dart';
import 'package:frontend/features/storage/presentation/widgets/storage_tier_selector.dart';

void main() {
  testWidgets('StorageAccountListView renders and handles tier switching', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StorageAccountListView(),
      ),
    );

    // Verify Title
    expect(find.text('Storage Management'), findsOneWidget);

    // Wait for BLoC mock data
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // -- Tier 0: Local --
    expect(find.text('LOCAL ACCOUNTS'), findsOneWidget);
    
    // -- Switch to Tier 1: Personal Cloud --
    await tester.tap(find.text('Personal Cloud'));
    await tester.pumpAndSettle();
    expect(find.text('CLOUD PROVIDERS'), findsOneWidget);

    // -- Switch to Tier 2: System Cloud --
    await tester.tap(find.text('System Cloud'));
    await tester.pumpAndSettle();
    expect(find.text('SYSTEM CLOUD'), findsOneWidget);
  });
}
