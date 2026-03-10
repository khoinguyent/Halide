import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class UploadService {
  final String _baseUrl = 'http://localhost:8000'; // Adjust for your environment

  Future<bool> uploadRollImage({
    required String rollId,
    required File imageFile,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/rolls/$rollId/images'),
      );

      // Add image file
      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      
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
