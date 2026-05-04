import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';

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

  List<dynamic> horaires = [];
  bool isLoading = true;
  String? errorMessage;
  String? coiffeurId;

  final List<String> jours = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'
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
      // Récupérer l'ID du coiffeur
      final profileResponse = await ApiService.get(
        'http://127.0.0.1:8080/api/coiffeurs/profile',
        widget.token,
      );

      final profileData = json.decode(profileResponse.body);
      if (profileResponse.statusCode == 200 && profileData['status'] == 'success') {
        coiffeurId = profileData['data']['userId'];

        // Récupérer les horaires
        final response = await ApiService.get(
          'http://127.0.0.1:8080/api/workschedules/coiffeur/$coiffeurId',
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

  Future<void> _creerHoraire(String jour, TimeOfDay debut, TimeOfDay fin) async {
    try {
      final response = await ApiService.post(
        'http://127.0.0.1:8080/api/workschedules',
        widget.token,
        body: json.encode({
          'dayOfWeek': jour,
          'startTime': '${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')}:00',
          'endTime': '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}:00',
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
              content: Text('❌ ${data['errors']?[0]?['message'] ?? 'Erreur'}'),
              backgroundColor: rouge,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur création horaire: $e');
    }
  }

  Future<void> _modifierHoraire(String id, String jour, TimeOfDay debut, TimeOfDay fin) async {
    try {
      final response = await ApiService.put(
        'http://127.0.0.1:8080/api/workschedules/$id',
        widget.token,
        body: json.encode({
          'dayOfWeek': jour,
          'startTime': '${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')}:00',
          'endTime': '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}:00',
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
        'http://127.0.0.1:8080/api/workschedules/$id',
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

  void _showHoraireDialog({dynamic horaire}) {
    final isEditing = horaire != null;
    String selectedJour = horaire?['dayOfWeek'] ?? jours[0];

    // Parser les heures existantes
    TimeOfDay debut = TimeOfDay(
      hour: int.parse((horaire?['startTime'] ?? '09:00:00').split(':')[0]),
      minute: int.parse((horaire?['startTime'] ?? '09:00:00').split(':')[1]),
    );
    TimeOfDay fin = TimeOfDay(
      hour: int.parse((horaire?['endTime'] ?? '18:00:00').split(':')[0]),
      minute: int.parse((horaire?['endTime'] ?? '18:00:00').split(':')[1]),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(
            isEditing ? 'Modifier l\'horaire' : 'Nouvel horaire',
            style: const TextStyle(color: marron, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Jour
              DropdownButtonFormField<String>(
                value: selectedJour,
                decoration: InputDecoration(
                  labelText: 'Jour',
                  labelStyle: const TextStyle(color: marron),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: marron),
                  ),
                ),
                items: jours.map((jour) => DropdownMenuItem(
                  value: jour,
                  child: Text(joursLabels[jour]!),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setStateDialog(() => selectedJour = val);
                },
              ),
              const SizedBox(height: 16),

              // Heure début
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: debut,
                    builder: (context, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(primary: marron),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setStateDialog(() => debut = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: marron),
                      const SizedBox(width: 12),
                      Text(
                        'Début : ${debut.hour.toString().padLeft(2, '0')}:${debut.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Heure fin
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: fin,
                    builder: (context, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(primary: marron),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setStateDialog(() => fin = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: marron),
                      const SizedBox(width: 12),
                      Text(
                        'Fin : ${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (isEditing) {
                  _modifierHoraire(horaire!['id'], selectedJour, debut, fin);
                } else {
                  _creerHoraire(selectedJour, debut, fin);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: marron,
                foregroundColor: Colors.white,
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
        content: const Text('Êtes-vous sûr de vouloir supprimer cet horaire ?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mes Horaires',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showHoraireDialog(),
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
        onRefresh: _fetchHoraires,
        child: horaires.isEmpty ? _buildEmpty() : _buildList(),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucun horaire',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez vos jours et heures de travail',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Trier par jour de la semaine
    final sorted = [...horaires]..sort((a, b) =>
        jours.indexOf(a['dayOfWeek']).compareTo(jours.indexOf(b['dayOfWeek'])));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) => _buildHoraireCard(sorted[index]),
    );
  }

  Widget _buildHoraireCard(dynamic horaire) {
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
            child: const Icon(Icons.schedule, color: marron),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  joursLabels[horaire['dayOfWeek']] ?? horaire['dayOfWeek'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: marron,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatTime(horaire['startTime'])} - ${_formatTime(horaire['endTime'])}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _showHoraireDialog(horaire: horaire),
                icon: const Icon(Icons.edit, color: marron),
              ),
              IconButton(
                onPressed: () => _confirmerSuppression(horaire['id']),
                icon: const Icon(Icons.delete_outline, color: rouge),
              ),
            ],
          ),
        ],
      ),
    );
  }
}