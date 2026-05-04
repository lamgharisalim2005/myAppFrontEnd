import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

class PhotosSalonScreen extends StatefulWidget {
  final String token;
  final String salonId;

  const PhotosSalonScreen({
    super.key,
    required this.token,
    required this.salonId,
  });

  @override
  State<PhotosSalonScreen> createState() => _PhotosSalonScreenState();
}

class _PhotosSalonScreenState extends State<PhotosSalonScreen> {
  static const Color marron = Color(0xFF795548);
  static const Color rouge = Color(0xFFE53935);

  List<dynamic> photos = [];
  bool isLoading = true;
  bool isUploading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
  }

  Future<void> _fetchPhotos() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/salons/${widget.salonId}/photos',
        widget.token,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          photos = data['data'] as List? ?? [];
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

  Future<void> _ajouterPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => isUploading = true);

    try {
      final response = await ApiService.multipart(
        'http://127.0.0.1:8080/api/salons/${widget.salonId}/photos',
        widget.token,
        fields: {},
        filePath: picked.path,
        method: 'POST',
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['status'] == 'success') {
        _fetchPhotos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Photo ajoutée avec succès'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur ajout photo: $e');
    }

    setState(() => isUploading = false);
  }

  Future<void> _supprimerPhoto(String photoId) async {
    try {
      final response = await ApiService.delete(
        'http://127.0.0.1:8080/api/salons/${widget.salonId}/photos/$photoId',
        widget.token,
      );

      if (response.statusCode == 204) {
        _fetchPhotos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Photo supprimée'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur suppression photo: $e');
    }
  }

  void _confirmerSuppression(String photoId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette photo ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerPhoto(photoId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: rouge,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, supprimer'),
          ),
        ],
      ),
    );
  }

  void _voirPhoto(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Photos du Salon',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isUploading ? null : _ajouterPhoto,
        backgroundColor: marron,
        icon: isUploading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: Text(
          isUploading ? 'Envoi...' : 'Ajouter',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : RefreshIndicator(
        color: marron,
        onRefresh: _fetchPhotos,
        child: photos.isEmpty ? _buildEmpty() : _buildGrid(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: rouge, size: 60),
          const SizedBox(height: 16),
          Text(errorMessage!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchPhotos,
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucune photo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez des photos à votre salon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) => _buildPhotoCard(photos[index]),
    );
  }

  Widget _buildPhotoCard(dynamic photo) {
    return GestureDetector(
      onTap: () => _voirPhoto(photo['url']),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              photo['url'],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: marron.withOpacity(0.1),
                  child: const Center(
                    child: CircularProgressIndicator(color: marron),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: marron.withOpacity(0.1),
                  child: const Icon(Icons.broken_image, color: marron),
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _confirmerSuppression(photo['id']),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}