import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:recollection_application/core/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = '${AppConfig.baseUrl}/auth';

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({ 'telefono': phone, 'contrasenia': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['accessToken']);
      await prefs.setString('userRole', data['user']['rol']);

      return data;
    } else {
      throw Exception('Error de autenticación: ${response.body}');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<bool> validateToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
          headers: {
            'Autorization': 'Bearer $token',
            'Content-Type': 'application/json',
          }
      );

      return response.statusCode == 200;

    } catch (e) {
      return false;
    }
  }
}