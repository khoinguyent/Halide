import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class RollService {
  Future<List<dynamic>> fetchRolls(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/rolls'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch rolls: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchRoll(String token, String rollId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/rolls/$rollId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      throw Exception('Roll not found');
    } else {
      throw Exception('Failed to fetch roll: ${response.body}');
    }
  }

  Future<void> updateRollStatus(String token, String rollId, String status) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiUrl}/rolls/$rollId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update roll status: ${response.body}');
    }
  }

  Future<void> updateRollMeta(
    String token,
    String rollId, {
    String? title,
    String? description,
    int? shotOffset,
  }) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiUrl}/rolls/$rollId/meta'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (title != null) 'title': title.isEmpty ? null : title,
        if (description != null) 'description': description.isEmpty ? null : description,
        if (shotOffset != null) 'shot_offset': shotOffset,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update roll meta: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createRoll(String token, Map<String, dynamic> rollData) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/rolls'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(rollData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create roll: ${response.body}');
    }
  }

  Future<void> addLocalImagesToRoll(String token, String rollId, List<String> localPaths) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/rolls/$rollId/local-images'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'local_paths': localPaths}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add local images: ${response.body}');
    }
  }

  Future<void> logShot(
    String token,
    String rollId, {
    required double aperture,
    required String shutterSpeed,
    required double lat,
    required double lng,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/rolls/$rollId/shots'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'aperture': aperture,
        'shutter_speed': shutterSpeed,
        'lat': lat,
        'lng': lng,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to log shot: ${response.body}');
    }
  }
}
