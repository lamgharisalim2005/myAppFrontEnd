import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../models/salon.dart';
import '../public/salon_detail_screen.dart';
import '../public/profile_screen.dart';
import '../client/reservations_screen.dart';
import 'notifications_screen.dart';
import 'conversations_screen.dart';
import '../../services/websocket_service.dart';
import '../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final String? token;
  final String? role;
  final String? userId;

  const HomeScreen({
    super.key,
    this.token,
    this.role,
    this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _newSalonsCount = 0;
  bool _isAdmin = false;

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
    _fetchUnreadCount();
    _fetchUnreadMessagesCount();
    _fetchIsAdmin();

    WebSocketService().notificationsStream.listen((data) {
      if (mounted) {
        _fetchUnreadCount();
      }
    });

    WebSocketService().salonsStream.listen((event) {
      if (mounted) {
        setState(() {
          _newSalonsCount++;
        });
        fetchSalons();
      }
    });

    WebSocketService().unreadMessagesStream.listen((count) {
      if (mounted) {
        setState(() {});
      }
    });

    WebSocketService().unreadNotificationsStream.listen((count) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _fetchIsAdmin() async {
    if (widget.role != 'COIFFEUR') return;
    try {
      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/coiffeurs/profile',
        widget.token ?? '',
      );
      final data = json.decode(response.body);
      debugPrint('🔍 Profile data: ${data['data']}');
      if (data['status'] == 'success') {
        setState(() {
          _isAdmin = data['data']['isAdmin'] as bool;
        });
        debugPrint('🔍 isAdmin: $_isAdmin');
      }
    } catch (e) {
      debugPrint('Erreur fetch isAdmin: $e');
    }
  }

  Future<void> _fetchUnreadMessagesCount() async {
    try {
      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/messages/conversations',
        widget.token ?? '',
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        final list = data['data'] as List;
        final totalUnread = list.fold<int>(
            0, (sum, c) => sum + (c['unreadCount'] as int? ?? 0));
        WebSocketService().updateUnreadMessagesCount(totalUnread);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Erreur unread messages: $e');
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/notifications/user',
        widget.token ?? '',
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        final count = (data['data'] as List)
            .where((n) => n['readStatus'] == false)
            .length;
        WebSocketService().updateUnreadNotificationsCount(count);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Erreur: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
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
    if (userPosition == null) return;
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(userPosition!.latitude, userPosition!.longitude),
        16,
      ),
    );
  }

  Future<void> fetchSalons() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/salons',
        widget.token ?? '',
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final List listeSalons = data['data'];
        salons = listeSalons.map((s) => Salon.fromJson(s)).toList();
        await _createMarkers();
      }
    } catch (e) {
      debugPrint('Erreur fetchSalons: $e');
    }
    setState(() => isLoading = false);
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
      final response = await ApiService.get(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${userPosition!.longitude},${userPosition!.latitude}&end=${selectedSalon!.longitude},${selectedSalon!.latitude}',
        '',
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

  Widget _buildMapScreen() {
    return Stack(
      children: [
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

        Positioned(
          top: 50,
          right: 16,
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildMapButton(Icons.my_location, _goToUserLocation),
              const SizedBox(height: 8),
              _buildMapButton(
                Icons.directions,
                selectedSalon != null ? _showRoute : null,
              ),
              const SizedBox(height: 8),
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

        if (selectedSalon != null)
          Positioned(
            bottom: 16,
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
                    onPressed: () async {
                      await _fetchIsAdmin();
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SalonDetailScreen(
                              salonId: selectedSalon!.id,
                              salonName: selectedSalon!.name,
                              token: widget.token,
                              role: widget.role,
                              userId: widget.userId,
                              isAdmin: _isAdmin,
                            ),
                          ),
                        );
                      }
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

        Positioned(
          bottom: 250,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: marron,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
            child: IconButton(
              onPressed: () => mapController?.animateCamera(CameraUpdate.zoomIn()),
              icon: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),

        Positioned(
          bottom: 190,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: marron,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
            child: IconButton(
              onPressed: () => mapController?.animateCamera(CameraUpdate.zoomOut()),
              icon: const Icon(Icons.remove, color: Colors.white),
            ),
          ),
        ),

        if (isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildMapScreen(),
            ReservationsScreen(
              token: widget.token ?? '',
              role: widget.role ?? '',
            ),
            ConversationsScreen(
              token: widget.token ?? '',
              userId: widget.userId ?? '',
              role: widget.role,
            ),
            NotificationsScreen(
              token: widget.token ?? '',
            ),
            ProfileScreen(
              token: widget.token ?? '',
              role: widget.role ?? '',
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: marron,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (index == 0) {
                _newSalonsCount = 0;
                fetchSalons();
              }
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.home),
                  if (_newSalonsCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_newSalonsCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Accueil',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Réservations',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.message),
                  if (WebSocketService().unreadMessagesCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${WebSocketService().unreadMessagesCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications),
                  if (WebSocketService().unreadNotificationsCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${WebSocketService().unreadNotificationsCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Notifications',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}