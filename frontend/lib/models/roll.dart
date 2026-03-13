class Roll {
  final String id;
  final String userId;
  final String filmStockId;
  final String userCameraId;
  final int? shotAtIso;
  final int? expiredYear;
  final String status;
  final DateTime createdAt;

  Roll({
    required this.id,
    required this.userId,
    required this.filmStockId,
    required this.userCameraId,
    this.shotAtIso,
    this.expiredYear,
    required this.status,
    required this.createdAt,
  });

  factory Roll.fromJson(Map<String, dynamic> json) {
    return Roll(
      id: json['id'],
      userId: json['user_id'],
      filmStockId: json['film_stock_id'],
      userCameraId: json['user_camera_id'],
      shotAtIso: json['shot_at_iso'],
      expiredYear: json['expired_year'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
