import 'package:uuid/uuid.dart';

class Shot {
  final String id;
  final String? rollId;
  final int? frameNumber;
  final String? imageUrl;
  final double? aperture;
  final String? shutterSpeed;
  final String? notes;
  final double? locationLat;
  final double? locationLng;
  final DateTime? createdAt;

  Shot({
    required this.id,
    this.rollId,
    this.frameNumber,
    this.imageUrl,
    this.aperture,
    this.shutterSpeed,
    this.notes,
    this.locationLat,
    this.locationLng,
    this.createdAt,
  });

  factory Shot.fromJson(Map<String, dynamic> json) {
    return Shot(
      id: json['id']?.toString() ?? '',
      rollId: json['roll_id']?.toString(),
      frameNumber: json['frame_number'] as int?,
      imageUrl: json['image_url'] as String?,
      aperture: (json['aperture'] as num?)?.toDouble(),
      shutterSpeed: json['shutter_speed'] as String?,
      notes: json['notes'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roll_id': rollId,
      'frame_number': frameNumber,
      'image_url': imageUrl,
      'aperture': aperture,
      'shutter_speed': shutterSpeed,
      'notes': notes,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
