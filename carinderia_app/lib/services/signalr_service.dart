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
        .withAutomaticReconnect()
        .build();

    // CRITICAL: Register the listener BEFORE starting the connection handshake
    _hubConnection!.on('ReceiveOrderUpdate', (arguments) {
      print("SignalR raw event 'ReceiveOrderUpdate' triggered!");
      onOrderUpdate(arguments);
    });

    try {
      await _hubConnection!.start();
      _isConnected = true;
      print(
        "SignalR Connected Successfully. ConnectionId: ${_hubConnection?.connectionId}",
      );

      // Automatically join the kitchen group right after connection starts
      await joinKitchen();
    } catch (e) {
      print("SignalR Connection Error: $e");
    }
  }

  Future<void> joinKitchen() async {
    if (_isConnected && _hubConnection != null) {
      try {
        await _hubConnection!.invoke('JoinKitchen');
        print("Successfully invoked JoinKitchen on hub.");
      } catch (e) {
        print("Error invoking JoinKitchen: $e");
      }
    }
  }

  Future<void> joinTable(int tableNumber) async {
    if (_isConnected && _hubConnection != null) {
      try {
        await _hubConnection!.invoke('JoinTable', args: [tableNumber]);
        print("Successfully invoked JoinTable for Table $tableNumber.");
      } catch (e) {
        print("Error invoking JoinTable: $e");
      }
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _isConnected = false;
    }
  }
}
