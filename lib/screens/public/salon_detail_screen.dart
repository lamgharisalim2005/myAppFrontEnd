import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../../models/coiffeur.dart';
import 'coiffeur_detail_screen.dart';

class SalonDetailScreen extends StatefulWidget {
  final String salonId;
  final String salonName;
  final String? token;
  final String? role;
  final String? userId;
  final bool isAdmin;

  const SalonDetailScreen({
    super.key,
    required this.salonId,
    required this.salonName,
    this.token,
    this.role,
    this.userId,
    this.isAdmin = false,
  });

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  static const Color marron = Color(0xFF795548);

  String localisation = '';
  List<String> photos = [];
  List<CoiffeurSalon> coiffeurs = [];
  CoiffeurSalon? selectedCoiffeur;

  bool isLoading = true;
  bool isLoadingAction = false;
  String? errorMessage;
  int currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchSalonDetail();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchSalonDetail() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/salons/${widget.salonId}/detail',
        widget.token ?? '',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final detail = data['data'];
          setState(() {
            localisation = detail['localisation'] ?? '';
            photos = List<String>.from(detail['photos'] ?? []);
            coiffeurs = (detail['coiffeurs'] as List? ?? [])
                .map((c) => CoiffeurSalon.fromJson(c))
                .toList();
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Erreur lors du chargement';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Erreur serveur: ${response.statusCode}';
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

  Future<void> _envoyerDemande() async {
    if (widget.token == null) return;
    setState(() => isLoadingAction = true);

    try {
      final response = await ApiService.post(
        'http://127.0.0.1:8080/api/salon-requests',
        widget.token ?? '',
        body: json.encode({'salonId': widget.salonId}),
      );

      final data = json.decode(response.body);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 201 && data['status'] == 'success'
                  ? '✅ Demande envoyée avec succès !'
                  : '❌ ${data['errors']?[0]?['message'] ?? 'Erreur'}',
            ),
            backgroundColor: response.statusCode == 201 ? marron : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Impossible de se connecter au serveur'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => isLoadingAction = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            errorMessage!,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchSalonDetail,
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
    return RefreshIndicator(
        color: marron,
        onRefresh: _fetchSalonDetail,
        child: CustomScrollView(
      slivers: [
        // AppBar avec photos
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: marron,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            widget.salonName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: photos.isEmpty
                ? Container(
              color: marron,
              child: const Icon(
                Icons.content_cut,
                color: Colors.white,
                size: 80,
              ),
            )
                : Stack(
              children: [
                // Carrousel photos
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => currentPhotoIndex = index);
                  },
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      photos[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: marron.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: marron,
                          child: const Icon(
                            Icons.content_cut,
                            color: Colors.white,
                            size: 80,
                          ),
                        );
                      },
                    );
                  },
                ),

                // Gradient en bas
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Points indicateurs
                if (photos.length > 1)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        photos.length,
                            (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: currentPhotoIndex == index ? 16 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: currentPhotoIndex == index
                                ? Colors.white
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Numéro photo
                if (photos.length > 1)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${currentPhotoIndex + 1}/${photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Contenu
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom et localisation
                Row(
                  children: [
                    const Icon(Icons.content_cut, color: marron, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.salonName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: marron,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      localisation,
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Liste coiffeurs
                const Text(
                  'Nos Coiffeurs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: marron,
                  ),
                ),
                const SizedBox(height: 16),

                coiffeurs.isEmpty
                    ? const Center(
                  child: Text(
                    'Aucun coiffeur disponible',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: coiffeurs.length,
                    itemBuilder: (context, index) {
                      return _buildCoiffeurCard(coiffeurs[index]);
                    },
                  ),
                ),

                // Coiffeur sélectionné → bouton Détails
                if (selectedCoiffeur != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: marron.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: marron.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: marron.withOpacity(0.1),
                          backgroundImage: selectedCoiffeur!.profilePicture != null
                              ? NetworkImage(selectedCoiffeur!.profilePicture!)
                              : null,
                          child: selectedCoiffeur!.profilePicture == null
                              ? const Icon(Icons.person, color: marron, size: 30)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedCoiffeur!.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: marron,
                                ),
                              ),
                              if (selectedCoiffeur!.isAdmin)
                                const Text(
                                  'Admin du salon',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // TODO: aller vers détails coiffeur je fais
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CoiffeurDetailScreen(
                                  coiffeurId: selectedCoiffeur!.coiffeurId,
                                  coiffeurName: selectedCoiffeur!.name,
                                  token: widget.token,
                                  role: widget.role,
                                  userId: widget.userId, // ← ajouter
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: marron,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Voir Détails'),
                        ),
                      ],
                    ),
                  ),
                ],

                const Divider(height: 32),

                // Bouton Rejoindre (COIFFEUR seulement et pas admin)
                if (widget.role == 'COIFFEUR' && !widget.isAdmin)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoadingAction ? null : _envoyerDemande,
                      icon: isLoadingAction
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.group_add),
                      label: const Text('Rejoindre ce salon'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: marron,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildCoiffeurCard(CoiffeurSalon coiffeur) {
    final isSelected = selectedCoiffeur?.coiffeurId == coiffeur.coiffeurId;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCoiffeur = isSelected ? null : coiffeur;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? marron.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? marron : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: marron.withOpacity(0.1),
              backgroundImage: coiffeur.profilePicture != null
                  ? NetworkImage(coiffeur.profilePicture!)
                  : null,
              child: coiffeur.profilePicture == null
                  ? const Icon(Icons.person, color: marron, size: 35)
                  : null,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                coiffeur.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? marron : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (coiffeur.isAdmin)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: marron,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}