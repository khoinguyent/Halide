import 'package:flutter/material.dart';
import 'roll_status.dart';

class Roll {
  final String id;
  final String brand;
  final String name;
  final Color color;
  final RollStatus status;
  final List<String> imageUrls;

  Roll({
    required this.id,
    required this.brand,
    required this.name,
    required this.color,
    this.status = RollStatus.shooting,
    this.imageUrls = const [],
  });

  Roll copyWith({
    RollStatus? status,
    List<String>? imageUrls,
  }) {
    return Roll(
      id: id,
      brand: brand,
      name: name,
      color: color,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}
