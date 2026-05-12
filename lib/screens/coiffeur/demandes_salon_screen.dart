import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../public/coiffeur_detail_screen.dart';
import '../../config/app_config.dart';
class DemandesSalonScreen extends StatefulWidget {
  final String token;
  final String salonId;
  final String salonName;

  const DemandesSalonScreen({
    super.key,
    required this.token,
    required this.salonId,
    required this.salonName,
  });

  @override
  State<DemandesSalonScreen> createState() => _DemandesSalonScreenState();
}

class _DemandesSalonScreenState extends State<DemandesSalonScreen> {
  static const Color marron = Color(0xFF795548);
  static const Color vert = Color(0xFF4CAF50);
  static const Color rouge = Color(0xFFE53935);
  static const Color orange = Color(0xFFFF9800);

  List<dynamic> demandes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDemandes();
  }

  Future<void> _fetchDemandes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final response = await ApiService.get(
        '${AppConfig.baseUrl}/api/salon-requests/salon/${widget.salonId}',
        widget.token,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          demandes = (data['data'] as List)
              .where((d) => d['status'] == 'PENDING')
              .toList();
          demandes.sort((a, b) => DateTime.parse(b['createdAt'])
              .compareTo(DateTime.parse(a['createdAt'])));
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

  Future<void> _traiterDemande(String demandeId, String status) async {
    try {
      final response = await ApiService.put(
        '${AppConfig.baseUrl}/api/salon-requests/$demandeId?status=$status',
        widget.token,
      );

      if (response.statusCode == 200) {
        _fetchDemandes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'ACCEPTED'
                    ? '✅ Demande acceptée'
                    : '❌ Demande refusée',
              ),
              backgroundColor: status == 'ACCEPTED' ? vert : rouge,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur traitement demande: $e');
    }
  }

  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final now = DateTime.now();
    final date = DateTime.parse(createdAt);
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jour(s)';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _confirmerTraitement(String demandeId, String status, String nom) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              status == 'ACCEPTED' ? Icons.check_circle : Icons.cancel,
              color: status == 'ACCEPTED' ? vert : rouge,
            ),
            const SizedBox(width: 8),
            Text(
              status == 'ACCEPTED' ? 'Accepter' : 'Refuser',
              style: TextStyle(
                color: status == 'ACCEPTED' ? vert : rouge,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          status == 'ACCEPTED'
              ? 'Voulez-vous accepter $nom dans votre salon ?'
              : 'Voulez-vous refuser la demande de $nom ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _traiterDemande(demandeId, status);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'ACCEPTED' ? vert : rouge,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              status == 'ACCEPTED' ? 'Oui, accepter' : 'Oui, refuser',
            ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demandes reçues',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.salonName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : RefreshIndicator(
        color: marron,
        onRefresh: _fetchDemandes,
        child: demandes.isEmpty
            ? _buildEmpty()
            : _buildList(),
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
            onPressed: _fetchDemandes,
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
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune demande en attente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les demandes de coiffeurs apparaîtront ici',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: demandes.length,
      itemBuilder: (context, index) => _buildDemandeCard(demandes[index]),
    );
  }

  Widget _buildDemandeCard(dynamic demande) {
    final nom = demande['coiffeurName'] ?? 'Coiffeur';
    final photo = demande['coiffeurProfilePicture'];
    final coiffeurId = demande['coiffeurId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header orange
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_empty, color: orange, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'En attente de votre décision',
                  style: TextStyle(
                    color: orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  _getTimeAgo(demande['createdAt']),
                  style: const TextStyle(
                    color: orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Photo
                CircleAvatar(
                  radius: 32,
                  backgroundColor: marron.withOpacity(0.1),
                  backgroundImage:
                  photo != null ? NetworkImage(photo) : null,
                  child: photo == null
                      ? const Icon(
                    Icons.content_cut,
                    color: marron,
                    size: 32,
                  )
                      : null,
                ),
                const SizedBox(width: 16),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nom,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            Icons.content_cut,
                            size: 14,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Coiffeur professionnel',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 0),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Voir profil
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: coiffeurId != null
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CoiffeurDetailScreen(
                            coiffeurId: coiffeurId,
                            coiffeurName: nom,
                            token: widget.token,
                          ),
                        ),
                      );
                    }
                        : null,
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text('Voir profil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: marron,
                      side: BorderSide(color: marron.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Refuser
                IconButton(
                  onPressed: () => _confirmerTraitement(
                    demande['id'],
                    'REJECTED',
                    nom,
                  ),
                  icon: const Icon(Icons.close, color: rouge),
                  style: IconButton.styleFrom(
                    backgroundColor: rouge.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Accepter
                IconButton(
                  onPressed: () => _confirmerTraitement(
                    demande['id'],
                    'ACCEPTED',
                    nom,
                  ),
                  icon: const Icon(Icons.check, color: vert),
                  style: IconButton.styleFrom(
                    backgroundColor: vert.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}