import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  HubConnection? _hubConnection;
  bool _isConnected = false;

  Future<void> connect(
    String baseUrl, {
    required Function(List<Object?>?) onOrderUpdate,
  }) async {
    if (_isConnected && _hubConnection != null) return;

    _hubConnection = HubConnectionBuilder()
        .withUrl('$baseUrl/orderHub')
        .build();

    _hubConnection!.on('ReceiveOrderUpdate', (arguments) {
      debugPrint("SignalR raw event 'ReceiveOrderUpdate' triggered!");
      onOrderUpdate(arguments);
    });

    try {
      await _hubConnection!.start();
      _isConnected = true;

      debugPrint(
        "[SignalR] Connected. ConnectionId: ${_hubConnection?.connectionId}",
      );
    } catch (e) {
      debugPrint("SignalR Connection Error: $e");
    }
  }

  Future<void> joinKitchen() async {
    if (_isConnected && _hubConnection != null) {
      try {
        await _hubConnection!.invoke('JoinKitchen');
        debugPrint("Successfully invoked JoinKitchen on hub.");
      } catch (e) {
        debugPrint("Error invoking JoinKitchen: $e");
      }
    }
  }

  Future<void> joinTable(int tableNumber) async {
    if (_isConnected && _hubConnection != null) {
      try {
        await _hubConnection!.invoke('JoinTable', args: [tableNumber]);
        debugPrint("Successfully invoked JoinTable for Table $tableNumber.");
      } catch (e) {
        debugPrint("Error invoking JoinTable: $e");
      }
    }
  }

  Future<void> disconnect() async {
    final connection = _hubConnection;

    _hubConnection = null;
    _isConnected = false;

    if (connection != null) {
      try {
        await connection.stop();
        debugPrint('[SignalR] Disconnected.');
      } catch (e) {
        debugPrint('[SignalR] Disconnect error: $e');
      }
    }
  }
}
