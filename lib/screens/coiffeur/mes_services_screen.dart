import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class MesServicesScreen extends StatefulWidget {
  final String token;

  const MesServicesScreen({super.key, required this.token});

  @override
  State<MesServicesScreen> createState() => _MesServicesScreenState();
}

class _MesServicesScreenState extends State<MesServicesScreen> {
  static const Color marron = Color(0xFF795548);
  static const Color rouge = Color(0xFFE53935);
  static const Color vert = Color(0xFF4CAF50);

  List<dynamic> services = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/coiffeurs/profile',
        widget.token,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        // Récupérer les services depuis le profil coiffeur
        final coiffeurId = data['data']['userId'];
        await _fetchServicesById(coiffeurId);
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Impossible de se connecter au serveur';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchServicesById(String coiffeurId) async {
    try {
      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/coiffeurs/$coiffeurId/detail',
        widget.token,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          services = data['data']['services'] as List? ?? [];
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

  Future<void> _creerService(String name, String description, double price, int duration) async {
    try {
      final response = await ApiService.post(
        'http://127.0.0.1:8080/api/services',
        widget.token,
        body: json.encode({
          'name': name,
          'description': description,
          'price': price,
          'duration': duration,
        }),
      );

      if (response.statusCode == 201) {
        _fetchServices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Service créé avec succès'),
              backgroundColor: vert,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur création service: $e');
    }
  }

  Future<void> _modifierService(String id, String name, String description, double price, int duration) async {
    try {
      final response = await ApiService.put(
        'http://127.0.0.1:8080/api/services/$id',
        widget.token,
        body: json.encode({
          'name': name,
          'description': description,
          'price': price,
          'duration': duration,
        }),
      );

      if (response.statusCode == 200) {
        _fetchServices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Service modifié avec succès'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur modification service: $e');
    }
  }

  Future<void> _supprimerService(String id) async {
    try {
      final response = await ApiService.delete(
        'http://127.0.0.1:8080/api/services/$id',
        widget.token,
      );

      if (response.statusCode == 204) {
        _fetchServices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Service supprimé'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur suppression service: $e');
    }
  }

  void _showServiceDialog({dynamic service}) {
    final nameController = TextEditingController(text: service?['name'] ?? '');
    final descController = TextEditingController(text: service?['description'] ?? '');
    final priceController = TextEditingController(text: service?['price']?.toString() ?? '');
    final durationController = TextEditingController(text: service?['duration']?.toString() ?? '');
    final isEditing = service != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isEditing ? 'Modifier le service' : 'Nouveau service',
          style: const TextStyle(color: marron, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du service',
                  labelStyle: const TextStyle(color: marron),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: marron),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (optionnel)',
                  labelStyle: const TextStyle(color: marron),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: marron),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Prix (MAD)',
                        labelStyle: const TextStyle(color: marron),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: marron),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Durée (min)',
                        labelStyle: const TextStyle(color: marron),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: marron),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              final price = double.tryParse(priceController.text.trim()) ?? 0;
              final duration = int.tryParse(durationController.text.trim()) ?? 0;

              if (name.isEmpty || price <= 0 || duration <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Remplissez tous les champs obligatoires'),
                    backgroundColor: rouge,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              if (isEditing) {
                _modifierService(service!['id'], name, desc, price, duration);
              } else {
                _creerService(name, desc, price, duration);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: marron,
              foregroundColor: Colors.white,
            ),
            child: Text(isEditing ? 'Modifier' : 'Créer'),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppression(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le service'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce service ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerService(id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mes Services',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showServiceDialog(),
        backgroundColor: marron,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : RefreshIndicator(
        color: marron,
        onRefresh: _fetchServices,
        child: services.isEmpty
            ? _buildEmpty()
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          itemBuilder: (context, index) =>
              _buildServiceCard(services[index]),
        ),
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
            onPressed: _fetchServices,
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
          Icon(Icons.content_cut, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucun service',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez vos services pour commencer',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(dynamic service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            child: const Icon(Icons.content_cut, color: marron),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (service['description'] != null &&
                    service['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    service['description'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${service['price']?.toStringAsFixed(0)} MAD',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: marron,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${service['duration']} min',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _showServiceDialog(service: service),
                icon: const Icon(Icons.edit, color: marron),
              ),
              IconButton(
                onPressed: () => _confirmerSuppression(service['id']),
                icon: const Icon(Icons.delete_outline, color: rouge),
              ),
            ],
          ),
        ],
      ),
    );
  }
}