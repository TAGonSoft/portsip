/// SIP transport protocol types supported by PortSIP SDK.
///
/// Defines the underlying transport protocol used for SIP signaling.
/// The choice of transport affects NAT traversal, firewall compatibility,
/// and connection reliability.
enum TransportType {
  /// Undefined transport (used as default/error state)
  none(-1),

  /// UDP transport - connectionless, lightweight, may have NAT issues
  udp(0),

  /// TLS transport - encrypted, secure, reliable (recommended for production)
  tls(1),

  /// TCP transport - connection-oriented, reliable, good NAT traversal
  tcp(2);

  /// The integer value passed to the native SDK
  final int value;
  const TransportType(this.value);

  /// Creates a TransportType from its integer value.
  ///
  /// Returns [TransportType.none] if the value doesn't match any known type.
  static TransportType fromValue(int value) {
    return TransportType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransportType.none,
    );
  }
}

/// Logging levels for the PortSIP SDK.
///
/// Controls the verbosity of SDK logging output. Higher levels
/// include all messages from lower levels.
enum PortsipLogLevel {
  /// Logging disabled
  none(-1),

  /// Error messages only - critical failures
  error(1),

  /// Warnings and errors - potential issues
  warning(2),

  /// Informational messages, warnings, and errors
  info(3),

  /// Debug-level logging - verbose output for development
  debug(4);

  /// The integer value passed to the native SDK
  final int value;
  const PortsipLogLevel(this.value);

  /// Creates a PortsipLogLevel from its integer value.
  ///
  /// Returns [PortsipLogLevel.none] if the value doesn't match any known level.
  static PortsipLogLevel fromValue(int value) {
    return PortsipLogLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PortsipLogLevel.none,
    );
  }
}
