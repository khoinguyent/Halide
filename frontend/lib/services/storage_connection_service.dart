import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';
import '../config/env_loader.dart';

/// Handles connecting cloud storage providers (e.g. Google Drive) via OAuth
/// and registering the connection with the backend.
class StorageConnectionService {
  final ApiService _api = ApiService();

  static String? get _googleDriveServerClientId {
    final id = halideEnvString(
      'GOOGLE_DRIVE_SERVER_CLIENT_ID',
      fromDefine:
          const String.fromEnvironment('GOOGLE_DRIVE_SERVER_CLIENT_ID', defaultValue: ''),
    );
    return id.isEmpty ? null : id;
  }

  /// Starts Google Sign-In with Drive scope and sends credentials to the backend.
  Future<void> connectGoogleDrive({
    bool isArchive = true,
    bool isScanSync = true,
  }) async {
    try {
      final clientId = _googleDriveServerClientId;
      debugPrint('[GDrive] Using serverClientId: $clientId');
      
      if (clientId == null || clientId.isEmpty) {
        throw StorageConnectionException(
          'Missing GOOGLE_DRIVE_SERVER_CLIENT_ID. Add it to frontend/.env '
          '(see .env.example) or pass --dart-define=GOOGLE_DRIVE_SERVER_CLIENT_ID=....',
        );
      }

      final googleSignIn = GoogleSignIn(
        clientId: (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)
            ? '413280765346-2pq8udmspnct62nvojgpuafku9pq8som.apps.googleusercontent.com'
            : null,
        scopes: const [
          'email',
          // Lab-scan import from shared folders.
          'https://www.googleapis.com/auth/drive.readonly',
          // Create/update Agxel Vault archive folders & uploads.
          'https://www.googleapis.com/auth/drive.file',
        ],
        serverClientId: clientId,
        forceCodeForRefreshToken: true,
      );

      // Sign out and disconnect to ensure we get a fresh account selection/consent.
      try {
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
      } catch (_) {}

      final account = await googleSignIn.signIn();
      if (account == null) {
        throw StorageConnectionException('Sign-in cancelled');
      }

      final auth = await account.authentication;
      final serverCode = account.serverAuthCode;
      debugPrint('[GDrive] account.serverAuthCode: $serverCode');
      
      String authData;
      if (serverCode != null && serverCode.isNotEmpty) {
        debugPrint('[GDrive] Proceeding with server_auth_code path');
        authData = jsonEncode({'server_auth_code': serverCode});
      } else {
        final token = auth.accessToken;
        debugPrint('[GDrive] No server_auth_code found. Falling back to access_token.');
        if (token == null || token.isEmpty) {
          throw StorageConnectionException('Could not get Google access token');
        }
        authData = jsonEncode({'access_token': token});
      }

      await _api.post('/api/v1/connect', data: {
        'provider': 'gdrive',
        'identifier': account.email,
        'auth_data': authData,
        'display_label': 'Google Drive (${account.email})',
        'is_primary': true,
        'is_archive': isArchive,
        'is_scan_sync': isScanSync,
      });
    } on PlatformException catch (e) {
      throw StorageConnectionException(
        e.message ?? 'Google Sign-In failed (${e.code})',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final detail = data is Map<String, dynamic> ? data['detail']?.toString() : data?.toString();
      throw StorageConnectionException(
        'Backend error${status != null ? ' ($status)' : ''}${detail != null ? ': $detail' : ''}',
      );
    } on StorageConnectionException {
      rethrow;
    } catch (e) {
      throw StorageConnectionException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Connects a NAS over SMB credentials and registers the connection with the backend.
  Future<void> connectNas({
    required String host,
    required String username,
    required String password,
  }) async {
    try {
      final cleanedHost = host.trim();
      final cleanedUsername = username.trim();
      if (cleanedHost.isEmpty) {
        throw StorageConnectionException('NAS host is required');
      }
      if (cleanedUsername.isEmpty) {
        throw StorageConnectionException('NAS username is required');
      }

      // Avoid DB unique constraint violations for is_primary by only setting it
      // when the user doesn't already have a primary connection.
      bool hasPrimary = false;
      final connectionsResp = await _api.get('/api/v1/connections');
      final raw = connectionsResp.data;
      if (raw is List) {
        for (final item in raw) {
          if (item is Map && item['is_primary'] == true) {
            hasPrimary = true;
            break;
          }
        }
      }

      final isPrimary = !hasPrimary;
      final authData = jsonEncode({
        // Backend currently doesn't parse this for NAS; it just encrypts & stores.
        'password': password,
      });

      await _api.post('/api/v1/connect', data: {
        'provider': 'nas',
        'identifier': '$cleanedUsername@$cleanedHost',
        'host': cleanedHost,
        'username': cleanedUsername,
        'auth_data': authData,
        'display_label': 'NAS ($cleanedHost)',
        'is_primary': isPrimary,
        'is_archive': true,
      });
    } catch (e) {
      if (e is StorageConnectionException) rethrow;
      throw StorageConnectionException(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

class StorageConnectionException implements Exception {
  final String message;
  StorageConnectionException(this.message);
  @override
  String toString() => message;
}
