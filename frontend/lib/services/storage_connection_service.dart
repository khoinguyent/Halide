import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

/// Handles connecting cloud storage providers (e.g. Google Drive) via OAuth
/// and registering the connection with the backend.
class StorageConnectionService {
  final ApiService _api = ApiService();

  static String? get _googleDriveServerClientId {
    const id = String.fromEnvironment('GOOGLE_DRIVE_SERVER_CLIENT_ID', defaultValue: '');
    return id.isEmpty ? null : id;
  }

  /// Starts Google Sign-In with Drive scope and sends credentials to the backend.
  Future<void> connectGoogleDrive() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: const [
          'email',
          'https://www.googleapis.com/auth/drive.file',
        ],
        serverClientId: _googleDriveServerClientId,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        throw StorageConnectionException('Sign-in cancelled');
      }

      String authData;
      final code = account.serverAuthCode;
      if (code != null && code.isNotEmpty) {
        authData = jsonEncode({'server_auth_code': code});
      } else {
        final auth = await account.authentication;
        final token = auth.accessToken;
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
        'is_archive': true,
      });
    } on PlatformException catch (e) {
      throw StorageConnectionException(
        e.message ?? 'Google Sign-In failed (${e.code})',
      );
    } on StorageConnectionException {
      rethrow;
    } catch (e) {
      throw StorageConnectionException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class StorageConnectionException implements Exception {
  final String message;
  StorageConnectionException(this.message);
  @override
  String toString() => message;
}
