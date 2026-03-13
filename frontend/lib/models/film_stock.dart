import 'package:flutter/material.dart';

class FilmStock {
  final String id;
  final String brand;
  final String name;
  final int iso;
  final String format;
  final String colorType;

  FilmStock({
    required this.id,
    required this.brand,
    required this.name,
    required this.iso,
    required this.format,
    required this.colorType,
  });

  factory FilmStock.fromJson(Map<String, dynamic> json) {
    return FilmStock(
      id: json['id'],
      brand: json['brand'],
      name: json['name'],
      iso: json['iso'],
      format: json['format'],
      colorType: json['color_type'],
    );
  }

  Color get color {
    switch (brand.toLowerCase()) {
      case 'kodak':
        return Colors.amber;
      case 'fujifilm':
        return Colors.green;
      case 'ilford':
        return Colors.grey;
      case 'cinestill':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }
}
