import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/storage/presentation/views/storage_strategy_view.dart';
import 'package:frontend/features/storage/presentation/widgets/cloud_providers_section.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/models/user_profile.dart';

class FakeStorageAccountsBloc extends Bloc<StorageAccountsEvent, StorageAccountsState> implements StorageAccountsBloc {
  FakeStorageAccountsBloc() : super(StorageAccountsLoaded([])) {
    on<LoadStorageAccounts>((event, emit) {});
    on<TogglePrimaryAccount>((event, emit) {});
    on<UpdateStorageAccountFlags>((event, emit) {});
    on<RemoveStorageAccounts>((event, emit) {});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      return null;
    });
  });

  testWidgets('StorageStrategyView defaults to Local Device for Free plan', (WidgetTester tester) async {
    final fakeBloc = FakeStorageAccountsBloc();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPlanProvider.overrideWithValue(UserPlan.free),
        ],
        child: MaterialApp(
          home: StorageStrategyView(bloc: fakeBloc),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('STORAGE STRATEGY'), findsOneWidget);
    
    // Default should be Local Storage
    expect(find.text('LOCAL STORAGE'), findsOneWidget);
    expect(find.byType(CloudProvidersSection), findsNothing);
  });

  testWidgets('StorageStrategyView defaults to Personal Cloud for Plus plan', (WidgetTester tester) async {
    final fakeBloc = FakeStorageAccountsBloc();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPlanProvider.overrideWithValue(UserPlan.plus),
        ],
        child: MaterialApp(
          home: StorageStrategyView(bloc: fakeBloc),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('STORAGE STRATEGY'), findsOneWidget);
    
    // Default should be Personal Cloud (index 1) which shows CloudProvidersSection
    expect(find.byType(CloudProvidersSection), findsOneWidget);
    expect(find.text('Cloud providers'), findsOneWidget);
  });
}
