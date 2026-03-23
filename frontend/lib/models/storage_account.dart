enum StorageAccountType {
  local,
  personal,
  system,
}

class StorageAccount {
  final String id;
  final String name;
  final StorageAccountType type;
  final String email;
  final String providerName;
  final bool isPrimary;
  final bool isArchive;
  final bool isScanSync;
  final int? storageUsed;
  final int? storageLimit;

  const StorageAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.email,
    required this.providerName,
    this.isPrimary = false,
    this.isArchive = false,
    this.isScanSync = false,
    this.storageUsed,
    this.storageLimit,
  });

  StorageAccount copyWith({
    String? id,
    String? name,
    StorageAccountType? type,
    String? email,
    String? providerName,
    bool? isPrimary,
    bool? isArchive,
    bool? isScanSync,
    int? storageUsed,
    int? storageLimit,
  }) {
    return StorageAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      email: email ?? this.email,
      providerName: providerName ?? this.providerName,
      isPrimary: isPrimary ?? this.isPrimary,
      isArchive: isArchive ?? this.isArchive,
      isScanSync: isScanSync ?? this.isScanSync,
      storageUsed: storageUsed ?? this.storageUsed,
      storageLimit: storageLimit ?? this.storageLimit,
    );
  }
}
