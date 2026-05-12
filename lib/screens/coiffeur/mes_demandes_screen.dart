import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../../config/app_config.dart';

class MesDemandesScreen extends StatefulWidget {
  final String token;

  const MesDemandesScreen({
    super.key,
    required this.token,
  });

  @override
  State<MesDemandesScreen> createState() => _MesDemandesScreenState();
}

class _MesDemandesScreenState extends State<MesDemandesScreen> {
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
        '${AppConfig.baseUrl}/api/salon-requests/coiffeur',
        widget.token,
      );

      debugPrint('🔍 MesDemandes status: ${response.statusCode}');
      debugPrint('🔍 MesDemandes body: ${response.body}');

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          demandes = data['data'] as List? ?? [];
          demandes.sort((a, b) {
            final aDate = a['createdAt'] ?? '2000-01-01T00:00:00';
            final bDate = b['createdAt'] ?? '2000-01-01T00:00:00';
            return DateTime.parse(bDate).compareTo(DateTime.parse(aDate));
          });
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = data['errors']?[0]?['message'] ?? 'Erreur serveur';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur MesDemandes: $e');
      setState(() {
        errorMessage = 'Impossible de se connecter au serveur';
        isLoading = false;
      });
    }
  }

  Future<void> _annulerDemande(String demandeId) async {
    try {
      final response = await ApiService.delete(
        '${AppConfig.baseUrl}/api/salon-requests/$demandeId',
        widget.token,
      );

      if (response.statusCode == 200) {
        _fetchDemandes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Demande annulée'),
              backgroundColor: marron,
            ),
          );
        }
      } else {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${data['errors']?[0]?['message'] ?? 'Erreur'}'),
              backgroundColor: rouge,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur annulation: $e');
    }
  }

  void _confirmerAnnulation(String demandeId, String salonName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: rouge),
            SizedBox(width: 8),
            Text('Annuler la demande',
                style: TextStyle(color: rouge, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Voulez-vous annuler votre demande pour le salon $salonName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _annulerDemande(demandeId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: rouge,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return orange;
      case 'ACCEPTED': return vert;
      case 'REJECTED': return rouge;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING': return Icons.hourglass_empty;
      case 'ACCEPTED': return Icons.check_circle;
      case 'REJECTED': return Icons.cancel;
      default: return Icons.info;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING': return 'En attente';
      case 'ACCEPTED': return 'Acceptée';
      case 'REJECTED': return 'Refusée';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mes Demandes',
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
        onRefresh: _fetchDemandes,
        child: demandes.isEmpty ? _buildEmpty() : _buildList(),
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
          Icon(Icons.send_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucune demande envoyée',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cherchez un salon sur la carte et envoyez une demande',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
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
    final status = demande['status'] ?? 'PENDING';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusLabel = _getStatusLabel(status);
    final salonName = demande['salonName'] ?? 'Salon';
    final salonLocalisation = demande['salonLocalisation'] ?? '';
    final demandeId = demande['id'];

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
          // Header statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  _getTimeAgo(demande['createdAt']),
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: marron.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.store, color: marron, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salonName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (salonLocalisation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                salonLocalisation,
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message + bouton annuler selon statut
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: status == 'PENDING'
                ? Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: orange.withOpacity(0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En attente de réponse de l\'admin du salon',
                    style: TextStyle(color: orange.withOpacity(0.7), fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton annuler
                TextButton.icon(
                  onPressed: () => _confirmerAnnulation(demandeId, salonName),
                  icon: const Icon(Icons.cancel_outlined, color: rouge, size: 16),
                  label: const Text('Annuler', style: TextStyle(color: rouge, fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'ACCEPTED' ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: statusColor.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  status == 'ACCEPTED'
                      ? 'Vous faites partie de ce salon !'
                      : 'Votre demande a été refusée',
                  style: TextStyle(
                    color: statusColor.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: status == 'ACCEPTED' ? FontWeight.bold : FontWeight.normal,
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