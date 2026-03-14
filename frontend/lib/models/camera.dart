import 'lens.dart';

class Camera {
  final String id;
  final String nickname;
  final String brand;
  final String model;
  final String? serialNumber;
  final String? format;
  final List<Lens> lenses;
  final List<String> imageUrls;

  Camera({
    required this.id,
    required this.nickname,
    required this.brand,
    required this.model,
    this.serialNumber,
    this.format,
    this.lenses = const [],
    this.imageUrls = const [],
  });

  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  factory Camera.fromJson(Map<String, dynamic> json) {
    final camera = json['camera'] as Map<String, dynamic>?;
    final urls = json['image_urls'] ?? camera?['image_urls'];
    final urlList = urls is List ? urls.map((e) => e.toString()).toList() : <String>[];
    return Camera(
      id: json['id']?.toString() ?? '',
      nickname: json['gear_nickname'] ?? json['nickname'] ?? '',
      brand: json['brand'] ?? camera?['brand'] ?? '',
      model: json['model'] ?? camera?['model'] ?? '',
      serialNumber: json['serial_number'],
      format: json['format'] ?? camera?['format'],
      lenses: (json['lenses'] as List? ?? [])
          .map((l) => Lens.fromJson(l as Map<String, dynamic>))
          .toList(),
      imageUrls: urlList,
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
