import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/service.dart';
import '../auth/login_screen.dart';
import '../client/reservation_screen.dart';

class CoiffeurDetailScreen extends StatefulWidget {
  final String coiffeurId;
  final String coiffeurName;
  final String? token;
  final String? role;

  const CoiffeurDetailScreen({
    super.key,
    required this.coiffeurId,
    required this.coiffeurName,
    this.token,
    this.role,
  });

  @override
  State<CoiffeurDetailScreen> createState() => _CoiffeurDetailScreenState();
}

class _CoiffeurDetailScreenState extends State<CoiffeurDetailScreen> {
  static const Color marron = Color(0xFF795548);

  // Data
  String? profilePicture;
  String? email;
  String? salonName;
  String? salonLocalisation;
  List<String> photos = [];
  List<Service> services = [];
  Set<String> selectedServices = {};

  // State
  bool isLoading = true;
  String? errorMessage;
  int currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchCoiffeurDetail();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoiffeurDetail() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await http.get(
        Uri.parse('http://192.168.0.128:8080/api/coiffeurs/${widget.coiffeurId}/detail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final detail = data['data'];
          setState(() {
            profilePicture = detail['profilePicture'];
            email = detail['email'];
            photos = List<String>.from(detail['photos'] ?? []);
            services = (detail['services'] as List? ?? [])
                .map((s) => Service.fromJson(s))
                .toList();
            if (detail['salon'] != null) {
              salonName = detail['salon']['name'];
              salonLocalisation = detail['salon']['localisation'];
            }
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

  double get totalPrice => services
      .where((s) => selectedServices.contains(s.id))
      .fold(0, (sum, s) => sum + s.price);

  int get totalDuration => services
      .where((s) => selectedServices.contains(s.id))
      .fold(0, (sum, s) => sum + s.duration);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : _buildContent(),
      // Bouton Réserver en bas (CLIENT seulement)
      bottomNavigationBar: !isLoading &&
          errorMessage == null &&
          widget.role == 'CLIENT' &&
          selectedServices.isNotEmpty
          ? _buildReserverButton()
          : null,
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
            onPressed: _fetchCoiffeurDetail,
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
    return CustomScrollView(
      slivers: [
        // AppBar avec photos
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: marron,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            widget.coiffeurName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: photos.isEmpty
                ? Container(
              color: marron,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white24,
                    backgroundImage: profilePicture != null
                        ? NetworkImage(profilePicture!)
                        : null,
                    child: profilePicture == null
                        ? const Icon(Icons.person, color: Colors.white, size: 60)
                        : null,
                  ),
                ],
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
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: marron,
                          child: const Icon(Icons.person, color: Colors.white, size: 80),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${currentPhotoIndex + 1}/${photos.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Infos coiffeur
                Row(
                  children: [
                    if (photos.isEmpty && profilePicture != null)
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(profilePicture!),
                      ),
                    if (photos.isEmpty && profilePicture != null)
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.coiffeurName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: marron,
                            ),
                          ),
                          if (salonName != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.content_cut, color: Colors.grey, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  salonName!,
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                          if (salonLocalisation != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  salonLocalisation!,
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Services
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ses Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: marron,
                      ),
                    ),
                    if (widget.role == 'CLIENT' && selectedServices.isNotEmpty)
                      Text(
                        '${totalDuration} min • ${totalPrice.toStringAsFixed(0)} MAD',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: marron,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                services.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aucun service disponible',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    return _buildServiceItem(services[index]);
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceItem(Service service) {
    final isSelected = selectedServices.contains(service.id);
    final isClient = widget.role == 'CLIENT';

    return GestureDetector(
      onTap: isClient
          ? () {
        setState(() {
          if (isSelected) {
            selectedServices.remove(service.id);
          } else {
            selectedServices.add(service.id);
          }
        });
      }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? marron.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? marron : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
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
            // Icône sélection (CLIENT seulement)
            if (isClient)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isSelected ? marron : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? marron : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),

            // Infos service
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? marron : Colors.black87,
                    ),
                  ),
                  if (service.description != null && service.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      service.description!,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Prix et durée
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${service.price.toStringAsFixed(0)} MAD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? marron : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(
                      '${service.duration} min',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReserverButton() {
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
        onPressed: () {
          // TODO: aller vers réservation je fais
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReservationScreen(
                coiffeurId: widget.coiffeurId,
                coiffeurName: widget.coiffeurName,
                selectedServices: services
                    .where((s) => selectedServices.contains(s.id))
                    .toList(),
                token: widget.token!,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: marron,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            Text(
              'Réserver • ${totalPrice.toStringAsFixed(0)} MAD • ${totalDuration} min',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}