import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth/login_screen.dart';
import '../screens/public/home_screen.dart';
import 'websocket_service.dart';

class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<http.Response> get(String url, String token) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await _deconnexion();
    }
    if (response.statusCode == 404) {
      await _allerVersHome();
    }
    return response;
  }

  static Future<http.Response> post(String url, String token, {Object? body}) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await _deconnexion();
    }
    if (response.statusCode == 404) {
      await _allerVersHome();
    }
    return response;
  }

  static Future<http.Response> multipart(
      String url,
      String token, {
        required Map<String, String> fields,
        String? filePath,
        String fileField = 'file',
        String method = 'PUT',
      }) async {
    final request = http.MultipartRequest(
      method,
      Uri.parse(url),
    );
    request.headers['Authorization'] = 'Bearer $token';
    fields.forEach((key, value) => request.fields[key] = value);

    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }

    final streamedResponse = await request.send()
        .timeout(const Duration(seconds: 120));
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) {
      await _deconnexion();
    }
    if (streamedResponse.statusCode == 404) {
      await _allerVersHome();
    }
    return http.Response(responseBody, streamedResponse.statusCode);
  }

  static Future<http.Response> put(String url, String token, {Object? body}) async {
    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await _deconnexion();
    }
    if (response.statusCode == 404) {
      await _allerVersHome();
    }
    return response;
  }

  static Future<http.Response> delete(String url, String token) async {
    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 || response.statusCode == 403) {
      await _deconnexion();
    }
    if (response.statusCode == 404) {
      await _allerVersHome();
    }
    return response;
  }

  static Future<void> _deconnexion() async {
    WebSocketService().disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  static Future<void> _allerVersHome() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final role = prefs.getString('role') ?? '';
    final userId = prefs.getString('userId') ?? '';

    debugPrint('🏠 allerVersHome: token=$token, role=$role, userId=$userId');

    if (token.isEmpty) {
      debugPrint('🏠 token vide → déconnexion');
      await _deconnexion();
      return;
    }

    debugPrint('🏠 token ok → HomeScreen');
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          token: token,
          role: role,
          userId: userId,
        ),
      ),
          (route) => false,
    );
  }
}