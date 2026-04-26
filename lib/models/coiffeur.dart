class CoiffeurSalon {
  final String coiffeurId;
  final String name;
  final String? profilePicture;
  final bool isAdmin;

  CoiffeurSalon({
    required this.coiffeurId,
    required this.name,
    this.profilePicture,
    required this.isAdmin,
  });

  factory CoiffeurSalon.fromJson(Map<String, dynamic> json) {
    return CoiffeurSalon(
      coiffeurId: json['coiffeurId'].toString(),
      name: json['name'] ?? 'Coiffeur',
      profilePicture: json['profilePicture'],
      isAdmin: json['isAdmin'] ?? false,
    );
  }
}