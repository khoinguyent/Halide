import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';

class UploadService {

  Future<bool> uploadRollImage({
    required String rollId,
    required File imageFile,
  }) async {
    try {
      const maxBytes = 15 * 1024 * 1024; // 15 MB
      final length = await imageFile.length();
      if (length > maxBytes) {
        // Too large; let caller surface a friendly message.
        print('Skipped ${imageFile.path}: file larger than 15MB (${length} bytes).');
        return false;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiUrl}/upload_roll_image/$rollId'),
      );

      // Add image file
      final stream = http.ByteStream(imageFile.openRead());
      
      final multipartFile = http.MultipartFile(
        'file',
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
