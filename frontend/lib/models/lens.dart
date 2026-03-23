import 'gear_status.dart';

class Lens {
  final String id;
  final String nickname;
  final String brand;
  final String model;
  final String? serialNumber;
  final String? focalLength;
  final String? maxAperture;
  final GearStatus status;
  final List<String> imageUrls;

  Lens({
    required this.id,
    required this.nickname,
    required this.brand,
    required this.model,
    this.serialNumber,
    this.focalLength,
    this.maxAperture,
    this.status = GearStatus.active,
    this.imageUrls = const [],
  });

  Lens copyWith({
    GearStatus? status,
    List<String>? imageUrls,
  }) {
    return Lens(
      id: id,
      nickname: nickname,
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      focalLength: focalLength,
      maxAperture: maxAperture,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  factory Lens.fromJson(Map<String, dynamic> json) {
    final master = json['lens'] as Map<String, dynamic>?;
    return Lens(
      id: json['id']?.toString() ?? '',
      nickname: json['gear_nickname'] ?? json['nickname'] ?? '',
      brand: json['brand'] ?? master?['brand'] ?? '',
      model: json['model'] ?? master?['model'] ?? '',
      serialNumber: json['serial_number'],
      focalLength: json['focal_length'] ?? master?['focal_length'],
      maxAperture: json['max_aperture'] ?? master?['max_aperture'],
      status: gearStatusFromString(json['status'] ?? 'active'),
      imageUrls: List<String>.from(json['image_urls'] ?? master?['image_urls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'focal_length': focalLength,
      'max_aperture': maxAperture,
      'status': status.name,
      'image_urls': imageUrls,
    };
  }
}
