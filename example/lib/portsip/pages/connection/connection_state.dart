enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionState {
  final bool isOnline;
  final ConnectionStatus status;

  ConnectionState({
    this.isOnline = false,
    this.status = ConnectionStatus.disconnected,
  });

  ConnectionState copyWith({bool? isOnline, ConnectionStatus? status}) {
    return ConnectionState(
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
    );
  }
}
