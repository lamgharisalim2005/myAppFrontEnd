import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../../services/websocket_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class ReservationsScreen extends StatefulWidget {
  final String token;
  final String role;


  const ReservationsScreen({
    super.key,
    required this.token,
    required this.role,
  });

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  static const Color marron = Color(0xFF795548);
  static const Color vert = Color(0xFF4CAF50);
  static const Color rouge = Color(0xFFE53935);
  static const Color orange = Color(0xFFFF9800);
  static const Color bleu = Color(0xFF2196F3);

  List<dynamic> reservations = [];

  List<dynamic> get enAttente => reservations.where((r) {
    final status = r['status'] as String;
    final endTime = DateTime.parse(r['endTime']);
    if (status == 'REJECTED') {
      return endTime.isAfter(DateTime.now());
    }
    return status == 'PENDING';
  }).toList();

  List<dynamic> get confirmees => reservations
      .where((r) => ['CONFIRMED', 'WAITING_PAYMENT'].contains(r['status']))
      .toList();

  List<dynamic> get historique => reservations.where((r) {
    final status = r['status'] as String;
    final endTime = DateTime.parse(r['endTime']);
    if (status == 'REJECTED') {
      return endTime.isBefore(DateTime.now());
    }
    return ['COMPLETED', 'CANCELLED'].contains(status);
  }).toList();
  bool isLoading = true;
  String? errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReservations();

    // Recharger automatiquement quand une nouvelle réservation arrive
    WebSocketService().notificationsStream.listen((data) {
      if (mounted) {
        _fetchReservations();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReservations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final endpoint = widget.role == 'CLIENT'
          ? '/api/reservations/client'
          : '/api/reservations/coiffeur';

      final response = await ApiService.get(
        'http://127.0.0.1:8080$endpoint',
        widget.token,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          reservations = data['data'] as List;
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

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED': return vert;
      case 'PENDING': return orange;
      case 'WAITING_PAYMENT': return bleu;
      case 'COMPLETED': return Colors.grey;
      case 'CANCELLED': return rouge;
      case 'REJECTED': return rouge;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'CONFIRMED': return 'Confirmée';
      case 'PENDING': return 'En attente';
      case 'WAITING_PAYMENT': return 'En attente de paiement';
      case 'COMPLETED': return 'Terminée';
      case 'CANCELLED': return 'Annulée';
      case 'REJECTED': return 'Refusée';
      default: return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'CONFIRMED': return Icons.check_circle;
      case 'PENDING': return Icons.hourglass_empty;
      case 'WAITING_PAYMENT': return Icons.payment;
      case 'COMPLETED': return Icons.done_all;
      case 'CANCELLED': return Icons.cancel;
      case 'REJECTED': return Icons.cancel;
      default: return Icons.info;
    }
  }

  String _formatDate(String isoDate) {
    final dt = DateTime.parse(isoDate);
    final months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _formatTime(String isoDate) {
    final dt = DateTime.parse(isoDate);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _annulerReservation(String id) async {
    try {
      final response = await ApiService.put(
        'http://127.0.0.1:8080/api/reservations/$id/cancel',
        widget.token,
      );

      if (response.statusCode == 200) {
        _fetchReservations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Réservation annulée'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur annulation: $e');
    }
  }

  Future<void> _traiterReservation(String id, String decision) async {
    try {
      final response = await ApiService.put(
        'http://127.0.0.1:8080/api/reservations/$id?decision=$decision',
        widget.token,
      );

      if (response.statusCode == 200) {
        _fetchReservations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decision == 'CONFIRMED'
                  ? '✅ Réservation confirmée'
                  : '❌ Réservation refusée'),
              backgroundColor: decision == 'CONFIRMED' ? vert : rouge,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur traitement: $e');
    }
  }

  Future<void> _supprimerReservation(String id) async {
    try {
      final response = await ApiService.delete(
        'http://127.0.0.1:8080/api/reservations/$id',
        widget.token,
      );

      if (response.statusCode == 200) {
        _fetchReservations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Réservation supprimée'),
              backgroundColor: marron,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur suppression: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        automaticallyImplyLeading: false,
        title: Text(
          widget.role == 'CLIENT' ? 'Mes Réservations' : 'Dashboard',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'En attente'),
            Tab(text: 'Confirmées'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : RefreshIndicator(
        color: marron,
        onRefresh: _fetchReservations,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildList(enAttente, isPassed: false),
            _buildList(confirmees, isPassed: false),
            _buildList(historique, isPassed: true),
          ],
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
            onPressed: _fetchReservations,
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

  Widget _buildList(List<dynamic> items, {required bool isPassed}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPassed ? Icons.history : Icons.calendar_today,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              isPassed
                  ? 'Aucune réservation dans l\'historique'
                  : 'Aucune réservation',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCard(items[index], isPassed: isPassed),
    );
  }

  Future<void> _payerReservation(dynamic reservation) async {
    try {
      // 1. Créer le PaymentIntent
      final response = await ApiService.post(
        'http://127.0.0.1:8080/api/payments/intent',
        widget.token,
        body: json.encode({
          'reservationId': reservation['id'],
          'currency': 'mad',
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201 && data['status'] == 'success') {
        final clientSecret = data['data']['clientSecret'];
        final paymentIntentId = data['data']['paymentIntentId'];

        // 2. Initialiser le payment sheet
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Sana Coiffure',
            style: ThemeMode.light,
          ),
        );

        // 3. Afficher le payment sheet
        await Stripe.instance.presentPaymentSheet();

        // 4. Confirmer le paiement côté backend
        await ApiService.put(
          'http://127.0.0.1:8080/api/payments/confirmer/$paymentIntentId',
          widget.token,
        );

        _fetchReservations();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Paiement effectué avec succès !'),
              backgroundColor: vert,
            ),
          );
        }
      }
    } on StripeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.error.localizedMessage ?? 'Paiement annulé'}'),
            backgroundColor: rouge,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur paiement: $e');
    }
  }

  Widget _buildCard(dynamic reservation, {required bool isPassed}) {
    final status = reservation['status'] as String;
    final isClient = widget.role == 'CLIENT';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(status), color: _statusColor(status), size: 18),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom client ou coiffeur
                Row(
                  children: [
                    const Icon(Icons.person, color: marron, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isClient
                          ? reservation['coiffeurName'] ?? ''
                          : reservation['clientName'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: marron,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Date et heure
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(reservation['startTime']),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatTime(reservation['startTime'])} - ${_formatTime(reservation['endTime'])}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Services
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.content_cut, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (reservation['serviceNames'] as List).join(', '),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Prix
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments, color: marron, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${reservation['totalPrice'].toStringAsFixed(0)} MAD',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: marron,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Boutons actions
                if (!isPassed) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildActions(reservation, status),
                ],

                if (isPassed && reservation['status'] != 'REJECTED') ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmerSuppression(reservation['id']),
                      icon: const Icon(Icons.delete_outline, color: rouge),
                      label: const Text('Supprimer', style: TextStyle(color: rouge)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: rouge),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(dynamic reservation, String status) {
    final isClient = widget.role == 'CLIENT';

    if (isClient && status == 'PENDING') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmerAnnulation(reservation['id']),
          icon: const Icon(Icons.cancel_outlined, color: rouge),
          label: const Text('Annuler', style: TextStyle(color: rouge)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: rouge),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (!isClient && status == 'PENDING') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _traiterReservation(reservation['id'], 'CONFIRMED'),
              icon: const Icon(Icons.check),
              label: const Text('Confirmer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: vert,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _traiterReservation(reservation['id'], 'REJECTED'),
              icon: const Icon(Icons.close, color: rouge),
              label: const Text('Refuser', style: TextStyle(color: rouge)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: rouge),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (isClient && status == 'WAITING_PAYMENT') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _payerReservation(reservation),
          icon: const Icon(Icons.payment),
          label: const Text('Payer maintenant'),
          style: ElevatedButton.styleFrom(
            backgroundColor: bleu,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _confirmerAnnulation(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette réservation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _annulerReservation(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: rouge, foregroundColor: Colors.white),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppression(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la réservation'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette réservation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerReservation(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: rouge, foregroundColor: Colors.white),
            child: const Text('Oui, supprimer'),
          ),
        ],
      ),
    );
  }
}