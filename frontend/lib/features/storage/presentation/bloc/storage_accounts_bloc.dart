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

class UpdateStorageAccountFlags extends StorageAccountsEvent {
  final String accountId;
  final bool? isArchive;
  final bool? isScanSync;
  UpdateStorageAccountFlags({required this.accountId, this.isArchive, this.isScanSync});
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
      // Local device entry is always present.
      var localAccount = const StorageAccount(
        id: 'local_device',
        name: 'Local Device',
        type: StorageAccountType.local,
        email: '',
        providerName: 'Device',
        isPrimary: true,
      );
      
      emit(StorageAccountsLoaded([localAccount]));

      try {
        final connectionsResp = await _api.get('/api/v1/connections');
        final raw = connectionsResp.data;

        final connectedAccounts = <StorageAccount>[];
        bool hasCloudPrimary = false;

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
            final isArchive = (m['is_archive'] as bool?) ?? false;
            final isScanSync = (m['is_scan_sync'] as bool?) ?? false;
            final storageUsed = (m['storage_used'] as int?);
            final storageLimit = (m['storage_limit'] as int?);

            if (isPrimary) hasCloudPrimary = true;

            connectedAccounts.add(
              StorageAccount(
                id: id.isEmpty ? '${provider}_$identifier' : id,
                name: (displayLabel != null && displayLabel.isNotEmpty)
                    ? displayLabel
                    : providerName,
                type: provider == 'system' ? StorageAccountType.system : StorageAccountType.personal,
                email: identifier,
                providerName: providerName,
                isPrimary: isPrimary,
                isArchive: isArchive,
                isScanSync: isScanSync,
                storageUsed: storageUsed,
                storageLimit: storageLimit,
              ),
            );
          }
        }

        // If a cloud account is primary, local device should not be.
        if (hasCloudPrimary) {
          localAccount = localAccount.copyWith(isPrimary: false);
        }

        // Emit updated list with both local and connected accounts
        emit(StorageAccountsLoaded([localAccount, ...connectedAccounts]));
      } catch (e) {
        // Even if connections fail, we keep the local account loaded.
      }
    });

    on<TogglePrimaryAccount>((event, emit) async {
      if (state is StorageAccountsLoaded) {
        final currentAccounts = (state as StorageAccountsLoaded).accounts;
        await HapticFeedback.mediumImpact();

        try {
          // If the new primary is a cloud account, update backend.
          if (event.accountId != 'local_device') {
            await _api.patch('/api/v1/connections/${event.accountId}', data: {'is_primary': true});
          } else {
            // Unset current cloud primary if setting local as primary.
            final cloudPrimary = currentAccounts.firstWhere(
              (a) => a.type != StorageAccountType.local && a.isPrimary,
              orElse: () => currentAccounts.first,
            );
            if (cloudPrimary.id != 'local_device') {
              await _api.patch('/api/v1/connections/${cloudPrimary.id}', data: {'is_primary': false});
            }
          }

          final updatedAccounts = currentAccounts.map((account) {
            return account.copyWith(isPrimary: account.id == event.accountId);
          }).toList();

          emit(StorageAccountsLoaded(updatedAccounts));
        } catch (e) {
          emit(StorageAccountsError('Failed to update primary storage: $e'));
        }
      }
    });

    on<UpdateStorageAccountFlags>((event, emit) async {
      try {
        final data = <String, dynamic>{};
        if (event.isArchive != null) data['is_archive'] = event.isArchive;
        if (event.isScanSync != null) data['is_scan_sync'] = event.isScanSync;

        await _api.patch('/api/v1/connections/${event.accountId}', data: data);
        add(LoadStorageAccounts());
      } catch (e) {
        emit(StorageAccountsError(e.toString()));
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
      case 'ftp':
        return 'FTP Storage';
      case 'smb':
        // Matches CloudProvidersSection provider list label.
        return 'SMB / Network';
      case 'system':
        return 'System Cloud';
      default:
        return null;
    }
  }
}
