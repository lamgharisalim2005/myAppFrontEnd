import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../../config/app_config.dart';
class MesHorairesScreen extends StatefulWidget {
  final String token;

  const MesHorairesScreen({super.key, required this.token});

  @override
  State<MesHorairesScreen> createState() => _MesHorairesScreenState();
}

class _MesHorairesScreenState extends State<MesHorairesScreen> {
  static const Color marron = Color(0xFF795548);
  static const Color rouge = Color(0xFFE53935);
  static const Color vert = Color(0xFF4CAF50);
  static const Color gris = Color(0xFFEEEEEE);

  List<dynamic> horaires = [];
  bool isLoading = true;
  String? errorMessage;
  String? coiffeurId;

  final List<String> jours = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY',
    'FRIDAY', 'SATURDAY', 'SUNDAY'
  ];

  final Map<String, String> joursLabels = {
    'MONDAY': 'Lundi',
    'TUESDAY': 'Mardi',
    'WEDNESDAY': 'Mercredi',
    'THURSDAY': 'Jeudi',
    'FRIDAY': 'Vendredi',
    'SATURDAY': 'Samedi',
    'SUNDAY': 'Dimanche',
  };

  final Map<String, String> joursShort = {
    'MONDAY': 'Lun',
    'TUESDAY': 'Mar',
    'WEDNESDAY': 'Mer',
    'THURSDAY': 'Jeu',
    'FRIDAY': 'Ven',
    'SATURDAY': 'Sam',
    'SUNDAY': 'Dim',
  };

  @override
  void initState() {
    super.initState();
    _fetchHoraires();
  }

  Future<void> _fetchHoraires() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final profileResponse = await ApiService.get(
        '${AppConfig.baseUrl}/api/coiffeurs/profile',
        widget.token,
      );

      final profileData = json.decode(profileResponse.body);
      if (profileResponse.statusCode == 200 &&
          profileData['status'] == 'success') {
        coiffeurId = profileData['data']['userId'];

        final response = await ApiService.get(
          '${AppConfig.baseUrl}/api/workschedules/coiffeur/$coiffeurId',
          widget.token,
        );

        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['status'] == 'success') {
          setState(() {
            horaires = data['data'] as List? ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Erreur serveur';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Impossible de se connecter au serveur';
        isLoading = false;
      });
    }
  }

  // Récupère l'horaire d'un jour donné (null si pas travaillé)
  dynamic _getHoraireForJour(String jour) {
    try {
      return horaires.firstWhere((h) => h['dayOfWeek'] == jour);
    } catch (e) {
      return null;
    }
  }

  Future<void> _creerHoraire(
      String jour, TimeOfDay debut, TimeOfDay fin) async {
    try {
      final response = await ApiService.post(
        '${AppConfig.baseUrl}/api/workschedules',
        widget.token,
        body: json.encode({
          'dayOfWeek': jour,
          'startTime':
          '${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')}:00',
          'endTime':
          '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}:00',
        }),
      );

      if (response.statusCode == 201) {
        _fetchHoraires();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Horaire ajouté avec succès'),
              backgroundColor: vert,
            ),
          );
        }
      } else {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '❌ ${data['errors']?[0]?['message'] ?? 'Erreur'}'),
              backgroundColor: rouge,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur création horaire: $e');
    }
  }

  Future<void> _modifierHoraire(
      String id, String jour, TimeOfDay debut, TimeOfDay fin) async {
    try {
      final response = await ApiService.put(
        '${AppConfig.baseUrl}/api/workschedules/$id',
        widget.token,
        body: json.encode({
          'dayOfWeek': jour,
          'startTime':
          '${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')}:00',
          'endTime':
          '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}:00',
        }),
      );

      if (response.statusCode == 200) {
        _fetchHoraires();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Horaire modifié avec succès'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur modification horaire: $e');
    }
  }

  Future<void> _supprimerHoraire(String id) async {
    try {
      final response = await ApiService.delete(
        '${AppConfig.baseUrl}/api/workschedules/$id',
        widget.token,
      );

      if (response.statusCode == 204) {
        _fetchHoraires();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Horaire supprimé'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur suppression horaire: $e');
    }
  }

  void _showHoraireDialog(String jour, {dynamic horaire}) {
    final isEditing = horaire != null;

    TimeOfDay debut = TimeOfDay(
      hour: int.parse(
          (horaire?['startTime'] ?? '09:00:00').split(':')[0]),
      minute: int.parse(
          (horaire?['startTime'] ?? '09:00:00').split(':')[1]),
    );
    TimeOfDay fin = TimeOfDay(
      hour: int.parse(
          (horaire?['endTime'] ?? '18:00:00').split(':')[0]),
      minute: int.parse(
          (horaire?['endTime'] ?? '18:00:00').split(':')[1]),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: marron.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.schedule, color: marron),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Modifier' : 'Ajouter',
                    style: const TextStyle(
                      color: marron,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    joursLabels[jour]!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Heure début
              const Text(
                'Heure de début',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: debut,
                    builder: (context, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme:
                        const ColorScheme.light(primary: marron),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setStateDialog(() => debut = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: marron.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: marron.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, color: marron),
                      const SizedBox(width: 8),
                      Text(
                        '${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: marron,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Flèche
              const Icon(Icons.arrow_downward, color: Colors.grey),

              const SizedBox(height: 16),

              // Heure fin
              const Text(
                'Heure de fin',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: fin,
                    builder: (context, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme:
                        const ColorScheme.light(primary: marron),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setStateDialog(() => fin = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: marron.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: marron.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, color: marron),
                      const SizedBox(width: 8),
                      Text(
                        '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: marron,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (isEditing)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmerSuppression(horaire!['id']);
                },
                icon: const Icon(Icons.delete_outline, color: rouge),
                label: const Text(
                  'Supprimer',
                  style: TextStyle(color: rouge),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                // Vérifier que fin > début
                final debutMinutes = debut.hour * 60 + debut.minute;
                final finMinutes = fin.hour * 60 + fin.minute;

                if (finMinutes <= debutMinutes) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          '❌ L\'heure de fin doit être après l\'heure de début'),
                      backgroundColor: rouge,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                if (isEditing) {
                  _modifierHoraire(horaire!['id'], jour, debut, fin);
                } else {
                  _creerHoraire(jour, debut, fin);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: marron,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isEditing ? 'Modifier' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmerSuppression(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'horaire'),
        content:
        const Text('Êtes-vous sûr de vouloir supprimer cet horaire ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerHoraire(id);
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

  String _formatTime(String time) {
    final parts = time.split(':');
    return '${parts[0]}:${parts[1]}';
  }

  // Calcule la durée en heures
  String _calculerDuree(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes =
        int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final diff = endMinutes - startMinutes;
    final hours = diff ~/ 60;
    final minutes = diff % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mon Planning',
          style: TextStyle(
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
          : RefreshIndicator(
        color: marron,
        onRefresh: _fetchHoraires,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: marron,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Appuyez sur un jour pour définir vos heures de travail',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Résumé semaine
              const Text(
                'Ma Semaine',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: marron,
                ),
              ),
              const SizedBox(height: 8),

              // Jours en grille horizontale
              Row(
                children: jours.map((jour) {
                  final horaire = _getHoraireForJour(jour);
                  final travaille = horaire != null;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          _showHoraireDialog(jour, horaire: horaire),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 3),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color: travaille ? marron : gris,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              joursShort[jour]!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: travaille
                                    ? Colors.white
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Icon(
                              travaille
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: travaille
                                  ? Colors.white
                                  : Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Stats
              Row(
                children: [
                  _buildStat(
                    icon: Icons.work,
                    label: 'Jours travaillés',
                    value: '${horaires.length}/7',
                  ),
                  const SizedBox(width: 12),
                  _buildStat(
                    icon: Icons.weekend,
                    label: 'Jours de repos',
                    value: '${7 - horaires.length}',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Liste détaillée
              const Text(
                'Détail des horaires',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: marron,
                ),
              ),
              const SizedBox(height: 12),

              // Tous les jours
              ...jours.map((jour) {
                final horaire = _getHoraireForJour(jour);
                return _buildJourCard(jour, horaire);
              }),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: marron.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: marron, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: marron,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourCard(String jour, dynamic horaire) {
    final travaille = horaire != null;

    return GestureDetector(
      onTap: () => _showHoraireDialog(jour, horaire: horaire),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: travaille ? marron.withOpacity(0.3) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            // Indicateur jour
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: travaille
                    ? marron.withOpacity(0.1)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  joursShort[jour]!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: travaille ? marron : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Infos
            Expanded(
              child: travaille
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    joursLabels[jour]!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: marron,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatTime(horaire['startTime'])} → ${_formatTime(horaire['endTime'])}',
                        style: const TextStyle(
                          color: marron,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: marron.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _calculerDuree(
                            horaire['startTime'],
                            horaire['endTime'],
                          ),
                          style: const TextStyle(
                            color: marron,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    joursLabels[jour]!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const Text(
                    'Jour de repos — Appuyez pour ajouter',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Icône action
            Icon(
              travaille ? Icons.edit : Icons.add,
              color: travaille ? marron : Colors.grey,
            ),
          ],
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
            onPressed: _fetchHoraires,
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
}