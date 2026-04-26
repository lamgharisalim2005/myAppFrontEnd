import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/service.dart';
import '../../models/work_schedule.dart';

class ReservationScreen extends StatefulWidget {
  final String coiffeurId;
  final String coiffeurName;
  final List<Service> selectedServices;
  final String token;

  const ReservationScreen({
    super.key,
    required this.coiffeurId,
    required this.coiffeurName,
    required this.selectedServices,
    required this.token,
  });

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  static const Color marron = Color(0xFF795548);
  static const Color vert = Color(0xFF4CAF50);
  static const Color rouge = Color(0xFFE53935);
  static const Color gris = Color(0xFFEEEEEE);

  List<WorkSchedule> workSchedules = [];
  List<Map<String, DateTime>> occupiedSlots = [];
  DateTime? selectedDateTime;

  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  // Jours de la semaine
  static const Map<String, String> dayNames = {
    'MONDAY': 'Lundi',
    'TUESDAY': 'Mardi',
    'WEDNESDAY': 'Mercredi',
    'THURSDAY': 'Jeudi',
    'FRIDAY': 'Vendredi',
    'SATURDAY': 'Samedi',
    'SUNDAY': 'Dimanche',
  };

  static const Map<int, String> weekdayToDay = {
    1: 'MONDAY',
    2: 'TUESDAY',
    3: 'WEDNESDAY',
    4: 'THURSDAY',
    5: 'FRIDAY',
    6: 'SATURDAY',
    7: 'SUNDAY',
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Appeler les 2 endpoints en parallèle
      final results = await Future.wait([
        http.get(
          Uri.parse('http://192.168.0.128:8080/api/workschedules/coiffeur/${widget.coiffeurId}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse('http://192.168.0.128:8080/api/reservations/coiffeur/${widget.coiffeurId}/slots'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        ).timeout(const Duration(seconds: 10)),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        final wsData = json.decode(results[0].body);
        final slotData = json.decode(results[1].body);

        setState(() {
          workSchedules = (wsData['data'] as List)
              .map((w) => WorkSchedule.fromJson(w))
              .toList();

          occupiedSlots = (slotData['data'] as List).map((s) {
            return {
              'start': DateTime.parse(s['startTime']),
              'end': DateTime.parse(s['endTime']),
            };
          }).toList();

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

  // Vérifie si un DateTime est occupé
  bool _isOccupied(DateTime dateTime) {
    return occupiedSlots.any((slot) =>
    dateTime.isAfter(slot['start']!.subtract(const Duration(minutes: 1))) &&
        dateTime.isBefore(slot['end']!));
  }

  // Récupère les workschedules pour un jour donné
  List<WorkSchedule> _getSchedulesForDate(DateTime date) {
    final dayName = weekdayToDay[date.weekday] ?? '';
    return workSchedules.where((ws) => ws.dayOfWeek == dayName).toList();
  }

  // Génère les 14 prochains jours
  List<DateTime> _getNextDays() {
    final now = DateTime.now();
    return List.generate(14, (i) => DateTime(now.year, now.month, now.day + i + 1));
  }

  double get totalPrice =>
      widget.selectedServices.fold(0, (sum, s) => sum + s.price);

  int get totalDuration =>
      widget.selectedServices.fold(0, (sum, s) => sum + s.duration);

  Future<void> _confirmerReservation() async {
    if (selectedDateTime == null) return;
    setState(() => isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.128:8080/api/reservations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'coiffeurId': widget.coiffeurId,
          'serviceIds': widget.selectedServices.map((s) => s.id).toList(),
          'startTime': selectedDateTime!.toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Réservation envoyée avec succès !'),
              backgroundColor: vert,
            ),
          );
          Navigator.pop(context);
          Navigator.pop(context);
        }
      } else {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Impossible de se connecter au serveur'),
            backgroundColor: rouge,
          ),
        );
      }
    }

    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Réserver',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : _buildContent(),
      bottomNavigationBar: selectedDateTime != null ? _buildConfirmButton() : null,
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
            onPressed: _fetchData,
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

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé en haut
          _buildSummary(),

          const SizedBox(height: 16),

          // Planning
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              'Disponibilités',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: marron,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Légende
          _buildLegend(),

          const SizedBox(height: 8),

          // Liste des jours
          ..._getNextDays().map((date) => _buildDayRow(date)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: marron,
                radius: 20,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.coiffeurName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: marron,
                      ),
                    ),
                    Text(
                      widget.selectedServices.map((s) => s.name).join(', '),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '$totalDuration min',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              Text(
                '${totalPrice.toStringAsFixed(0)} MAD',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: marron,
                ),
              ),
            ],
          ),
          if (selectedDateTime != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: marron),
                const SizedBox(width: 8),
                Text(
                  '${_formatDate(selectedDateTime!)} • ${_formatTime(selectedDateTime!)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: marron,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _legendItem(vert, 'Disponible'),
          const SizedBox(width: 16),
          _legendItem(rouge, 'Occupé'),
          const SizedBox(width: 16),
          _legendItem(Colors.grey.shade300, 'Fermé'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDayRow(DateTime date) {
    final schedules = _getSchedulesForDate(date);
    final dayName = weekdayToDay[date.weekday] ?? '';
    final dayLabel = dayNames[dayName] ?? '';
    final dateLabel = '${date.day}/${date.month}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom du jour
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dayLabel $dateLabel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (schedules.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Fermé',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),

          if (schedules.isEmpty)
            const SizedBox(height: 8),

          if (schedules.isEmpty)
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
            ),

          // Barres horaires
          if (schedules.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...schedules.map((schedule) => _buildTimeBar(date, schedule)),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeBar(DateTime date, WorkSchedule schedule) {
    final startParts = schedule.startTime.split(':');
    final endParts = schedule.endTime.split(':');

    final startHour = int.parse(startParts[0]);
    final startMin = int.parse(startParts[1]);
    final endHour = int.parse(endParts[0]);
    final endMin = int.parse(endParts[1]);

    final startDT = DateTime(date.year, date.month, date.day, startHour, startMin);
    final endDT = DateTime(date.year, date.month, date.day, endHour, endMin);
    final totalMinutes = endDT.difference(startDT).inMinutes;

    // Générer les segments de 30 min
    List<Widget> segments = [];
    DateTime current = startDT;

    while (current.isBefore(endDT)) {
      final segEnd = current.add(const Duration(minutes: 30));
      final isOccupied = _isOccupied(current);
      final isSelected = selectedDateTime != null &&
          selectedDateTime!.year == current.year &&
          selectedDateTime!.month == current.month &&
          selectedDateTime!.day == current.day &&
          selectedDateTime!.hour == current.hour &&
          selectedDateTime!.minute == current.minute;

      final segmentDT = current;

      segments.add(
        Expanded(
          child: GestureDetector(
            onTap: isOccupied
                ? null
                : () {
              setState(() {
                selectedDateTime =
                selectedDateTime == segmentDT ? null : segmentDT;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? marron
                    : isOccupied
                    ? rouge.withOpacity(0.7)
                    : vert.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
                border: isSelected
                    ? Border.all(color: marron, width: 2)
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ),
        ),
      );

      current = segEnd;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barre des segments
        Row(children: segments),
        const SizedBox(height: 4),
        // Heures début et fin
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              schedule.startTime,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              schedule.endTime,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _confirmerReservation,
        style: ElevatedButton.styleFrom(
          backgroundColor: marron,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(
              'Confirmer • ${_formatDate(selectedDateTime!)} • ${_formatTime(selectedDateTime!)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}