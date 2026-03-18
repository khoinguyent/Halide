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

  const StorageAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.email,
    required this.providerName,
    this.isPrimary = false,
  });

  StorageAccount copyWith({
    String? id,
    String? name,
    StorageAccountType? type,
    String? email,
    String? providerName,
    bool? isPrimary,
  }) {
    return StorageAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      email: email ?? this.email,
      providerName: providerName ?? this.providerName,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
