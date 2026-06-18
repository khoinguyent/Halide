import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/light_table/logic/light_table_color.dart';

void main() {
  group('getColorFromTemperature', () {
    test('returns warm amber below 5500K', () {
      expect(getColorFromTemperature(5000), const Color(0xFFFFF7EF));
    });

    test('returns D65 white at 6000K', () {
      expect(getColorFromTemperature(6000), const Color(0xFFFFFFFF));
    });

    test('returns cool blue above 6500K', () {
      expect(getColorFromTemperature(7000), const Color(0xFFF2F8FF));
    });
  });
}
