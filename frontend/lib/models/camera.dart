import 'lens.dart';
import 'gear_status.dart';

class Camera {
  final String id;
  final String nickname;
  final String brand;
  final String model;
  final String cameraType;
  final String? serialNumber;
  final String? format;
  final GearStatus status;
  final List<String> imageUrls;
  /// Index of the image to use as card thumbnail (0-based). Clamped to valid range.
  final int primaryImageIndex;
  final List<Lens> lenses;

  Camera({
    required this.id,
    required this.nickname,
    required this.brand,
    required this.model,
    this.cameraType = 'Unknown',
    this.serialNumber,
    this.format,
    this.status = GearStatus.active,
    this.imageUrls = const [],
    this.primaryImageIndex = 0,
    this.lenses = const [],
  });

  Camera copyWith({
    String? nickname,
    String? brand,
    String? model,
    String? cameraType,
    String? serialNumber,
    String? format,
    GearStatus? status,
    List<String>? imageUrls,
    int? primaryImageIndex,
    List<Lens>? lenses,
  }) {
    return Camera(
      id: id,
      nickname: nickname ?? this.nickname,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      cameraType: cameraType ?? this.cameraType,
      serialNumber: serialNumber ?? this.serialNumber,
      format: format ?? this.format,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      primaryImageIndex: primaryImageIndex ?? this.primaryImageIndex,
      lenses: lenses ?? this.lenses,
    );
  }

  /// Primary image URL for card thumbnail. Uses [primaryImageIndex] when in range, else first image.
  String? get imageUrl {
    if (imageUrls.isEmpty) return null;
    final idx = primaryImageIndex.clamp(0, imageUrls.length - 1);
    return imageUrls[idx];
  }

  factory Camera.fromJson(Map<String, dynamic> json) {
    final camera = json['camera'] as Map<String, dynamic>?;
    final urls = json['image_urls'];
    final urlList = urls is List ? urls.map((e) => e.toString()).toList() : <String>[];
    final primaryIdx = json['primary_image_index'] is int
        ? json['primary_image_index'] as int
        : 0;
    
    return Camera(
      id: json['id']?.toString() ?? '',
      nickname: json['gear_nickname'] ?? json['nickname'] ?? '',
      brand: json['brand'] ?? camera?['brand'] ?? '',
      model: json['model'] ?? camera?['model'] ?? '',
      cameraType: json['camera_type'] ?? 'Unknown',
      serialNumber: json['serial_number'],
      format: json['format'] ?? camera?['format'],
      status: gearStatusFromString(json['status'] ?? 'active'),
      imageUrls: urlList,
      primaryImageIndex: primaryIdx >= 0 ? primaryIdx : 0,
      lenses: (json['lenses'] as List? ?? [])
          .map((l) => Lens.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'brand': brand,
      'model': model,
      'camera_type': cameraType,
      'serial_number': serialNumber,
      'format': format,
      'status': status.name,
      'image_urls': imageUrls,
      'primary_image_index': primaryImageIndex,
    };
  }

  String get displayName {
    if (nickname.isNotEmpty) {
      return '$nickname - $brand $model';
    }
    return '$brand $model';
  }
}
