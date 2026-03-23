import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';

class UploadService {

  Future<bool> uploadRollImage({
    required String rollId,
    required File imageFile,
  }) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final token = await firebaseUser?.getIdToken();
      if (token == null || token.isEmpty) {
        print('[UploadService] Missing Firebase ID token; cannot upload.');
        return false;
      }

      const maxBytes = 15 * 1024 * 1024; // 15 MB
      final length = await imageFile.length();
      if (length > maxBytes) {
        // Too large; let caller surface a friendly message.
        print('Skipped ${imageFile.path}: file larger than 15MB (${length} bytes).');
        return false;
      }

      final request = http.MultipartRequest(
        'POST',
        // Backend endpoint expects multipart form field name `files`.
        Uri.parse('${AppConfig.apiUrl}/rolls/$rollId/images'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      // Add image file
      final stream = http.ByteStream(imageFile.openRead());
      
      final multipartFile = http.MultipartFile(
        'files',
        stream,
        length,
        filename: imageFile.path.split('/').last,
        contentType: MediaType('image', 'jpeg'),
      );
      
      request.files.add(multipartFile);

      final response = await request.send();

      if (response.statusCode == 200) {
        print('Successfully uploaded ${imageFile.path}');
        return true;
      } else {
        print('Failed to upload ${imageFile.path}. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return false;
    }
  }
}
