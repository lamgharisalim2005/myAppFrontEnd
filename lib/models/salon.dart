class Salon {
  final String id;
  final String name;
  final String localisation;
  final double latitude;
  final double longitude;

  Salon({
    required this.id,
    required this.name,
    required this.localisation,
    required this.latitude,
    required this.longitude,
  });

  factory Salon.fromJson(Map<String, dynamic> json) {
    return Salon(
      id: json['id'],
      name: json['name'],
      localisation: json['localisation'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}