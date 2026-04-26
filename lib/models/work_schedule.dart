class WorkSchedule {
  final String id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;

  WorkSchedule({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    return WorkSchedule(
      id: json['id'].toString(),
      dayOfWeek: json['dayOfWeek'],
      startTime: json['startTime'].toString().substring(0, 5),
      endTime: json['endTime'].toString().substring(0, 5),
    );
  }
}