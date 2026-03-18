import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/storage_account.dart';

// Events
abstract class StorageAccountsEvent {}

class LoadStorageAccounts extends StorageAccountsEvent {}

class TogglePrimaryAccount extends StorageAccountsEvent {
  final String accountId;
  TogglePrimaryAccount(this.accountId);
}

// States
abstract class StorageAccountsState {}

class StorageAccountsInitial extends StorageAccountsState {}

class StorageAccountsLoading extends StorageAccountsState {}

class StorageAccountsLoaded extends StorageAccountsState {
  final List<StorageAccount> accounts;
  StorageAccountsLoaded(this.accounts);
}

class StorageAccountsError extends StorageAccountsState {
  final String message;
  StorageAccountsError(this.message);
}

// BLoC
class StorageAccountsBloc extends Bloc<StorageAccountsEvent, StorageAccountsState> {
  StorageAccountsBloc() : super(StorageAccountsInitial()) {
    on<LoadStorageAccounts>((event, emit) async {
      emit(StorageAccountsLoading());
      try {
        // Mocking some data for now
        final accounts = [
          const StorageAccount(
            id: '1',
            name: 'Local Device',
            type: StorageAccountType.local,
            email: 'local@device.com',
            providerName: 'Device',
            isPrimary: true,
          ),
          const StorageAccount(
            id: '2',
            name: 'Personal iCloud',
            type: StorageAccountType.personal,
            email: 'user@icloud.com',
            providerName: 'iCloud',
            isPrimary: false,
          ),
          const StorageAccount(
            id: '2b',
            name: 'Shared Family iCloud',
            type: StorageAccountType.personal,
            email: 'family@icloud.com',
            providerName: 'iCloud',
            isPrimary: false,
          ),
          const StorageAccount(
            id: '4',
            name: 'Work Drive',
            type: StorageAccountType.personal,
            email: 'work@gmail.com',
            providerName: 'Google Drive',
            isPrimary: false,
          ),
          const StorageAccount(
            id: '3',
            name: 'Halide Pro Sync',
            type: StorageAccountType.system,
            email: 'pro@halide.com',
            providerName: 'Halide',
            isPrimary: false,
          ),
        ];
        emit(StorageAccountsLoaded(accounts));
      } catch (e) {
        emit(StorageAccountsError(e.toString()));
      }
    });

    on<TogglePrimaryAccount>((event, emit) async {
      if (state is StorageAccountsLoaded) {
        final currentAccounts = (state as StorageAccountsLoaded).accounts;
        
        // Add haptic feedback for the "Set as Primary" action
        await HapticFeedback.mediumImpact();

        final updatedAccounts = currentAccounts.map((account) {
          if (account.id == event.accountId) {
            return account.copyWith(isPrimary: true);
          } else {
            return account.copyWith(isPrimary: false);
          }
        }).toList();

        emit(StorageAccountsLoaded(updatedAccounts));
      }
    });
  }
}
