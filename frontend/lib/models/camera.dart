class Camera {
  final String id;
  final String brand;
  final String model;
  final String cameraType;

  Camera({
    required this.id,
    required this.brand,
    required this.model,
    required this.cameraType,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'],
      brand: json['brand'],
      model: json['model'],
      cameraType: json['camera_type'],
    );
  }

  String get displayName => '$brand $model';
}
