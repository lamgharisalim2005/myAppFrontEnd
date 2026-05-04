import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import 'chat_screen.dart';
import '../../services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConversationsScreen extends StatefulWidget {
  final String token;
  final String userId;
  final VoidCallback? onNotificationReceived; // ← ajouter
  final String? role; // ← ajouter

  const ConversationsScreen({
    super.key,
    required this.token,
    required this.userId,
    this.role, // ← ajouter
    this.onNotificationReceived, // ← ajouter
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  static const Color marron = Color(0xFF795548);

  List<Map<String, dynamic>> conversations = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, bool> onlineStatuses = {};
  bool _selectionMode = false;
  Set<String> _selectedConversations = {};



  @override
  void initState() {
    super.initState();
    _fetchConversations();

    // Ecouter le statut en ligne en temps réel
    WebSocketService().onlineStatusStream.listen((data) {
      if (mounted) {
        setState(() {
          onlineStatuses[data['userId'].toString()] = data['online'] == true;
        });
      }
    });

    // Ecouter les nouveaux messages
    WebSocketService().messagesStream.listen((data) {
      if (mounted) {
        // Si nouveau message → retirer la conversation des supprimées
        _retirerConversationSupprimee(data['senderId']);
        _fetchConversations();
      }
    });

    WebSocketService().notificationsStream.listen((data) {
      if (mounted) {
        // Notifier home_screen de mettre à jour le badge
        widget.onNotificationReceived?.call();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _retirerConversationSupprimee(String senderId) async {
    final prefs = await SharedPreferences.getInstance();

    // Retirer la conversation des supprimées
    final deletedConversations = prefs.getStringList(
        'deleted_conversations_${widget.token}') ?? [];
    if (deletedConversations.contains(senderId)) {
      deletedConversations.remove(senderId);
      await prefs.setStringList(
          'deleted_conversations_${widget.token}', deletedConversations);
    }

    // Retirer aussi le filtre des messages de cette conversation
    final deletedMessages = prefs.getStringList(
        'deleted_messages_${widget.token}') ?? [];
    if (deletedMessages.contains('conv_$senderId')) {
      deletedMessages.remove('conv_$senderId');
      await prefs.setStringList(
          'deleted_messages_${widget.token}', deletedMessages);
    }
  }

  Future<void> _fetchOnlineStatuses() async {
    for (var conversation in conversations) {
      try {
        final response = await ApiService.get(
          'http://127.0.0.1:8080/api/messages/online/${conversation['userId']}',
          widget.token,
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() {
              onlineStatuses[conversation['userId']] = data['data'] == true;
            });
          }
        }
      } catch (e) {
        debugPrint('Erreur online status: $e');
      }
    }
  }

  Future<void> _supprimerConversationsSelectionnees() async {
    final prefs = await SharedPreferences.getInstance();

    // Supprimer les conversations
    final deletedConversations = prefs.getStringList('deleted_conversations_${widget.token}') ?? [];
    deletedConversations.addAll(_selectedConversations);
    await prefs.setStringList('deleted_conversations_${widget.token}', deletedConversations);

    // Supprimer aussi tous les messages de ces conversations
    final deletedMessages = prefs.getStringList('deleted_messages_${widget.token}') ?? [];
    for (var userId in _selectedConversations) {
      // Trouver tous les messages de cette conversation
      final conversation = conversations.firstWhere(
            (c) => c['userId'] == userId,
        orElse: () => {},
      );
      if (conversation.isNotEmpty) {
        // Ajouter l'ID de conversation dans les messages supprimés
        // pour filtrer lors du chargement
        deletedMessages.add('conv_$userId');
      }
    }
    await prefs.setStringList('deleted_messages_${widget.token}', deletedMessages);

    setState(() {
      conversations.removeWhere((c) => _selectedConversations.contains(c['userId']));
      _selectedConversations.clear();
      _selectionMode = false;
    });
  }

  Future<List<String>> _getDeletedConversations() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('deleted_conversations_${widget.token}') ?? [];
  }

  Future<void> _ouvrirChat(Map<String, dynamic> conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          token: widget.token,
          otherUserId: conversation['userId'],
          otherUserName: conversation['name'],
          otherUserType: conversation['userType'],
          otherProfilePicture: conversation['profilePicture'],
          userId: widget.userId, // ← ajouter
          role: widget.role,     // ← ajouter
        ),
      ),
    );
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await ApiService.get(
        'http://127.0.0.1:8080/api/messages/conversations',
        widget.token,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final list = List<Map<String, dynamic>>.from(data['data']);

          final totalUnread = list.fold<int>(
              0, (sum, c) => sum + (c['unreadCount'] as int? ?? 0));
          WebSocketService().updateUnreadMessagesCount(totalUnread);

          final deletedConversations = await _getDeletedConversations();
          setState(() {
            conversations = list
                .where((c) => !deletedConversations.contains(c['userId']))
                .toList();
            isLoading = false;
          });
          _fetchOnlineStatuses();
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

  String _getTimeAgo(String? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final date = DateTime.parse(time);
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _selectionMode
          ? AppBar(
        backgroundColor: marron,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            setState(() {
              _selectionMode = false;
              _selectedConversations.clear();
            });
          },
        ),
        title: Text(
          '${_selectedConversations.length} sélectionné(s)',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () => _supprimerConversationsSelectionnees(),
          ),
        ],
      )
          : AppBar(
        backgroundColor: marron,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Messages',
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
          : conversations.isEmpty
          ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(errorMessage!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchConversations,
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucune conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vos conversations apparaîtront ici',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: marron,
      onRefresh: _fetchConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          return _buildConversationCard(conversations[index]);
        },
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final isCoiffeur = conversation['userType'] == 'COIFFEUR';
    final unreadCount = conversation['unreadCount'] as int? ?? 0;
    final isSelected = _selectedConversations.contains(conversation['userId']);

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _selectionMode = true;
          _selectedConversations.add(conversation['userId']);
        });
      },
      onTap: () {
        if (_selectionMode) {
          setState(() {
            if (isSelected) {
              _selectedConversations.remove(conversation['userId']);
              if (_selectedConversations.isEmpty) _selectionMode = false;
            } else {
              _selectedConversations.add(conversation['userId']);
            }
          });
        } else {
          _ouvrirChat(conversation);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? marron.withOpacity(0.2)
              : unreadCount > 0
              ? marron.withOpacity(0.03)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? marron
                : unreadCount > 0
                ? marron.withOpacity(0.2)
                : Colors.transparent,
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
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: marron.withOpacity(0.1),
                  backgroundImage: conversation['profilePicture'] != null
                      ? NetworkImage(conversation['profilePicture'])
                      : null,
                  child: conversation['profilePicture'] == null
                      ? Icon(
                    isCoiffeur ? Icons.content_cut : Icons.person,
                    color: marron,
                    size: 28,
                  )
                      : null,
                ),
                // Point statut en ligne
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: (onlineStatuses[conversation['userId']] == true)
                          ? Colors.green
                          : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          conversation['name'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _getTimeAgo(conversation['lastMessageTime']),
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? marron
                              : Colors.grey.shade400,
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: marron.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCoiffeur ? 'Coiffeur' : 'Client',
                          style: const TextStyle(
                            fontSize: 10,
                            color: marron,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          conversation['lastMessage'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: unreadCount > 0
                                ? Colors.black87
                                : Colors.grey.shade600,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Badge messages non lus ou icône sélection
            if (isSelected)
              const Icon(Icons.check_circle, color: marron, size: 24)
            else if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}