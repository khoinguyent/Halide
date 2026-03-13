class Lens {
  final String id;
  final String nickname;
  final String brand;
  final String model;
  final String? serialNumber;
  final String? focalLength;
  final String? maxAperture;

  Lens({
    required this.id,
    required this.nickname,
    required this.brand,
    required this.model,
    this.serialNumber,
    this.focalLength,
    this.maxAperture,
  });

  factory Lens.fromJson(Map<String, dynamic> json) {
    return Lens(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '',
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      serialNumber: json['serial_number'],
      focalLength: json['focal_length'],
      maxAperture: json['max_aperture'],
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
    };
  }
}
