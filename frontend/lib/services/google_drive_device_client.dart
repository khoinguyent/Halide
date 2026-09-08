import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/env_loader.dart';

/// Lightweight Drive v3 client using the device's Google Sign-In access token.
/// Used by Free-tier Agxel Vault backup (local frames → personal Drive).
class GoogleDriveDeviceClient {
  GoogleDriveDeviceClient._(this._dio, this._accessToken);

  final Dio _dio;
  final String _accessToken;

  static const vaultFolderName = 'Agxel Vault';
  static const _folderMime = 'application/vnd.google-apps.folder';
  static const _driveBase = 'https://www.googleapis.com/drive/v3';
  static const _uploadBase = 'https://www.googleapis.com/upload/drive/v3';
  static const writeScope = 'https://www.googleapis.com/auth/drive.file';
  static const _scopes = [
    'email',
    'https://www.googleapis.com/auth/drive.readonly',
    writeScope,
  ];

  static GoogleSignIn _signIn() {
    final serverClientId = halideEnvString(
      'GOOGLE_DRIVE_SERVER_CLIENT_ID',
      fromDefine: const String.fromEnvironment(
        'GOOGLE_DRIVE_SERVER_CLIENT_ID',
        defaultValue: '',
      ),
    );
    return GoogleSignIn(
      clientId: (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)
          ? '413280765346-2pq8udmspnct62nvojgpuafku9pq8som.apps.googleusercontent.com'
          : null,
      scopes: _scopes,
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
  }

  /// Silent sign-in first; falls back to interactive if needed.
  ///
  /// Ensures [writeScope] (`drive.file`) is granted — older installs that only
  /// consented to `drive.readonly` cannot create Agxel Vault folders until the
  /// user reconnects Google Drive.
  static Future<GoogleDriveDeviceClient> connect({bool interactive = true}) async {
    final signIn = _signIn();
    GoogleSignInAccount? account = await signIn.signInSilently();
    if (account == null && interactive) {
      account = await signIn.signIn();
    }
    if (account == null) {
      throw GoogleDriveDeviceException('Google Sign-In cancelled');
    }

    // Older sessions may lack drive.file — silent sign-in does not re-consent.
    final hasWrite = await signIn.canAccessScopes(const [writeScope]);
    if (!hasWrite) {
      if (!interactive) {
        throw GoogleDriveDeviceException(
          'Google Drive needs updated permissions for Agxel Vault backup. '
          'Reconnect Google Drive and try again.',
          needsReauth: true,
        );
      }
      final granted = await signIn.requestScopes(const [writeScope]);
      if (!granted) {
        throw GoogleDriveDeviceException(
          'Google Drive needs updated permissions for Agxel Vault backup. '
          'Reconnect Google Drive and try again.',
          needsReauth: true,
        );
      }
    }

    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      throw GoogleDriveDeviceException(
        'Could not get Google access token. Reconnect Google Drive and try again.',
        needsReauth: true,
      );
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 180),
        sendTimeout: const Duration(seconds: 180),
        headers: {'Authorization': 'Bearer $token'},
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );
    return GoogleDriveDeviceClient._(dio, token);
  }

  Future<String> ensureVaultFolder() async {
    return findOrCreateFolder(name: vaultFolderName, parentId: 'root');
  }

  Future<String> findOrCreateFolder({
    required String name,
    required String parentId,
  }) async {
    final existing = await findChildByName(
      parentId: parentId,
      name: name,
      mimeType: _folderMime,
    );
    if (existing != null) return existing;
    try {
      final resp = await _dio.post(
        '$_driveBase/files',
        queryParameters: {
          'supportsAllDrives': 'true',
          'fields': 'id',
        },
        data: {
          'name': name,
          'mimeType': _folderMime,
          'parents': [parentId],
        },
      );
      final id = (resp.data is Map ? resp.data['id'] : null)?.toString();
      if (id == null || id.isEmpty) {
        throw GoogleDriveDeviceException('Failed to create folder "$name"');
      }
      return id;
    } on DioException catch (e) {
      throw GoogleDriveDeviceException.fromDio(e, action: 'create folder');
    }
  }

  Future<String?> findChildByName({
    required String parentId,
    required String name,
    String? mimeType,
  }) async {
    final safeName = name.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final safeParent = parentId.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    var q =
        "name = '$safeName' and '$safeParent' in parents and trashed = false";
    if (mimeType != null) {
      q += " and mimeType = '$mimeType'";
    }
    try {
      final resp = await _dio.get(
        '$_driveBase/files',
        queryParameters: {
          'q': q,
          'spaces': 'drive',
          'pageSize': 10,
          'fields': 'files(id, name, mimeType)',
          'supportsAllDrives': 'true',
          'includeItemsFromAllDrives': 'true',
        },
      );
      final files = (resp.data is Map ? resp.data['files'] : null);
      if (files is List && files.isNotEmpty) {
        final first = files.first;
        if (first is Map && first['id'] != null) return first['id'].toString();
      }
      return null;
    } on DioException catch (e) {
      throw GoogleDriveDeviceException.fromDio(e, action: 'list Drive');
    }
  }

  Future<void> uploadOrUpdateFile({
    required String parentId,
    required String name,
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
  }) async {
    final existing = await findChildByName(parentId: parentId, name: name);
    if (existing != null) {
      await _updateMedia(fileId: existing, bytes: bytes, mimeType: mimeType);
    } else {
      await _createMedia(
        parentId: parentId,
        name: name,
        bytes: bytes,
        mimeType: mimeType,
      );
    }
  }

  Future<void> _createMedia({
    required String parentId,
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final meta = jsonEncode({
      'name': name,
      'parents': [parentId],
    });
    final boundary = 'halide_${DateTime.now().millisecondsSinceEpoch}';
    final preamble = utf8.encode(
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$meta\r\n'
      '--$boundary\r\n'
      'Content-Type: $mimeType\r\n\r\n',
    );
    final epilogue = utf8.encode('\r\n--$boundary--');
    final body = Uint8List(preamble.length + bytes.length + epilogue.length);
    body.setRange(0, preamble.length, preamble);
    body.setRange(preamble.length, preamble.length + bytes.length, bytes);
    body.setRange(preamble.length + bytes.length, body.length, epilogue);

    try {
      await _dio.post(
        '$_uploadBase/files',
        queryParameters: {
          'uploadType': 'multipart',
          'supportsAllDrives': 'true',
          'fields': 'id',
        },
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'multipart/related; boundary=$boundary',
            'Content-Length': body.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw GoogleDriveDeviceException.fromDio(e, action: 'upload $name');
    }
  }

  Future<void> _updateMedia({
    required String fileId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      await _dio.patch(
        '$_uploadBase/files/$fileId',
        queryParameters: {
          'uploadType': 'media',
          'supportsAllDrives': 'true',
          'fields': 'id',
        },
        data: bytes,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': mimeType,
            'Content-Length': bytes.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw GoogleDriveDeviceException.fromDio(e, action: 'update file');
    }
  }

  static String sanitizeFolderName(String? title) {
    var name = (title ?? '').trim();
    if (name.isEmpty) name = 'Untitled Roll';
    name = name.replaceAll(RegExp(r'[/\\]'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.length > 200) name = name.substring(0, 200);
    return name.isEmpty ? 'Untitled Roll' : name;
  }
}

class GoogleDriveDeviceException implements Exception {
  final String message;
  /// True when the user must disconnect/reconnect Google Drive (stale scopes / 403).
  final bool needsReauth;

  GoogleDriveDeviceException(this.message, {this.needsReauth = false});

  factory GoogleDriveDeviceException.fromDio(
    DioException e, {
    required String action,
  }) {
    final parsed = _parseDio(e, action: action);
    return GoogleDriveDeviceException(parsed.$1, needsReauth: parsed.$2);
  }

  static (String, bool) _parseDio(DioException e, {required String action}) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? reason;
    String? reasonCode;
    String? errorStatus;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        reason = err['message']?.toString();
        errorStatus = err['status']?.toString();
        final errors = err['errors'];
        if (errors is List && errors.isNotEmpty && errors.first is Map) {
          reasonCode = errors.first['reason']?.toString();
          if (reasonCode == 'storageQuotaExceeded') {
            return (
              'Google Drive is out of storage. Free up space or upgrade Drive storage, then retry.',
              false,
            );
          }
        }
      }
    }

    final blob = '${reason ?? ''} ${errorStatus ?? ''} ${reasonCode ?? ''}'.toLowerCase();
    final scopeIssue = blob.contains('insufficient') ||
        blob.contains('access_token_scope_insufficient') ||
        blob.contains('permission') ||
        reasonCode == 'authError' ||
        reasonCode == 'invalid' ||
        errorStatus == 'PERMISSION_DENIED';

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return (
        'Network problem while trying to $action. Check your connection and retry.',
        false,
      );
    }

    if (status == 401 || status == 403 || scopeIssue) {
      return (
        reason ??
            'Google Drive permission denied while trying to $action. '
                'Reconnect Google Drive to grant Agxel Vault access, then try again.',
        true,
      );
    }
    return (reason ?? 'Failed to $action${status != null ? ' ($status)' : ''}.', false);
  }

  @override
  String toString() => message;
}
