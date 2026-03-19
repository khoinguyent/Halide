import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/storage_account.dart';
import 'package:frontend/services/api_service.dart';

// Events
abstract class StorageAccountsEvent {}

class LoadStorageAccounts extends StorageAccountsEvent {}

class TogglePrimaryAccount extends StorageAccountsEvent {
  final String accountId;
  TogglePrimaryAccount(this.accountId);
}

class RemoveStorageAccounts extends StorageAccountsEvent {
  final List<String> accountIds;
  RemoveStorageAccounts(this.accountIds);
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
  final ApiService _api;

  StorageAccountsBloc({ApiService? api}) : _api = api ?? ApiService(), super(StorageAccountsInitial()) {
    on<LoadStorageAccounts>((event, emit) async {
      emit(StorageAccountsLoading());
      try {
        final connectionsResp = await _api.get('/api/v1/connections');
        final raw = connectionsResp.data;

        final connectedAccounts = <StorageAccount>[];
        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item as Map);
            final provider = (m['provider'] as String?) ?? '';
            final providerName = _providerDisplayName(provider);
            if (providerName == null) continue;

            final id = (m['id'] as String?) ?? '';
            final identifier = (m['identifier'] as String?) ?? '';
            final displayLabel = (m['display_label'] as String?)?.trim();
            final isPrimary = (m['is_primary'] as bool?) ?? false;

            connectedAccounts.add(
              StorageAccount(
                id: id.isEmpty ? '${provider}_$identifier' : id,
                name: (displayLabel != null && displayLabel.isNotEmpty)
                    ? displayLabel
                    : providerName,
                type: StorageAccountType.personal,
                email: identifier,
                providerName: providerName,
                isPrimary: isPrimary,
              ),
            );
          }
        }

        // Local device entry is not stored in backend storage_credentials; keep a stable local row.
        final accounts = <StorageAccount>[
          const StorageAccount(
            id: 'local_device',
            name: 'Local Device',
            type: StorageAccountType.local,
            email: 'local@device.com',
            providerName: 'Device',
            isPrimary: true,
          ),
          ...connectedAccounts,
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

    on<RemoveStorageAccounts>((event, emit) async {
      try {
        for (final id in event.accountIds) {
          if (id == 'local_device') continue;
          await _api.delete('/api/v1/connections/$id');
        }
        add(LoadStorageAccounts());
      } catch (e) {
        emit(StorageAccountsError(e.toString()));
      }
    });
  }

  static String? _providerDisplayName(String provider) {
    switch (provider) {
      case 'icloud':
        return 'iCloud';
      case 'gdrive':
        return 'Google Drive';
      case 'onedrive':
        return 'OneDrive';
      case 'nas':
        return 'NAS';
      case 'smb':
        // Matches CloudProvidersSection provider list label.
        return 'SMB / Network';
      default:
        return null;
    }
  }
}
