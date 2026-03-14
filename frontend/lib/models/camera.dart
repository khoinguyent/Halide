class Camera {
  final String id;
  final String brand;
  final String model;
  final String cameraType;
  final String? nickname;

  Camera({
    required this.id,
    required this.brand,
    required this.model,
    required this.cameraType,
    this.nickname,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'],
      brand: json['brand'],
      model: json['model'],
      cameraType: json['camera_type'],
      nickname: json['nickname'],
    );
  }

  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      return '$nickname - $model';
    }
    return '$brand $model';
  }
}
