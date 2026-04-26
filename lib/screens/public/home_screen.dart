import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../models/salon.dart';
import '../auth/login_screen.dart';
import '../public/salon_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? token;
  final String? role;

  const HomeScreen({super.key, this.token, this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  List<Salon> salons = [];
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool isLoading = true;
  Salon? selectedSalon;
  Position? userPosition;
  final TextEditingController searchController = TextEditingController();
  bool showSearchResults = false;
  List<Salon> searchResults = [];

  static const String orsApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImQyZTc2ZjVjMzFhNzRhZTFiNTllZTkxZmI1MzcwNjVhIiwiaCI6Im11cm11cjY0In0=';
  static const Color marron = Color(0xFF795548);

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(34.0209, -5.0078),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    fetchSalons();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() => userPosition = position);
    } catch (e) {
      debugPrint('Erreur localisation: $e');
    }
  }

  Future<void> _goToUserLocation() async {
    if (userPosition == null) await _getUserLocation();
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(userPosition!.latitude, userPosition!.longitude),
        16,
      ),
    );
  }

  Future<void> fetchSalons() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.128:8080/api/salons'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final List listeSalons = data['data'];
        salons = listeSalons.map((s) => Salon.fromJson(s)).toList();
        await _createMarkers();
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _createMarkers() async {
    Set<Marker> newMarkers = {};
    for (var salon in salons) {
      final icon = await _createCustomMarker(salon.name);
      newMarkers.add(
        Marker(
          markerId: MarkerId(salon.id),
          position: LatLng(salon.latitude, salon.longitude),
          icon: icon,
          onTap: () {
            setState(() {
              selectedSalon = salon;
              polylines.clear();
            });
          },
        ),
      );
    }
    setState(() => markers = newMarkers);
  }

  Future<BitmapDescriptor> _createCustomMarker(String name) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double width = 160;
    const double height = 80;

    final Paint shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(3, 3, width, height), const Radius.circular(12)),
      shadowPaint,
    );

    final Paint bgPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width, height), const Radius.circular(12)),
      bgPaint,
    );

    final Paint topPaint = Paint()..color = marron;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, width, 28),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
      ),
      topPaint,
    );

    final TextPainter iconPainter = TextPainter(
      text: const TextSpan(text: '✂️', style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(canvas, const Offset(8, 5));

    final TextPainter titlePainter = TextPainter(
      text: const TextSpan(
        text: 'Salon',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(canvas, const Offset(32, 8));

    final TextPainter namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: marron),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    namePainter.layout(maxWidth: width - 10);
    namePainter.paint(canvas, Offset((width - namePainter.width) / 2, 35));

    final Paint trianglePaint = Paint()..color = Colors.white;
    final Path triangle = Path()
      ..moveTo(width / 2 - 8, height)
      ..lineTo(width / 2 + 8, height)
      ..lineTo(width / 2, height + 10)
      ..close();
    canvas.drawPath(triangle, trianglePaint);

    final img = await recorder.endRecording().toImage(width.toInt(), (height + 10).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<void> _showRoute() async {
    if (userPosition == null || selectedSalon == null) return;
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${userPosition!.longitude},${userPosition!.latitude}&end=${selectedSalon!.longitude},${selectedSalon!.latitude}',
        ),
      );
      final data = json.decode(response.body);
      final List coords = data['features'][0]['geometry']['coordinates'];
      List<LatLng> polylineCoordinates = coords
          .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();

      setState(() {
        polylines.clear();
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: marron,
            width: 5,
            points: polylineCoordinates,
          ),
        );
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              userPosition!.latitude < selectedSalon!.latitude ? userPosition!.latitude : selectedSalon!.latitude,
              userPosition!.longitude < selectedSalon!.longitude ? userPosition!.longitude : selectedSalon!.longitude,
            ),
            northeast: LatLng(
              userPosition!.latitude > selectedSalon!.latitude ? userPosition!.latitude : selectedSalon!.latitude,
              userPosition!.longitude > selectedSalon!.longitude ? userPosition!.longitude : selectedSalon!.longitude,
            ),
          ),
          100,
        ),
      );
    } catch (e) {
      debugPrint('Erreur itinéraire: $e');
    }
  }

  void filtrerSalons(String recherche) async {
    final filtered = salons
        .where((s) => s.name.toLowerCase().contains(recherche.toLowerCase()))
        .toList();

    Set<Marker> newMarkers = {};
    for (var salon in filtered) {
      final icon = await _createCustomMarker(salon.name);
      newMarkers.add(
        Marker(
          markerId: MarkerId(salon.id),
          position: LatLng(salon.latitude, salon.longitude),
          icon: icon,
          onTap: () {
            setState(() {
              selectedSalon = salon;
              polylines.clear();
            });
          },
        ),
      );
    }

    setState(() {
      markers = newMarkers;
      showSearchResults = recherche.isNotEmpty;
      searchResults = filtered;
    });
  }

  Widget _buildMapButton(IconData icon, VoidCallback? onPressed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: marron,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ GOOGLE MAP
          GoogleMap(
            zoomControlsEnabled: false,
            initialCameraPosition: _initialPosition,
            markers: markers,
            polylines: polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              mapController = controller;
              _goToUserLocation();
            },
            onTap: (_) {
              setState(() {
                selectedSalon = null;
                polylines.clear();
                showSearchResults = false;
                searchController.clear();
              });
            },
          ),

          // 🔍 BARRE DE RECHERCHE
          Positioned(
            top: 50,
            left: 16,
            right: 72,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: TextField(
                controller: searchController,
                onChanged: filtrerSalons,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un salon...',
                  prefixIcon: Icon(Icons.search, color: marron),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          // 📋 Liste résultats recherche
          if (showSearchResults)
            Positioned(
              top: 110,
              left: 16,
              width: 250,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final salon = searchResults[index];
                    return ListTile(
                      leading: const Text('✂️'),
                      title: Text(
                        salon.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: marron),
                      ),
                      subtitle: Text(salon.localisation),
                      onTap: () {
                        mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(salon.latitude, salon.longitude), 17,
                          ),
                        );
                        setState(() {
                          selectedSalon = salon;
                          showSearchResults = false;
                          searchController.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ),

          // Boutons à droite
          Positioned(
            top: 50,
            right: 16,
            child: Column(
              children: [
                // 🚪 Déconnexion
                _buildMapButton(Icons.logout, () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                    );
                  }
                }),
                const SizedBox(height: 8),
                // 📍 Ma position
                _buildMapButton(Icons.my_location, _goToUserLocation),
                const SizedBox(height: 8),
                // 🗺️ Itinéraire
                _buildMapButton(
                  Icons.directions,
                  selectedSalon != null ? _showRoute : null,
                ),
                const SizedBox(height: 8),
                // 🧭 Orientation
                _buildMapButton(Icons.explore, () {
                  mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          userPosition?.latitude ?? 34.0209,
                          userPosition?.longitude ?? -5.0078,
                        ),
                        zoom: 16,
                        bearing: 0,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // 🏪 Carte salon sélectionné
          if (selectedSalon != null)
            Positioned(
              bottom: widget.token != null ? 80 : 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    const Text('✂️', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedSalon!.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: marron,
                            ),
                          ),
                          Text(
                            selectedSalon!.localisation,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: aller vers détails salon je fais
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SalonDetailScreen(
                              salonId: selectedSalon!.id,
                              salonName: selectedSalon!.name,
                              token: widget.token,
                              role: widget.role,
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
                      child: const Text('Détails'),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          selectedSalon = null;
                          polylines.clear();
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // ➕ Zoom +
          Positioned(
            bottom: widget.token != null ? 250 : 180,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: marron,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: IconButton(
                onPressed: () {
                  mapController?.animateCamera(CameraUpdate.zoomIn());
                },
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),

          // ➖ Zoom -
          Positioned(
            bottom: widget.token != null ? 190 : 120,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: marron,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: IconButton(
                onPressed: () {
                  mapController?.animateCamera(CameraUpdate.zoomOut());
                },
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
            ),
          ),

          if (isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),

      // 📱 BARRE DE NAVIGATION
      bottomNavigationBar: widget.token != null
          ? BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: marron,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Réservations'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      )
          : null,
    );
  }
}