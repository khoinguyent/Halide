import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class GearService {
  Future<List<dynamic>> fetchUserGear(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/user_cameras'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch gear: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> addUserCamera(String token, Map<String, dynamic> gearData) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/user_cameras'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(gearData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add camera: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> addUserLens(String token, Map<String, dynamic> gearData) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/user_lenses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(gearData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add lens: ${response.body}');
    }
  }

  /// Update user camera (e.g. image_urls, primary_image_index, gear_nickname).
  Future<Map<String, dynamic>> updateUserCamera(
    String token,
    String userCameraId, {
    List<String>? imageUrls,
    int? primaryImageIndex,
    String? gearNickname,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (imageUrls != null) body['image_urls'] = imageUrls;
    if (primaryImageIndex != null) body['primary_image_index'] = primaryImageIndex;
    if (gearNickname != null) body['gear_nickname'] = gearNickname;
    if (status != null) body['status'] = status;

    final response = await http.patch(
      Uri.parse('${AppConfig.apiUrl}/user_cameras/$userCameraId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update camera: ${response.body}');
    }
  }
  Future<List<dynamic>> fetchUserLenses(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/user_lenses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch lenses: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateUserLens(
    String token,
    String lensId, {
    String? parentCameraId,
    String? gearNickname,
  }) async {
    final body = <String, dynamic>{};
    if (parentCameraId != null) body['parent_camera_id'] = parentCameraId;
    if (gearNickname != null) body['gear_nickname'] = gearNickname;

    final response = await http.patch(
      Uri.parse('${AppConfig.apiUrl}/user_lenses/$lensId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update lens: ${response.body}');
    }
  }
}
