import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/storage/presentation/views/storage_account_list_view.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/features/storage/presentation/widgets/storage_tier_selector.dart';

void main() {
  testWidgets('StorageAccountListView renders and contains necessary elements', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StorageAccountListView(),
      ),
    );

    // Verify Title
    expect(find.text('Storage Management'), findsOneWidget);

    // Verify Tier Selector
    expect(find.byType(StorageTierSelector), findsOneWidget);

    // Initial loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for BLoC mock data to load and animations to finish
    await tester.pump(const Duration(milliseconds: 100)); // Initial pump for BLoC trigger
    await tester.pumpAndSettle(); // Wait for state transition and possible animations

    // Verify list items once loaded
    expect(find.text('Connected Accounts'), findsOneWidget);
    expect(find.text('Local Device'), findsOneWidget);
    expect(find.text('Personal iCloud'), findsOneWidget);
    expect(find.text('Halide Pro Sync'), findsOneWidget);
  });
}
