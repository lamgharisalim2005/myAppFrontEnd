import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'dart:async';
import 'dart:convert';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _stompClient;

  // Stream messages
  final StreamController<Map<String, dynamic>> _messagesController =
  StreamController.broadcast();
  Stream<Map<String, dynamic>> get messagesStream => _messagesController.stream;

  // Stream notifications
  final StreamController<Map<String, dynamic>> _notificationsController =
  StreamController.broadcast();
  Stream<Map<String, dynamic>> get notificationsStream =>
      _notificationsController.stream;

  // Stream unread messages count
  final StreamController<int> _unreadMessagesController =
  StreamController.broadcast();
  Stream<int> get unreadMessagesStream => _unreadMessagesController.stream;

  int _unreadMessagesCount = 0;
  int get unreadMessagesCount => _unreadMessagesCount;

  void updateUnreadMessagesCount(int count) {
    _unreadMessagesCount = count;
    _unreadMessagesController.add(count);
  }

  bool _isConnected = false;
  bool get isConnected => _isConnected;
// Stream unread notifications count
  final StreamController<int> _unreadNotificationsController =
  StreamController.broadcast();
  Stream<int> get unreadNotificationsStream => _unreadNotificationsController.stream;

  int _unreadNotificationsCount = 0;
  int get unreadNotificationsCount => _unreadNotificationsCount;

  // Stream online status
  final StreamController<Map<String, dynamic>> _onlineStatusController =
  StreamController.broadcast();
  Stream<Map<String, dynamic>> get onlineStatusStream => _onlineStatusController.stream;

  // Stream nouveaux salons
  final StreamController<String> _salonsController =
  StreamController.broadcast();
  Stream<String> get salonsStream => _salonsController.stream;

  void updateUnreadNotificationsCount(int count) {
    _unreadNotificationsCount = count;
    _unreadNotificationsController.add(count);
  }

  void connect(String token, String userId) {
    if (_isConnected) return;

    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://127.0.0.1:8080/ws/websocket',
        onConnect: (frame) {
          _isConnected = true;
          debugPrint('✅ WebSocket Global connecté !');

          _stompClient!.subscribe(
            destination: '/queue/messages/$userId',
            callback: (frame) {
              if (frame.body != null) {
                final data = json.decode(frame.body!);
                _messagesController.add(data);
                // Incrémenter le count automatiquement
                updateUnreadMessagesCount(_unreadMessagesCount + 1);
              }
            },
          );
          // Ecouter le statut en ligne des contacts
          _stompClient!.subscribe(
            destination: '/topic/online',
            callback: (frame) {
              if (frame.body != null) {
                final data = json.decode(frame.body!);
                _onlineStatusController.add(data);
              }
            },
          );
          _stompClient!.subscribe(
            destination: '/queue/notifications/$userId',
            callback: (frame) {
              if (frame.body != null) {
                final data = json.decode(frame.body!);
                _notificationsController.add(data);
                // Incrémenter le count
                updateUnreadNotificationsCount(_unreadNotificationsCount + 1);
              }
            },
          );
          // Ecouter les changements de salons
          _stompClient!.subscribe(
            destination: '/topic/salons',
            callback: (frame) {
              if (frame.body != null) {
                _salonsController.add(frame.body!);
              }
            },
          );
        },

        onDisconnect: (_) {
          _isConnected = false;
          debugPrint('❌ WebSocket Global déconnecté !');
        },
        onWebSocketError: (error) {
          _isConnected = false;
          debugPrint('❌ WebSocket erreur: $error');
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    _stompClient!.activate();

  }

  void disconnect() {
    _stompClient?.deactivate();
    _isConnected = false;
    _unreadMessagesCount = 0;
    debugPrint('🔌 WebSocket Global déconnecté manuellement');
  }
}