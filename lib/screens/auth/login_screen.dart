import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../public/home_screen.dart';
import 'role_screen.dart';
import '../../services/websocket_service.dart';
import '../../config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color marron = Color(0xFF795548);
  bool isLoading = false;
  String? errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '681462135328-olls77t7uuqtjablr8sfoki1jn5v689g.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? account =
      await GoogleSignIn.instance.authenticate();
      if (account == null) {
        setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        setState(() => isLoading = false);
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/google/check'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'idToken': idToken}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final token = data['data']['token'];
        final role = data['data']['role'];
        final name = data['data']['name'];
        final userId = data['data']['userId'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('role', role);
        await prefs.setString('name', name);
        await prefs.setString('userId', userId);

        WebSocketService().connect(token, userId);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  HomeScreen(token: token, role: role, userId: userId),
            ),
                (route) => false,
          );
        }
      } else {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoleScreen(idToken: idToken),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur: $e');
      setState(() {
        errorMessage = 'Impossible de se connecter. Vérifiez votre connexion Internet.';
      });
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
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: marron,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.content_cut,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),

              // Titre
              const Text(
                'Bienvenue !',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: marron,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Trouvez le meilleur coiffeur près de chez vous',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),

              // Message erreur
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Bouton Google
              isLoading
                  ? const CircularProgressIndicator(color: marron)
                  : GestureDetector(
                onTap: _signInWithGoogle,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icône Google sans network image
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'G',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Se connecter avec Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}