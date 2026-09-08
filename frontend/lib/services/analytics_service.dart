import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../config/app_config.dart';
import '../models/shooting_matrix.dart';

class AnalyticsService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<ShootingMatrixResponse> fetchShootingMatrix() async {
    String timezone = 'UTC';
    try {
      timezone = await FlutterTimezone.getLocalTimezone();
    } catch (_) {}

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/analytics/shooting-matrix',
        queryParameters: {
          'timezone': timezone,
          'sync_timezone': true,
        },
        options: Options(headers: await _authHeaders()),
      );
      final data = response.data;
      if (data == null) {
        throw Exception('Empty analytics response from server');
      }
      return ShootingMatrixResponse.fromJson(data);
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] != null) {
        throw Exception(detail['detail'].toString());
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Analytics request timed out. Please try again.');
      }
      throw Exception(e.message ?? 'Could not load shooting analytics');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }
}
