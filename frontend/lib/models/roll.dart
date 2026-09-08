import 'package:flutter/material.dart';
import 'roll_status.dart';
import 'shot.dart';

class Roll {
  final String id;
  final String userId;
  final String filmStockId;
  final String userCameraId;
  final String brand;
  final String name;
  final Color color;
  /// Film stock format key from API, e.g. `format_135` or `format_120`.
  final String? filmFormat;
  final String? title;
  final String? description;
  final int? shotAtIso;
  final int? expiredYear;
  final RollStatus status;
  final List<String> imageUrls;
  final List<Shot> shots;
  final String? driveUrl;
  final String? nickname;
  final String? cameraName;
  final String? lensName;
  final int frameCount;
  final int maxFrames;
  final int shotOffset;
  final DateTime createdAt;

  Roll({
    required this.id,
    required this.userId,
    required this.filmStockId,
    required this.userCameraId,
    required this.brand,
    required this.name,
    required this.color,
    this.filmFormat,
    this.title,
    this.description,
    this.shotAtIso,
    this.expiredYear,
    this.status = RollStatus.shooting,
    this.imageUrls = const [],
    this.shots = const [],
    this.driveUrl,
    this.nickname,
    this.cameraName,
    this.lensName,
    this.frameCount = 0,
    this.maxFrames = 36,
    this.shotOffset = 0,
    required this.createdAt,
  });

  Roll copyWith({
    RollStatus? status,
    List<String>? imageUrls,
    String? driveUrl,
    String? nickname,
    String? cameraName,
    String? lensName,
    int? frameCount,
    int? maxFrames,
    int? shotOffset,
    String? title,
    String? description,
    String? filmFormat,
    int? shotAtIso,
    int? expiredYear,
    List<Shot>? shots,
  }) {
    return Roll(
      id: id,
      userId: userId,
      filmStockId: filmStockId,
      userCameraId: userCameraId,
      brand: brand,
      name: name,
      color: color,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      driveUrl: driveUrl ?? this.driveUrl,
      nickname: nickname ?? this.nickname,
      cameraName: cameraName ?? this.cameraName,
      lensName: lensName ?? this.lensName,
      frameCount: frameCount ?? this.frameCount,
      maxFrames: maxFrames ?? this.maxFrames,
      shotOffset: shotOffset ?? this.shotOffset,
      createdAt: createdAt,
      title: title ?? this.title,
      description: description ?? this.description,
      filmFormat: filmFormat ?? this.filmFormat,
      shotAtIso: shotAtIso ?? this.shotAtIso,
      expiredYear: expiredYear ?? this.expiredYear,
      shots: shots ?? this.shots,
    );
  }

  factory Roll.fromJson(Map<String, dynamic> json) {
    return Roll(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      filmStockId: json['film_stock_id']?.toString() ?? '',
      userCameraId: json['user_camera_id']?.toString() ?? '',
      brand: json['brand'] ?? '',
      name: json['name'] ?? '',
      color: Color(int.parse(json['color']?.replaceFirst('#', '0xff') ?? '0xffcccccc')),
      filmFormat: json['film_format']?.toString(),
      title: json['title'],
      description: json['description'],
      shotAtIso: json['shot_at_iso'],
      expiredYear: json['expired_year'],
      status: statusFromString(json['status'] ?? 'shooting'),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      shots: (json['shots'] as List<dynamic>?)?.map((s) => Shot.fromJson(Map<String, dynamic>.from(s))).toList() ?? [],
      driveUrl: (json['drive_url'] ?? json['driveUrl'])?.toString(),
      nickname: json['nickname'],
      cameraName: json['camera_name'],
      lensName: json['lens_name'],
      frameCount: json['frame_count'] ?? 0,
      maxFrames: json['max_frames'] ?? 36,
      shotOffset: json['shot_offset'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}
