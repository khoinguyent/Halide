import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/models/storage_account.dart';
import 'package:frontend/services/api_service.dart';
import 'package:dio/dio.dart';

class MockApiService implements ApiService {
  late Response Function(String path) getHandler;
  late Response Function(String path, dynamic data) patchHandler;

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return getHandler(path);
  }

  @override
  Future<Response> patch(String path, {dynamic data}) async {
    return patchHandler(path, data);
  }

  @override
  Future<Response> post(String path, {dynamic data}) => throw UnimplementedError();

  @override
  Future<Response> delete(String path, {dynamic data}) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      return null;
    });
  });

  test('LoadStorageAccounts sets local_device as primary if no cloud accounts', () async {
    final mockApi = MockApiService();
    mockApi.getHandler = (path) => Response(
          data: [],
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
        );

    final bloc = StorageAccountsBloc(api: mockApi);
    bloc.add(LoadStorageAccounts());

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<StorageAccountsLoaded>().having((s) => s.accounts.first.isPrimary, 'initial local primary', true),
        isA<StorageAccountsLoaded>().having((s) => s.accounts.first.isPrimary, 'final local primary', true),
      ]),
    );
  });

  test('LoadStorageAccounts unsets local_device as primary if cloud account is primary', () async {
    final mockApi = MockApiService();
    mockApi.getHandler = (path) => Response(
          data: [
            {
              'id': 'cloud_1',
              'provider': 'gdrive',
              'identifier': 'test@gmail.com',
              'is_primary': true,
            }
          ],
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
        );

    final bloc = StorageAccountsBloc(api: mockApi);
    bloc.add(LoadStorageAccounts());

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<StorageAccountsLoaded>().having((s) => s.accounts.first.isPrimary, 'initial local primary', true),
        isA<StorageAccountsLoaded>().having((s) => s.accounts.first.isPrimary, 'final local primary', false),
      ]),
    );
  });

  test('TogglePrimaryAccount unsets local and sets cloud on backend', () async {
    final mockApi = MockApiService();
    bool patchCalled = false;
    mockApi.getHandler = (path) => Response(
          data: [
            {
              'id': 'cloud_1',
              'provider': 'gdrive',
              'identifier': 'test@gmail.com',
              'is_primary': false,
            }
          ],
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
        );
    mockApi.patchHandler = (path, data) {
      if (path == '/api/v1/connections/cloud_1' && data['is_primary'] == true) {
        patchCalled = true;
      }
      return Response(data: {}, statusCode: 200, requestOptions: RequestOptions(path: path));
    };

    final bloc = StorageAccountsBloc(api: mockApi);
    
    bloc.add(LoadStorageAccounts()); 
    // Wait for the final loaded state (local + cloud_1)
    await expectLater(
      bloc.stream, 
      emitsThrough(isA<StorageAccountsLoaded>().having((s) => s.accounts.length, 'two accounts', 2)),
    );

    // Now toggle
    bloc.add(TogglePrimaryAccount('cloud_1'));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<StorageAccountsLoaded>().having((s) => s.accounts.any((a) => a.id == 'cloud_1' && a.isPrimary), 'cloud is primary', true),
      ),
    );
    expect(patchCalled, true);
  });
}
