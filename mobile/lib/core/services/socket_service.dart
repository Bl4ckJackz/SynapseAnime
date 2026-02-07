import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  IO.Socket? _socket;
  final _storage = const FlutterSecureStorage();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token == null) return; // Cannot connect without auth

    // Connect to specific namespace if needed, or root
    // Our backend gateway uses namespace 'history'
    // URL format: http://host:port/history
    final uri = '${AppConstants.apiBaseUrl}/history';

    _socket = IO.io(
        uri,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // Try both
            .enableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .setQuery({
              'token': token
            }) // For NestJS, usually passed in query or auth object
            .build());

    _socket!.onConnect((_) {
      print('SOCKET: Connected to ${AppConstants.apiBaseUrl}');
    });

    _socket!.onDisconnect((_) {
      print('SOCKET: Disconnected');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, (data) {
      print('SOCKET: Received event: $event with data: $data');
      callback(data);
    });
  }

  void off(String event) {
    _socket?.off(event);
  }
}
