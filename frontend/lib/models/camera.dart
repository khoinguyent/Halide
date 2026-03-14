import 'lens.dart';
import 'gear_status.dart';

class Camera {
  final String id;
  final String nickname;
  final String brand;
  final String model;
  final String? serialNumber;
  final String? format;
  final GearStatus status;
  final List<String> imageUrls;
  final List<Lens> lenses;

  Camera({
    required this.id,
    required this.nickname,
    required this.brand,
    required this.model,
    this.serialNumber,
    this.format,
    this.status = GearStatus.active,
    this.imageUrls = const [],
    this.lenses = const [],
  });

  Camera copyWith({
    GearStatus? status,
    List<String>? imageUrls,
    List<Lens>? lenses,
  }) {
    return Camera(
      id: id,
      nickname: nickname,
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      format: format,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      lenses: lenses ?? this.lenses,
    );
  }

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      serialNumber: json['serial_number'],
      format: json['format'],
      status: gearStatusFromString(json['status'] ?? 'active'),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
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
      'serial_number': serialNumber,
      'format': format,
      'status': status.name,
      'image_urls': imageUrls,
    };
  }
}
