import 'lens.dart';

class Camera {
  final String id;
  final String nickname;
  final String brand;
  final String model;
  final String? serialNumber;
  final String? format;
  final List<Lens> lenses;

  Camera({
    required this.id,
    required this.nickname,
    required this.brand,
    required this.model,
    this.serialNumber,
    this.format,
    this.lenses = const [],
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      serialNumber: json['serial_number'],
      format: json['format'],
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
    };
  }

  String get displayName => '$brand $model';
}
