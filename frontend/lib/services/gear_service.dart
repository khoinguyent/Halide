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
}
