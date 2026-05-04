import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/public/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/websocket_service.dart';
import 'services/api_service.dart'; // ← ajouter
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Stripe
  Stripe.publishableKey = 'pk_test_51TLQuKDnhpF1jgjywRaUqc1jdIzAtZFwGGpdoyC8BuMGN9KmuVjZxxWScp8KzDEHibVSBm1TkOStgYWPBLfWLmir00RxlLL94x';
  await Stripe.instance.applySettings();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');
  final role = prefs.getString('role');
  final userId = prefs.getString('userId');

  if (token != null && userId != null) {
    WebSocketService().connect(token, userId);
  }

  runApp(MyApp(token: token, role: role, userId: userId));
}

class MyApp extends StatelessWidget {
  final String? token;
  final String? role;
  final String? userId;

  const MyApp({super.key, this.token, this.role, this.userId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coiffeur App',
      debugShowCheckedModeBanner: false,
      navigatorKey: ApiService.navigatorKey, // ← ajouter
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: token == null
          ? const LoginScreen()
          : HomeScreen(token: token, role: role, userId: userId),
    );
  }
}