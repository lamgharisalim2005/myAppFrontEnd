import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String token;
  final String otherUserId;
  final String otherUserName;
  final String otherUserType;
  final String? otherProfilePicture;

  const ChatScreen({
    super.key,
    required this.token,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserType,
    this.otherProfilePicture,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}


class _ChatScreenState extends State<ChatScreen> {
  bool _isOtherOnline = false;
  static const Color marron = Color(0xFF795548);

  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _listenOnlineStatus() {
    // Vérifier le statut toutes les 30 secondes
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _checkOnlineStatus();
        _listenOnlineStatus();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _checkOnlineStatus();
    _listenOnlineStatus(); // ← Ajoute ça
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  Future<void> _checkOnlineStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.144/api/messages/online/${widget.otherUserId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isOtherOnline = data['data'] == true;
        });
      }
    } catch (e) {
      debugPrint('Erreur check online: $e');
    }
  }

  Future<void> _fetchMessages() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await http.get(
        Uri.parse(
          'http://192.168.0.144:8080/api/messages/conversation?otherUserId=${widget.otherUserId}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            messages = List<Map<String, dynamic>>.from(data['data']);
            isLoading = false;
          });
          _scrollToBottom();
          // Marquer tous les messages non lus comme lus
          _markAllAsRead();
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

  Future<void> _markAsRead(String messageId) async {
    try {
      await http.put(
        Uri.parse('http://192.168.0.144:8080/api/messages/$messageId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );
    } catch (e) {
      debugPrint('Erreur mark as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    for (var message in messages) {
      if (message['isMe'] == false && message['status'] != 'READ') {
        await _markAsRead(message['id']);
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => isSending = true);
    _messageController.clear();

    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.144:8080/api/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'receiverId': widget.otherUserId,
          'content': content,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            messages.add(data['data']);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Impossible d\'envoyer le message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => isSending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String createdAt) {
    final date = DateTime.parse(createdAt);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(String createdAt) {
    final date = DateTime.parse(createdAt);
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month) return 'Aujourd\'hui';
    if (date.day == now.day - 1) return 'Hier';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: marron,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: widget.otherProfilePicture != null
                  ? NetworkImage(widget.otherProfilePicture!)
                  : null,
              child: widget.otherProfilePicture == null
                  ? Icon(
                widget.otherUserType == 'COIFFEUR'
                    ? Icons.content_cut
                    : Icons.person,
                color: Colors.white,
                size: 18,
              )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.otherUserType == 'COIFFEUR' ? 'Coiffeur' : 'Client',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: marron))
          : errorMessage != null
          ? _buildError()
          : _buildChat(),
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
            onPressed: _fetchMessages,
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

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 60,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Commencez la conversation !',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isMe = message['isMe'] == true;

              final showDate = index == 0 ||
                  _formatDate(messages[index - 1]['createdAt']) !=
                      _formatDate(message['createdAt']);

              return Column(
                children: [
                  if (showDate)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDate(message['createdAt']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  _buildMessageBubble(message, isMe),
                ],
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: marron.withOpacity(0.1),
              backgroundImage: widget.otherProfilePicture != null
                  ? NetworkImage(widget.otherProfilePicture!)
                  : null,
              child: widget.otherProfilePicture == null
                  ? Icon(
                widget.otherUserType == 'COIFFEUR'
                    ? Icons.content_cut
                    : Icons.person,
                color: marron,
                size: 16,
              )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? marron : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message['createdAt']),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      // Statut message (seulement pour mes messages)
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message['status'] == 'READ'
                              ? Icons.done_all
                              : message['status'] == 'DELIVERED'
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: message['status'] == 'READ'
                              ? Colors.blue
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: marron,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}