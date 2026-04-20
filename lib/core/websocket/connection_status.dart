/// Represents the current state of the WebSocket connection.
///
/// Used by [WebSocketService] to broadcast connection lifecycle changes
/// via its `connectionStatus` stream.
enum ConnectionStatus {
  /// The WebSocket is fully connected and receiving events.
  connected,

  /// The WebSocket is in the process of establishing a connection.
  connecting,

  /// The WebSocket is not connected and no reconnection is in progress.
  disconnected,

  /// The WebSocket lost its connection and is attempting to reconnect
  /// using the exponential-backoff strategy.
  reconnecting,
}
