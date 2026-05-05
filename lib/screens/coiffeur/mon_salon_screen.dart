import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'photos_salon_screen.dart';
import 'demandes_salon_screen.dart';
import 'mes_demandes_screen.dart';

class MonSalonScreen extends StatefulWidget {
  final String token;

  const MonSalonScreen({super.key, required this.token});

  @override
  State<MonSalonScreen> createState() => _MonSalonScreenState();
}

class _MonSalonScreenState extends State<MonSalonScreen> {
  static const Color marron = Color(0xFF795548);
  static const Color rouge = Color(0xFFE53935);
  static const Color vert = Color(0xFF4CAF50);
  static const Color orange = Color(0xFFFF9800);

  Map<String, dynamic>? salon;
  List<dynamic> membres = [];
  List<dynamic> demandes = [];
  bool isLoading = true;
  bool isAdmin = false;
  String? errorMessage;
  String? coiffeurId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final profileResponse = await ApiService.get(
        'http://127.0.0.1:8080/api/coiffeurs/profile',
        widget.token,
      );

      final profileData = json.decode(profileResponse.body);
      if (profileResponse.statusCode == 200 &&
          profileData['status'] == 'success') {
        coiffeurId = profileData['data']['userId'];

        final detailResponse = await ApiService.get(
          'http://127.0.0.1:8080/api/coiffeurs/$coiffeurId/detail',
          widget.token,
        );

        final detailData = json.decode(detailResponse.body);
        if (detailResponse.statusCode == 200 &&
            detailData['status'] == 'success') {
          final salonData = detailData['data']['salon'];

          if (salonData != null) {
            final salonId = salonData['id'];

            final salonResponse = await ApiService.get(
              'http://127.0.0.1:8080/api/salons/$salonId/detail',
              widget.token,
            );
            final salonDetailData = json.decode(salonResponse.body);
            if (salonResponse.statusCode == 200 &&
                salonDetailData['status'] == 'success') {
              final salonDetail = salonDetailData['data'];
              final coiffeurs = salonDetail['coiffeurs'] as List? ?? [];

              final monProfil = coiffeurs.firstWhere(
                    (c) => c['coiffeurId'] == coiffeurId,
                orElse: () => null,
              );

              setState(() {
                salon = salonDetail;
                membres = coiffeurs;
                isAdmin =
                    monProfil != null && monProfil['isAdmin'] == true;
                isLoading = false;
              });

              if (isAdmin) {
                await _fetchDemandes(salonId);
              }
            }
          } else {
            setState(() => isLoading = false);
          }
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Impossible de se connecter au serveur';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchDemandes(String salonId) async {
    try {
      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/salon-requests/salon/$salonId',
        widget.token,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          demandes = (data['data'] as List)
              .where((d) => d['status'] == 'PENDING')
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Erreur fetch demandes: $e');
    }
  }

  Future<void> _creerSalon(
      String name, String localisation, double lat, double lng) async {
    try {
      final response = await ApiService.post(
        'http://127.0.0.1:8080/api/salons',
        widget.token,
        body: json.encode({
          'name': name,
          'localisation': localisation,
          'latitude': lat,
          'longitude': lng,
        }),
      );

      if (response.statusCode == 201) {
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Salon créé avec succès'),
              backgroundColor: vert,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur création salon: $e');
    }
  }

  Future<void> _retirerMembre(String membreId) async {
    try {
      final response = await ApiService.put(
        'http://127.0.0.1:8080/api/salons/${salon!['id']}/retirer',
        widget.token,
        body: json.encode({'coiffeurId': membreId}),
      );

      if (response.statusCode == 200) {
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Membre retiré'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur retirer membre: $e');
    }
  }

  Future<void> _transfererAdmin(String nouveauAdminId) async {
    debugPrint('🔍 nouveauAdminId envoyé: $nouveauAdminId');
    try {
      final response = await ApiService.put(
        'http://127.0.0.1:8080/api/salons/${salon!['id']}/transferer',
        widget.token,
        body: json.encode({'nouveauAdminId': nouveauAdminId}),
      );

      if (response.statusCode == 200) {
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Administration transférée avec succès'),
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
      debugPrint('Erreur transfert admin: $e');
    }
  }

  Future<void> _quitterSalon() async {
    try {
      final response = await ApiService.put(
        'http://127.0.0.1:8080/api/coiffeurs/quitter-salon',
        widget.token,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Vous avez quitté le salon'),
              backgroundColor: marron,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Erreur quitter salon: $e');
    }
  }

  Future<void> _supprimerSalon() async {
    try {
      final response = await ApiService.delete(
        'http://127.0.0.1:8080/api/salons/${salon!['id']}',
        widget.token,
      );

      if (response.statusCode == 204) {
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Salon supprimé'),
              backgroundColor: marron,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Erreur suppression salon: $e');
    }
  }

  void _showTransfertDialog() {
    final autresMembres = membres
        .where(
            (m) => m['coiffeurId'] != coiffeurId && m['isAdmin'] != true)
        .toList();

    if (autresMembres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('❌ Aucun membre disponible pour le transfert'),
          backgroundColor: rouge,
        ),
      );
      return;
    }

    String? selectedMembreId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: marron),
              SizedBox(width: 8),
              Text(
                'Transférer l\'admin',
                style: TextStyle(
                  color: marron,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisissez le nouveau administrateur du salon :',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...autresMembres.map((membre) {
                final isSelected =
                    selectedMembreId == membre['coiffeurId'];
                return GestureDetector(
                  onTap: () {
                    setStateDialog(() {
                      selectedMembreId = membre['coiffeurId'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? marron.withOpacity(0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                        isSelected ? marron : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: marron.withOpacity(0.1),
                          backgroundImage:
                          membre['profilePicture'] != null
                              ? NetworkImage(
                              membre['profilePicture'])
                              : null,
                          child: membre['profilePicture'] == null
                              ? const Icon(Icons.person,
                              color: marron, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            membre['name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? marron
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: marron),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedMembreId == null
                  ? null
                  : () {
                debugPrint('🔍 selectedMembreId: $selectedMembreId');
                Navigator.pop(ctx);
                _confirmerTransfert(selectedMembreId!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: marron,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Transférer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmerTransfert(String nouveauAdminId) {
    final membre = membres.firstWhere(
          (m) => m['coiffeurId'] == nouveauAdminId,
      orElse: () => {},
    );
    final nom = membre['name'] ?? 'ce membre';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer le transfert'),
        content: Text(
          'Êtes-vous sûr de vouloir transférer l\'administration à $nom ?\n\nVous deviendrez un membre simple.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _transfererAdmin(nouveauAdminId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: marron,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, transférer'),
          ),
        ],
      ),
    );
  }

  void _showCreerSalonDialog() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Récupération de votre position...'),
          duration: Duration(seconds: 2),
          backgroundColor: marron,
        ),
      );
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      debugPrint('Erreur GPS: $e');
    }

    if (!mounted) return;

    final nameController = TextEditingController();
    final localisationController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.store, color: marron),
            SizedBox(width: 8),
            Text(
              'Créer un salon',
              style: TextStyle(
                color: marron,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nom du salon',
                labelStyle: const TextStyle(color: marron),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: marron),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: localisationController,
              decoration: InputDecoration(
                labelText: 'Adresse',
                labelStyle: const TextStyle(color: marron),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: marron),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (position != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: vert.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: vert.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: vert, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Position GPS détectée ✅\n${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                            color: vert, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rouge.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_off, color: rouge, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'GPS non disponible',
                      style: TextStyle(color: rouge, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: position == null
                ? null
                : () {
              final name = nameController.text.trim();
              final localisation =
              localisationController.text.trim();

              if (name.isEmpty || localisation.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                    Text('❌ Remplissez tous les champs'),
                    backgroundColor: rouge,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _creerSalon(
                name,
                localisation,
                position!.latitude,
                position!.longitude,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: position == null ? Colors.grey : marron,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mon Salon',
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
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: salon == null
              ? _buildPasDeSalon()
              : _buildSalon(),
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

  Widget _buildPasDeSalon() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
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
            children: [
              Icon(Icons.store, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'Vous n\'avez pas de salon',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Créez votre salon ou rejoignez-en un',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showCreerSalonDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Créer un salon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: marron,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search, color: marron),
                  label: const Text(
                    'Chercher un salon sur la carte',
                    style: TextStyle(color: marron),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: marron),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSectionButton(
          icon: Icons.send,
          title: 'Mes Demandes',
          subtitle: 'Voir vos demandes envoyées aux salons',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MesDemandesScreen(token: widget.token),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSalon() {
    return Column(
      children: [
        _buildSalonInfo(),
        const SizedBox(height: 16),

        if (isAdmin) ...[
          _buildSectionButton(
            icon: Icons.people,
            title: 'Demandes reçues',
            subtitle: demandes.isNotEmpty
                ? '${demandes.length} demande(s) en attente'
                : 'Aucune demande en attente',
            badge: demandes.isNotEmpty ? demandes.length : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DemandesSalonScreen(
                    token: widget.token,
                    salonId: salon!['id'],
                    salonName: salon!['name'],
                  ),
                ),
              ).then((_) => _fetchData());
            },
          ),
          const SizedBox(height: 16),
        ],

        _buildMembres(),
        const SizedBox(height: 16),

        if (isAdmin)
          _buildAdminActions()
        else
          _buildMembreActions(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSalonInfo() {
    return Container(
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
                  salon!['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: marron,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.grey, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        salon!['localisation'] ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: marron,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMembres() {
    return Container(
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
              const Text(
                'Membres',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: marron,
                ),
              ),
              Text(
                '${membres.length} membre(s)',
                style:
                const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...membres.map((membre) => _buildMembreCard(membre)),
        ],
      ),
    );
  }

  Widget _buildMembreCard(dynamic membre) {
    final isMe = membre['coiffeurId'] == coiffeurId;
    final membreIsAdmin = membre['isAdmin'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? marron.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? marron.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: marron.withOpacity(0.1),
            backgroundImage: membre['profilePicture'] != null
                ? NetworkImage(membre['profilePicture'])
                : null,
            child: membre['profilePicture'] == null
                ? const Icon(Icons.person, color: marron, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      membre['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '(Moi)',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                if (membreIsAdmin)
                  const Text(
                    'Admin',
                    style: TextStyle(color: marron, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (isAdmin && !isMe && !membreIsAdmin)
            IconButton(
              onPressed: () =>
                  _confirmerRetrait(membre['coiffeurId'], membre['name']),
              icon: const Icon(Icons.remove_circle_outline, color: rouge),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminActions() {
    return Container(
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
          const Text(
            'Actions Admin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: marron,
            ),
          ),
          const SizedBox(height: 12),

          _buildSectionButton(
            icon: Icons.photo_library,
            title: 'Photos du salon',
            subtitle: 'Gérer les photos du salon',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotosSalonScreen(
                    token: widget.token,
                    salonId: salon!['id'],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ✅ Bouton transfert admin
          _buildSectionButton(
            icon: Icons.admin_panel_settings,
            title: 'Transférer l\'administration',
            subtitle: 'Passer le rôle admin à un autre membre',
            onTap: () => _showTransfertDialog(),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmerSuppressionSalon(),
              icon: const Icon(Icons.delete_outline, color: rouge),
              label: const Text(
                'Supprimer le salon',
                style: TextStyle(color: rouge),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: rouge),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembreActions() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmerQuitter(),
        icon: const Icon(Icons.exit_to_app, color: rouge),
        label: const Text(
          'Quitter le salon',
          style: TextStyle(color: rouge),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: rouge),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
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
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: marron.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: marron),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _confirmerRetrait(String membreId, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: Text(
            'Êtes-vous sûr de vouloir retirer $name du salon ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retirerMembre(membreId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: rouge,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, retirer'),
          ),
        ],
      ),
    );
  }

  void _confirmerQuitter() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitter le salon'),
        content: const Text(
            'Êtes-vous sûr de vouloir quitter ce salon ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _quitterSalon();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: rouge,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, quitter'),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppressionSalon() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le salon'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce salon ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerSalon();
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
}