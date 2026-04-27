import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../public/home_screen.dart';
import 'role_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color marron = Color(0xFF795548);
  bool isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);

    try {
      // 1. Ouvrir Google Sign In
      await GoogleSignIn.instance.initialize(
        serverClientId: '681462135328-olls77t7uuqtjablr8sfoki1jn5v689g.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? account = await GoogleSignIn.instance.authenticate();
      if (account == null) {
        setState(() => isLoading = false);
        return;
      }

      // 2. Récupérer le token Google
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        setState(() => isLoading = false);
        return;
      }

      // 3. Vérifier si l'utilisateur existe
      final response = await http.post(
        Uri.parse('http://192.168.0.144:8080/api/auth/google/check'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'idToken': idToken}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        // ✅ Utilisateur EXISTANT → connecter directement
        final token = data['data']['token'];
        final role = data['data']['role'];
        final name = data['data']['name'];
        final userId = data['data']['userId'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('role', role);
        await prefs.setString('name', name);
        await prefs.setString('userId', userId);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(token: token, role: role, userId: userId),
            ),
                (route) => false,
          );
        }
      } else {
        // ❌ Utilisateur NOUVEAU → demander le rôle
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
                decoration: BoxDecoration(
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

              // Bouton Google
              isLoading
                  ? const CircularProgressIndicator(color: marron)
                  : GestureDetector(
                onTap: _signInWithGoogle,
                child: Container(
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
                      Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 24,
                        height: 24,
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