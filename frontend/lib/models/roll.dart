<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'roll_status.dart';

class Roll {
  final String id;
  final String brand;
  final String name;
  final Color color;
  final RollStatus status;
  final List<String> imageUrls;
  final String? nickname;
  final String? cameraName;
  final String? lensName;
  final int frameCount;
  final int maxFrames;
  final DateTime? createdAt;

  Roll({
    required this.id,
    required this.brand,
    required this.name,
    required this.color,
    this.status = RollStatus.shooting,
    this.imageUrls = const [],
    this.nickname,
    this.cameraName,
    this.lensName,
    this.frameCount = 0,
    this.maxFrames = 36,
    this.createdAt,
  });

  Roll copyWith({
    RollStatus? status,
    List<String>? imageUrls,
    String? nickname,
    String? cameraName,
    String? lensName,
    int? frameCount,
    int? maxFrames,
  }) {
    return Roll(
      id: id,
      brand: brand,
      name: name,
      color: color,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      nickname: nickname ?? this.nickname,
      cameraName: cameraName ?? this.cameraName,
      lensName: lensName ?? this.lensName,
      frameCount: frameCount ?? this.frameCount,
      maxFrames: maxFrames ?? this.maxFrames,
      createdAt: createdAt,
    );
  }

  factory Roll.fromJson(Map<String, dynamic> json) {
    return Roll(
      id: json['id'] ?? '',
      brand: json['brand'] ?? '',
      name: json['name'] ?? '',
      color: Color(int.parse(json['color']?.replaceFirst('#', '0xff') ?? '0xffcccccc')),
      status: statusFromString(json['status'] ?? 'shooting'),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      nickname: json['nickname'],
      cameraName: json['camera_name'],
      lensName: json['lens_name'],
      frameCount: json['frame_count'] ?? 0,
      maxFrames: json['max_frames'] ?? 36,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
=======
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
>>>>>>> feat/sprint_03/fe_dev_1
    );
  }
}
