import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../../models/service.dart';
import '../../models/work_schedule.dart';
import '../../config/app_config.dart';

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
  TimeOfDay? selectedTime;
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

      final wsResponse = await ApiService.get(
        '${AppConfig.baseUrl}/api/workschedules/coiffeur/${widget.coiffeurId}',
        widget.token,
      );
      final slotResponse = await ApiService.get(
        '${AppConfig.baseUrl}/api/reservations/coiffeur/${widget.coiffeurId}/slots',
        widget.token,
      );

      if (wsResponse.statusCode == 200 && slotResponse.statusCode == 200) {
        final wsData = json.decode(wsResponse.body);
        final slotData = json.decode(slotResponse.body);

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

  List<DateTime> _getNextDays() {
    final now = DateTime.now();
    return List.generate(
      14,
          (i) => DateTime(now.year, now.month, now.day + i + 1),
    );
  }

  double get totalPrice =>
      widget.selectedServices.fold(0, (sum, s) => sum + s.price);

  int get totalDuration =>
      widget.selectedServices.fold(0, (sum, s) => sum + s.duration);

  // Vérifie si une minute précise est dans un slot occupé
  bool _isMinuteOccupied(DateTime minute) {
    final minuteEnd = minute.add(const Duration(minutes: 1));
    return occupiedSlots.any((slot) {
      return minute.isBefore(slot['end']!) &&
          minuteEnd.isAfter(slot['start']!);
    });
  }

  // Vérifie si l'heure choisie est valide
  String? _validerHeure(TimeOfDay time) {
    if (selectedDate == null) return 'Choisissez un jour d\'abord';

    final schedules = _getSchedulesForDate(selectedDate!);
    if (schedules.isEmpty) return 'Le coiffeur ne travaille pas ce jour';

    final selectedDT = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      time.hour,
      time.minute,
    );
    final endDT = selectedDT.add(Duration(minutes: totalDuration));

    bool dansHoraires = false;
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
        dansHoraires = true;
        break;
      }
    }

    if (!dansHoraires) {
      return 'Hors des horaires de travail\n(le service finit après la fermeture)';
    }

    // Vérifier si une minute dans le créneau est occupée
    for (int i = 0; i < totalDuration; i++) {
      final minute = selectedDT.add(Duration(minutes: i));
      if (_isMinuteOccupied(minute)) {
        return 'Ce créneau est déjà occupé';
      }
    }

    return null;
  }

  void _showTimePicker(WorkSchedule schedule) {
    TimeOfDay selectedTimeDialog = TimeOfDay(
      hour: int.parse(schedule.startTime.split(':')[0]),
      minute: int.parse(schedule.startTime.split(':')[1]),
    );

    String? validationError;

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
                child: const Icon(Icons.access_time, color: marron),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choisir l\'heure',
                    style: TextStyle(
                      color: marron,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Durée : $totalDuration min',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: marron.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.work, color: marron, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Horaires : ${schedule.startTime.substring(0, 5)} → ${schedule.endTime.substring(0, 5)}',
                      style: const TextStyle(
                        color: marron,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: selectedTimeDialog,
                    builder: (context, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme:
                        const ColorScheme.light(primary: marron),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    final error = _validerHeure(picked);
                    setStateDialog(() {
                      selectedTimeDialog = picked;
                      validationError = error;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: validationError == null &&
                        selectedTimeDialog !=
                            TimeOfDay(
                              hour: int.parse(
                                  schedule.startTime.split(':')[0]),
                              minute: int.parse(
                                  schedule.startTime.split(':')[1]),
                            )
                        ? vert.withOpacity(0.1)
                        : marron.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: validationError == null &&
                          selectedTimeDialog !=
                              TimeOfDay(
                                hour: int.parse(
                                    schedule.startTime.split(':')[0]),
                                minute: int.parse(
                                    schedule.startTime.split(':')[1]),
                              )
                          ? vert
                          : marron.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, color: marron),
                      const SizedBox(width: 8),
                      Text(
                        '${selectedTimeDialog.hour.toString().padLeft(2, '0')}:${selectedTimeDialog.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: marron,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  final startDT = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    selectedTimeDialog.hour,
                    selectedTimeDialog.minute,
                  );
                  final endDT =
                  startDT.add(Duration(minutes: totalDuration));
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward,
                          color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Fin : ${endDT.hour.toString().padLeft(2, '0')}:${endDT.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),

              if (validationError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: rouge.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: rouge.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: rouge, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          validationError!,
                          style: const TextStyle(
                            color: rouge,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: validationError != null
                  ? null
                  : () {
                final error = _validerHeure(selectedTimeDialog);
                if (error != null) {
                  setStateDialog(() => validationError = error);
                  return;
                }
                Navigator.pop(ctx);
                setState(() {
                  selectedTime = selectedTimeDialog;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: marron,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmerReservation() async {
    if (selectedDate == null || selectedTime == null) return;
    setState(() => isSubmitting = true);

    final selectedDT = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    try {
      final response = await ApiService.post(
        '${AppConfig.baseUrl}/api/reservations',
        widget.token,
        body: json.encode({
          'coiffeurId': widget.coiffeurId,
          'serviceIds':
          widget.selectedServices.map((s) => s.id).toList(),
          'startTime': selectedDT.toIso8601String(),
        }),
      );

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
              content: Text(
                  '❌ ${data['errors']?[0]?['message'] ?? 'Erreur'}'),
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
          'Choisir un créneau',
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
          : _buildContent(),
      bottomNavigationBar:
      selectedDate != null && selectedTime != null
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
          _buildSummary(),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              'Choisissez un jour',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: marron,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildDaySelector(),
          const SizedBox(height: 24),

          if (selectedDate != null) ...[
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
            _buildLegende(),
            const SizedBox(height: 12),
            _buildHoraireBars(),
          ],

          if (selectedTime != null) ...[
            const SizedBox(height: 16),
            _buildSelectedSlot(),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
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
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final days = _getNextDays();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          final schedules = _getSchedulesForDate(date);
          final isOpen = schedules.isNotEmpty;
          final isSelected = selectedDate?.day == date.day &&
              selectedDate?.month == date.month &&
              selectedDate?.year == date.year;

          final dayName = weekdayToDay[date.weekday] ?? '';
          final dayLabel = dayNames[dayName] ?? '';

          return GestureDetector(
            onTap: isOpen
                ? () {
              setState(() {
                selectedDate = date;
                selectedTime = null;
              });
            }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? marron
                    : isOpen
                    ? Colors.white
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? marron
                      : isOpen
                      ? marron.withOpacity(0.3)
                      : Colors.transparent,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: marron.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayLabel.substring(0, 3),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : isOpen
                          ? marron
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : isOpen
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : isOpen
                          ? vert
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegende() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _legendItem(vert, 'Disponible — cliquez pour choisir'),
          const SizedBox(width: 16),
          _legendItem(rouge, 'Occupé'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildHoraireBars() {
    if (selectedDate == null) return const SizedBox();

    final schedules = _getSchedulesForDate(selectedDate!);
    if (schedules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Le coiffeur ne travaille pas ce jour',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: schedules.map((schedule) {
          return _buildScheduleBar(schedule);
        }).toList(),
      ),
    );
  }

  Widget _buildScheduleBar(WorkSchedule schedule) {
    final startParts = schedule.startTime.split(':');
    final endParts = schedule.endTime.split(':');

    final startHour = int.parse(startParts[0]);
    final startMin = int.parse(startParts[1]);
    final endHour = int.parse(endParts[0]);
    final endMin = int.parse(endParts[1]);

    final workStart = DateTime(
      selectedDate!.year, selectedDate!.month, selectedDate!.day,
      startHour, startMin,
    );
    final workEnd = DateTime(
      selectedDate!.year, selectedDate!.month, selectedDate!.day,
      endHour, endMin,
    );

    final totalMinutes = workEnd.difference(workStart).inMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                schedule.startTime.substring(0, 5),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: marron,
                  fontSize: 13,
                ),
              ),
              Text(
                schedule.endTime.substring(0, 5),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: marron,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          GestureDetector(
            onTapDown: (details) {
              _showTimePicker(schedule);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;

                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 40,
                        width: barWidth,
                        child: CustomPaint(
                          painter: _ScheduleBarPainter(
                            workStart: workStart,
                            workEnd: workEnd,
                            totalMinutes: totalMinutes,
                            occupiedSlots: occupiedSlots,
                            vertColor: vert,
                            rougeColor: rouge,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Appuyez pour choisir votre heure',
                          style:
                          TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedSlot() {
    if (selectedTime == null) return const SizedBox();

    final startDT = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );
    final endDT = startDT.add(Duration(minutes: totalDuration));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vert.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vert.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: vert),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Créneau sélectionné',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: vert,
                  ),
                ),
                Text(
                  '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')} → ${endDT.hour.toString().padLeft(2, '0')}:${endDT.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: vert,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              final schedules = _getSchedulesForDate(selectedDate!);
              if (schedules.isNotEmpty) {
                _showTimePicker(schedules.first);
              }
            },
            child: const Text(
              'Modifier',
              style: TextStyle(color: marron),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final startDT = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );
    final endDT = startDT.add(Duration(minutes: totalDuration));

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
          'Confirmer • ${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')} → ${endDT.hour.toString().padLeft(2, '0')}:${endDT.minute.toString().padLeft(2, '0')} • ${totalPrice.toStringAsFixed(0)} MAD',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// CustomPainter pour dessiner la barre avec précision à la minute
class _ScheduleBarPainter extends CustomPainter {
  final DateTime workStart;
  final DateTime workEnd;
  final int totalMinutes;
  final List<Map<String, DateTime>> occupiedSlots;
  final Color vertColor;
  final Color rougeColor;

  _ScheduleBarPainter({
    required this.workStart,
    required this.workEnd,
    required this.totalMinutes,
    required this.occupiedSlots,
    required this.vertColor,
    required this.rougeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintVert = Paint()..color = vertColor.withOpacity(0.7);
    final paintRouge = Paint()..color = rougeColor.withOpacity(0.7);
    final paintDivider = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 0.5;

    // Dessiner minute par minute pour une précision parfaite
    for (int i = 0; i < totalMinutes; i++) {
      final minute = workStart.add(Duration(minutes: i));
      final minuteEnd = minute.add(const Duration(minutes: 1));

      // Vérifier si cette minute est occupée
      final isOccupied = occupiedSlots.any((slot) =>
      minute.isBefore(slot['end']!) &&
          minuteEnd.isAfter(slot['start']!));

      final x = (i / totalMinutes) * size.width;
      final w = size.width / totalMinutes;

      final rect = Rect.fromLTWH(x, 0, w, size.height);
      canvas.drawRect(rect, isOccupied ? paintRouge : paintVert);
    }

    // Dessiner les diviseurs par dessus
    for (int i = 0; i < totalMinutes; i++) {
      final minutesFromStart = i;
      final isHour = minutesFromStart % 60 == 0;
      final isHalfHour = minutesFromStart % 30 == 0 && !isHour;
      final isQuarter = minutesFromStart % 15 == 0 && !isHour && !isHalfHour;

      if (i > 0 && (isHour || isHalfHour || isQuarter)) {
        final x = (i / totalMinutes) * size.width;
        final dividerHeight = isHour
            ? size.height
            : isHalfHour
            ? size.height * 0.7
            : size.height * 0.4;

        final dividerWidth = isHour ? 1.5 : isHalfHour ? 1.0 : 0.5;
        paintDivider.strokeWidth = dividerWidth;

        canvas.drawLine(
          Offset(x, size.height - dividerHeight),
          Offset(x, size.height),
          paintDivider,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}