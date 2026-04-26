import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../public/home_screen.dart';

class RoleScreen extends StatefulWidget {
  final String idToken;
  const RoleScreen({super.key, required this.idToken});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  static const Color marron = Color(0xFF795548);
  bool isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.21:8080/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'idToken': widget.idToken,
          'role': role,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final token = data['data']['token'];
        final userRole = data['data']['role'];
        final name = data['data']['name'];
        final userId = data['data']['userId'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('role', userRole);
        await prefs.setString('name', name);
        await prefs.setString('userId', userId);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(token: token, role: userRole),
            ),
                (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur: $e');
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.content_cut, color: marron, size: 60),
              const SizedBox(height: 24),
              const Text(
                'Qui êtes-vous ?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: marron,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choisissez votre rôle pour continuer',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              isLoading
                  ? const CircularProgressIndicator(color: marron)
                  : Column(
                children: [
                  // Bouton CLIENT
                  GestureDetector(
                    onTap: () => _selectRole('CLIENT'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: marron,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.person, color: Colors.white, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'Je suis CLIENT',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Je cherche un coiffeur',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bouton COIFFEUR
                  GestureDetector(
                    onTap: () => _selectRole('COIFFEUR'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: marron, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.content_cut, color: marron, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'Je suis COIFFEUR',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: marron,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'J\'offre des services de coiffure',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}