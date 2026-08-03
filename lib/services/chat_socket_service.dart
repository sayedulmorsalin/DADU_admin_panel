import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../constants/constants.dart';

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  ChatSocketService._internal();

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isTyping = ValueNotifier<bool>(false);
  
  Timer? _reconnectTimer;
  String? _currentUserId;

  void connect(String userId) {
    if (_currentUserId == userId && isConnected.value) return;
    _currentUserId = userId;
    
    _disconnect();
    _establishConnection();
  }

  Future<void> _establishConnection() async {
    if (_currentUserId == null) return;

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String? token = await user.getIdToken();
      if (token == null) return;

      // Convert https to wss and http to ws
      String wsUrl = apiBaseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      
      final uri = Uri.parse('$wsUrl/ws/$_currentUserId');

      debugPrint('Connecting to WebSocket: $uri');

      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
        pingInterval: const Duration(seconds: 20),
      );
      
      isConnected.value = true;
      _listen();
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      isConnected.value = false;
      _scheduleReconnect();
    }
  }

  void _listen() {
    _channel?.stream.listen(
      (data) {
        try {
          final Map<String, dynamic> event = jsonDecode(data);
          
          if (event['type'] == 'new_message') {
            _messageController.add(event);
          } else if (event['type'] == 'typing') {
            // In admin panel, we want to know if the USER is typing
            if (event['senderRole'] == 'user') {
              isTyping.value = true;
            }
          } else if (event['type'] == 'stop_typing') {
            if (event['senderRole'] == 'user') {
              isTyping.value = false;
            }
          } else if (event['type'] == 'error') {
            debugPrint('WebSocket error event: ${event['error']}');
          }
        } catch (e) {
          debugPrint('WebSocket decode error: $e');
        }
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
        isConnected.value = false;
        _scheduleReconnect();
      },
      onError: (error) {
        debugPrint('WebSocket stream error: $error');
        isConnected.value = false;
        _scheduleReconnect();
      },
    );
  }

  void sendMessage(String message, {String? imageUrl}) {
    if (_channel == null || !isConnected.value) {
      debugPrint('Cannot send message: WebSocket not connected');
      return;
    }

    final data = {
      'type': 'message',
      'message': message,
      'imageUrl': imageUrl,
    };

    _channel?.sink.add(jsonEncode(data));
  }

  void sendTyping() {
    if (_channel != null && isConnected.value) {
      _channel?.sink.add(jsonEncode({'type': 'typing'}));
    }
  }

  void sendStopTyping() {
    if (_channel != null && isConnected.value) {
      _channel?.sink.add(jsonEncode({'type': 'stop_typing'}));
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentUserId != null && !isConnected.value) {
        _establishConnection();
      }
    });
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close(1001); // 1001 is goingAway
    isConnected.value = false;
    isTyping.value = false;
  }

  void dispose() {
    _disconnect();
    _messageController.close();
  }
}
