import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import 'coiffeur_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String userType;
  final String token;
  final String? currentUserId;
  final String? currentUserRole;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.token,
    this.currentUserId,
    this.currentUserRole,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  static const Color marron = Color(0xFF795548);

  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final endpoint = widget.userType == 'COIFFEUR'
          ? '/api/coiffeurs/${widget.userId}/public'
          : '/api/clients/${widget.userId}/public';

      final response = await ApiService.get(
        'http://127.0.0.1:8080$endpoint',
        widget.token,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          profile = data['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Erreur serveur';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Impossible de se connecter';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          profile?['name'] ?? 'Profil',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : _buildProfile(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(errorMessage!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: marron,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    final isCoiffeur = widget.userType == 'COIFFEUR';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Photo de profil
          CircleAvatar(
            radius: 60,
            backgroundColor: marron.withOpacity(0.1),
            backgroundImage: profile?['profilePicture'] != null
                ? NetworkImage(profile!['profilePicture'])
                : null,
            child: profile?['profilePicture'] == null
                ? Icon(
              isCoiffeur ? Icons.content_cut : Icons.person,
              color: marron,
              size: 60,
            )
                : null,
          ),
          const SizedBox(height: 16),

          // Nom
          Text(
            profile?['name'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // Badge rôle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: marron.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCoiffeur ? 'Coiffeur' : 'Client',
              style: const TextStyle(
                color: marron,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Infos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                // Email
                Row(
                  children: [
                    const Icon(Icons.email, color: marron),
                    const SizedBox(width: 12),
                    Text(
                      profile?['email'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Rôle
                Row(
                  children: [
                    const Icon(Icons.person, color: marron),
                    const SizedBox(width: 12),
                    Text(
                      isCoiffeur ? 'Coiffeur professionnel' : 'Client',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bouton Voir détails (coiffeur seulement)
          if (isCoiffeur) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CoiffeurDetailScreen(
                        coiffeurId: widget.userId,
                        coiffeurName: profile?['name'] ?? '',
                        token: widget.token,
                        role: widget.currentUserRole,
                        userId: widget.currentUserId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.content_cut),
                label: const Text('Voir les détails'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: marron,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}