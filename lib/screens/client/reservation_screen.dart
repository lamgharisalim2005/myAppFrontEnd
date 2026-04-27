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

  List<WorkSchedule> workSchedules = [];
  List<Map<String, DateTime>> occupiedSlots = [];

  DateTime? selectedDate;
  int selectedHour = 9;
  int selectedMinute = 0;
  String? slotStatus; // 'available', 'occupied', 'outside'

  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

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

      final results = await Future.wait([
        http.get(
          Uri.parse('http://192.168.0.144:8080/api/workschedules/coiffeur/${widget.coiffeurId}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse('http://192.168.0.144:8080/api/reservations/coiffeur/${widget.coiffeurId}/slots'),
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

  List<WorkSchedule> _getSchedulesForDate(DateTime date) {
    final dayName = weekdayToDay[date.weekday] ?? '';
    return workSchedules.where((ws) => ws.dayOfWeek == dayName).toList();
  }

  // Vérifie le statut du créneau sélectionné
  void _checkSlotStatus() {
    if (selectedDate == null) return;

    final selectedDT = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedHour,
      selectedMinute,
    );

    final endDT = selectedDT.add(Duration(minutes: totalDuration));

    // Vérifier si dans les horaires de travail
    final schedules = _getSchedulesForDate(selectedDate!);
    bool inWorkHours = false;

    for (var schedule in schedules) {
      final startParts = schedule.startTime.split(':');
      final endParts = schedule.endTime.split(':');

      final workStart = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );
      final workEnd = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      if (!selectedDT.isBefore(workStart) && !endDT.isAfter(workEnd)) {
        inWorkHours = true;
        break;
      }
    }

    if (!inWorkHours) {
      setState(() => slotStatus = 'outside');
      return;
    }

    // Vérifier si occupé
    bool isOccupied = occupiedSlots.any((slot) {
      return selectedDT.isBefore(slot['end']!) &&
          endDT.isAfter(slot['start']!);
    });

    setState(() => slotStatus = isOccupied ? 'occupied' : 'available');
  }

  List<DateTime> _getNextDays() {
    final now = DateTime.now();
    return List.generate(
        14, (i) => DateTime(now.year, now.month, now.day + i + 1));
  }

  double get totalPrice =>
      widget.selectedServices.fold(0, (sum, s) => sum + s.price);

  int get totalDuration =>
      widget.selectedServices.fold(0, (sum, s) => sum + s.duration);

  Future<void> _confirmerReservation() async {
    if (selectedDate == null || slotStatus != 'available') return;
    setState(() => isSubmitting = true);

    final selectedDT = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedHour,
      selectedMinute,
    );

    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.144:8080/api/reservations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'coiffeurId': widget.coiffeurId,
          'serviceIds': widget.selectedServices.map((s) => s.id).toList(),
          'startTime': selectedDT.toIso8601String(),
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
      bottomNavigationBar:
      selectedDate != null && slotStatus == 'available'
          ? _buildConfirmButton()
          : null,
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
          // Résumé
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
          _buildLegend(),
          const SizedBox(height: 8),

          // Jours
          ..._getNextDays().map((date) => _buildDayRow(date)),

          // Sélecteur d'heure (si jour sélectionné)
          if (selectedDate != null) ...[
            const SizedBox(height: 16),
            _buildTimePicker(),
          ],

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
                  Text('$totalDuration min',
                      style: const TextStyle(color: Colors.grey)),
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
          width: 14,
          height: 14,
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
    final isSelected = selectedDate?.day == date.day &&
        selectedDate?.month == date.month &&
        selectedDate?.year == date.year;

    return GestureDetector(
      onTap: schedules.isEmpty
          ? null
          : () {
        setState(() {
          selectedDate = date;
          slotStatus = null;
        });
        _checkSlotStatus();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? marron.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? marron : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$dayLabel ${date.day}/${date.month}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? marron : Colors.black87,
                  ),
                ),
                if (schedules.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
            const SizedBox(height: 10),

            // Barres horaires
            if (schedules.isEmpty)
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),

            if (schedules.isNotEmpty)
              ...schedules.map((schedule) => _buildTimeBar(date, schedule)),
          ],
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barre visuelle
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            // Construire les segments occupés
            List<Widget> barSegments = [];
            DateTime current = startDT;

            while (current.isBefore(endDT)) {
              final nextMinute = current.add(const Duration(minutes: 1));
              final isOccupied = occupiedSlots.any((slot) =>
              current.isAfter(slot['start']!.subtract(const Duration(minutes: 1))) &&
                  current.isBefore(slot['end']!));

              // Trouver la fin du segment actuel (même statut)
              DateTime segEnd = current;
              while (segEnd.isBefore(endDT)) {
                final segOccupied = occupiedSlots.any((slot) =>
                segEnd.isAfter(slot['start']!.subtract(const Duration(minutes: 1))) &&
                    segEnd.isBefore(slot['end']!));
                if (segOccupied != isOccupied) break;
                segEnd = segEnd.add(const Duration(minutes: 1));
              }

              final segMinutes = segEnd.difference(current).inMinutes;
              final segWidth = (segMinutes / totalMinutes) * width;

              barSegments.add(
                Container(
                  width: segWidth,
                  height: 16,
                  color: isOccupied ? rouge.withOpacity(0.8) : vert.withOpacity(0.8),
                ),
              );

              current = segEnd;
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(children: barSegments),
            );
          },
        ),

        const SizedBox(height: 4),

        // Heures
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

  Widget _buildTimePicker() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
          Text(
            'Choisir l\'heure pour ${dayNames[weekdayToDay[selectedDate!.weekday]] ?? ''} ${selectedDate!.day}/${selectedDate!.month}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: marron,
            ),
          ),
          const SizedBox(height: 20),

          // Sélecteur heure + minute
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Heures
              _buildScrollPicker(
                value: selectedHour,
                min: 0,
                max: 23,
                label: 'h',
                onChanged: (val) {
                  setState(() => selectedHour = val);
                  _checkSlotStatus();
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: marron,
                  ),
                ),
              ),

              // Minutes
              _buildScrollPicker(
                value: selectedMinute,
                min: 0,
                max: 59,
                label: 'min',
                onChanged: (val) {
                  setState(() => selectedMinute = val);
                  _checkSlotStatus();
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Statut du créneau
          if (slotStatus != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: slotStatus == 'available'
                    ? vert.withOpacity(0.1)
                    : slotStatus == 'occupied'
                    ? rouge.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: slotStatus == 'available'
                      ? vert
                      : slotStatus == 'occupied'
                      ? rouge
                      : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    slotStatus == 'available'
                        ? Icons.check_circle
                        : slotStatus == 'occupied'
                        ? Icons.cancel
                        : Icons.warning,
                    color: slotStatus == 'available'
                        ? vert
                        : slotStatus == 'occupied'
                        ? rouge
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slotStatus == 'available'
                          ? '✅ Créneau disponible ! ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')} → ${_formatEndTime()}'
                          : slotStatus == 'occupied'
                          ? '❌ Ce créneau est déjà occupé'
                          : '⚠️ Hors des horaires de travail',
                      style: TextStyle(
                        color: slotStatus == 'available'
                            ? vert
                            : slotStatus == 'occupied'
                            ? rouge
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
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

  Widget _buildScrollPicker({
    required int value,
    required int min,
    required int max,
    required String label,
    required Function(int) onChanged,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: marron.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: marron.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              // Bouton +
              IconButton(
                onPressed: () {
                  final newVal = value < max ? value + 1 : min;
                  onChanged(newVal);
                },
                icon: const Icon(Icons.keyboard_arrow_up, color: marron),
              ),
              // Valeur
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  value.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: marron,
                  ),
                ),
              ),
              // Bouton -
              IconButton(
                onPressed: () {
                  final newVal = value > min ? value - 1 : max;
                  onChanged(newVal);
                },
                icon: const Icon(Icons.keyboard_arrow_down, color: marron),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatEndTime() {
    final endDT = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedHour,
      selectedMinute,
    ).add(Duration(minutes: totalDuration));
    return '${endDT.hour.toString().padLeft(2, '0')}:${endDT.minute.toString().padLeft(2, '0')}';
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
            : Text(
          'Confirmer • ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')} • ${totalPrice.toStringAsFixed(0)} MAD',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}