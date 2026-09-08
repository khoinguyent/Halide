import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    // Drive sync can require downloading many images and uploading them to R2/S3.
    // Increase timeouts so the request isn't aborted mid-way.
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 180),
  ));

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // In a real app, we'd send the Firebase ID token
          // For now, mapping Firebase UID to support backend's basic sub-based auth
          final idToken = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $idToken';
        }
        return handler.next(options);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  /// Binary body (e.g. Google Drive file bytes for free-tier on-device import).
  Future<Uint8List> getBytes(
    String path, {
    Duration receiveTimeout = const Duration(seconds: 180),
  }) async {
    final r = await _dio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: receiveTimeout,
        sendTimeout: receiveTimeout,
      ),
    );
    final list = r.data;
    if (list == null) return Uint8List(0);
    return Uint8List.fromList(list);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) async {
    return _dio.delete(path, data: data);
  }
}
