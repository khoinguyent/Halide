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
}
