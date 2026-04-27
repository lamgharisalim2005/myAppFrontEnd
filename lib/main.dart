import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/public/home_screen.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  // Assure que Flutter est initialisé
  WidgetsFlutterBinding.ensureInitialized();

  // Vérifier si l'utilisateur est connecté
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');
  final role = prefs.getString('role');
  final userId = prefs.getString('userId'); // ← Ajoute ça

  runApp(MyApp(token: token, role: role));
}

class MyApp extends StatelessWidget {
  final String? token;
  final String? role;
  final String? userId; // ← Ajoute ça

  const MyApp({super.key, this.token, this.role, this.userId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coiffeur App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      // Premier écran toujours = Accueil (carte des salons)
      home: token == null
          ? const LoginScreen()
          : HomeScreen(token: token, role: role, userId: userId), // ← Ajoute userId
    );
  }
}