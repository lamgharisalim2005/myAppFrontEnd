import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../auth/login_screen.dart';
import '../../services/websocket_service.dart';
import '../coiffeur/mes_photos_screen.dart';
import '../coiffeur/mes_services_screen.dart';
import '../coiffeur/mon_salon_screen.dart';
import '../coiffeur/mes_horaires_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String token;
  final String role;

  const ProfileScreen({
    super.key,
    required this.token,
    required this.role,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color marron = Color(0xFF795548);

  Map<String, dynamic>? profile;
  bool isLoading = true;
  bool isUpdating = false;
  String? errorMessage;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final endpoint = widget.role == 'CLIENT'
          ? '/api/clients/profile'
          : '/api/coiffeurs/profile';

      final response = await ApiService.get(
        'http://127.0.0.1:8080$endpoint',
        widget.token,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          profile = data['data'];
          _nameController.text = profile!['name'] ?? '';
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
        errorMessage = 'Impossible de se connecter au serveur';
        isLoading = false;
      });
    }
  }

  Future<void> _updateProfile({File? imageFile}) async {
    setState(() => isUpdating = true);
    try {
      final endpoint = widget.role == 'CLIENT'
          ? '/api/clients/profile'
          : '/api/coiffeurs/profile';

      final response = await ApiService.multipart(
        'http://127.0.0.1:8080$endpoint',
        widget.token,
        fields: {'name': _nameController.text.trim()},
        filePath: imageFile?.path,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          profile = data['data'];
          isUpdating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profil mis à jour'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isUpdating = false);
      debugPrint('Erreur update profile: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      await _updateProfile(imageFile: File(picked.path));
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              WebSocketService().disconnect();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mon Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : RefreshIndicator(
        color: marron,
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildPhotoSection(),
              const SizedBox(height: 24),
              _buildInfoSection(),
              const SizedBox(height: 24),
              if (widget.role == 'COIFFEUR') ...[
                _buildCoiffeurSection(),
                const SizedBox(height: 24),
              ],
              _buildLogoutButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
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

  Widget _buildPhotoSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: marron.withOpacity(0.1),
            backgroundImage: profile?['profilePicture'] != null
                ? NetworkImage(profile!['profilePicture'])
                : null,
            child: profile?['profilePicture'] == null
                ? Icon(
              widget.role == 'CLIENT' ? Icons.person : Icons.content_cut,
              color: marron,
              size: 60,
            )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: isUpdating ? null : _pickImage,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: marron,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: isUpdating
                    ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations personnelles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: marron,
            ),
          ),
          const SizedBox(height: 16),

          // Nom
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom',
              labelStyle: const TextStyle(color: marron),
              prefixIcon: const Icon(Icons.person, color: marron),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: marron),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Email (non modifiable)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.email, color: Colors.grey),
                const SizedBox(width: 12),
                Text(
                  profile?['email'] ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bouton sauvegarder
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isUpdating ? null : () => _updateProfile(),
              icon: isUpdating
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.save),
              label: const Text('Sauvegarder'),
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
      ),
    );
  }

  Widget _buildCoiffeurSection() {
    return Column(
      children: [
        // Photos portfolio
        _buildSectionButton(
          icon: Icons.photo_library,
          title: 'Mes Photos',
          subtitle: 'Gérer votre portfolio',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MesPhotosScreen(token: widget.token),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Services
        _buildSectionButton(
          icon: Icons.content_cut,
          title: 'Mes Services',
          subtitle: 'Gérer vos services et tarifs',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MesServicesScreen(token: widget.token),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
// Horaires
        _buildSectionButton(
          icon: Icons.schedule,
          title: 'Mes Horaires',
          subtitle: 'Gérer vos jours et heures de travail',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MesHorairesScreen(token: widget.token),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Salon
        _buildSectionButton(
          icon: Icons.store,
          title: 'Mon Salon',
          subtitle: 'Gérer votre salon',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MonSalonScreen(token: widget.token),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: marron.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: marron),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text(
          'Se déconnecter',
          style: TextStyle(color: Colors.red),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}