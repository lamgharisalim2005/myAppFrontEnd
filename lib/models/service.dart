class Service {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int duration;

  Service({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.duration,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      duration: json['duration'] ?? 0,
    );
  }
}