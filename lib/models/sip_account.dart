import 'audio_codec.dart';

/// Exception thrown when SipAccount validation fails.
class SipAccountValidationException implements Exception {
  final String message;
  const SipAccountValidationException(this.message);

  @override
  String toString() => 'SipAccountValidationException: $message';
}

/// Configuration model for a SIP account.
///
/// This class encapsulates all the settings needed to register with a SIP server,
/// including user credentials, server addresses, and media settings.
///
/// All parameters are validated on construction. Port numbers must be in the
/// valid range (1-65535), and server addresses must be valid hostnames or IPs.
///
/// Example:
/// ```dart
/// // Minimal configuration (without STUN)
/// final account = SipAccount(
///   userName: 'user123',
///   password: 'secretPassword',
///   sipServer: 'sip.example.com',
///   sipServerPort: 5060,
/// );
///
/// // With STUN server for NAT traversal
/// final accountWithStun = SipAccount(
///   userName: 'user123',
///   password: 'secretPassword',
///   sipServer: 'sip.example.com',
///   sipServerPort: 5060,
///   stunServer: 'stun.example.com',
///   stunServerPort: 3478,
/// );
/// ```
class SipAccount {
  /// Default recommended audio codecs in preference order.
  /// OPUS for quality, PCMU/PCMA for compatibility.
  static const List<AudioCodec> defaultAudioCodecs = [
    AudioCodec.opus,
    AudioCodec.pcmu,
    AudioCodec.pcma,
  ];

  /// Minimum valid port number.
  static const int minPort = 1;

  /// Maximum valid port number.
  static const int maxPort = 65535;

  // Regular expression for validating hostname format.
  static final RegExp _hostnameRegex = RegExp(
    r'^(?=.{1,253}$)(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z0-9-]{1,63})*\.?$',
  );

  // Regular expression for validating IPv4 address format.
  static final RegExp _ipv4Regex = RegExp(
    r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
  );

  // Regular expression for validating IPv6 address format.
  // Supports full form, compressed form (::), and all valid abbreviations.
  static final RegExp _ipv6Regex = RegExp(
    r'^('
    // Full form: 8 groups of 4 hex digits
    r'(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|'
    // :: at start with up to 7 groups after (e.g., ::1, ::ffff:192.0.2.1)
    r'::(?:[0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{1,4}|'
    // :: alone (all zeros)
    r'::|'
    // Groups before :: with nothing after (e.g., fe80::)
    r'(?:[0-9a-fA-F]{1,4}:){1,7}:|'
    // Groups on both sides of :: (e.g., fe80::1, 2001:db8::8a2e:370:7334)
    r'(?:[0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|'
    r'(?:[0-9a-fA-F]{1,4}:){1,5}(?::[0-9a-fA-F]{1,4}){1,2}|'
    r'(?:[0-9a-fA-F]{1,4}:){1,4}(?::[0-9a-fA-F]{1,4}){1,3}|'
    r'(?:[0-9a-fA-F]{1,4}:){1,3}(?::[0-9a-fA-F]{1,4}){1,4}|'
    r'(?:[0-9a-fA-F]{1,4}:){1,2}(?::[0-9a-fA-F]{1,4}){1,5}|'
    r'[0-9a-fA-F]{1,4}:(?::[0-9a-fA-F]{1,4}){1,6}'
    r')$',
  );
  /// The SIP username (extension number or account name)
  final String userName;

  /// The SIP password for authentication
  final String password;

  /// The SIP server address (hostname or IP)
  final String sipServer;

  /// The SIP server port (default: 5060)
  final int sipServerPort;

  /// Display name shown to call recipients
  final String displayName;

  /// Authentication name (if different from userName)
  final String authName;

  /// The user's SIP domain
  final String userDomain;

  /// STUN server address for NAT traversal (optional)
  final String stunServer;

  /// STUN server port (default: 3478, ignored if stunServer is empty)
  final int stunServerPort;

  /// Outbound proxy server address
  final String outboundServer;

  /// Outbound proxy server port
  final int outboundServerPort;

  /// PortSIP license key
  final String licenseKey;

  /// Registration timeout in seconds
  final int registerTimeout;

  /// Number of registration retry attempts on failure
  final int registerRetryTimes;

  /// Video bitrate in kbps for video calls
  final int videoBitrate;

  /// Video frame rate (frames per second)
  final int videoFrameRate;

  /// Video width in pixels
  final int videoWidth;

  /// Video height in pixels
  final int videoHeight;

  /// List of audio codecs to use, in preference order
  final List<AudioCodec> audioCodecs;

  /// Creates a new SipAccount configuration.
  ///
  /// Required parameters:
  /// - [userName]: The SIP username
  /// - [password]: The SIP password
  /// - [sipServer]: The SIP server address
  /// - [sipServerPort]: The SIP server port (1-65535)
  ///
  /// Optional parameters have sensible defaults for most use cases.
  /// [stunServer] and [stunServerPort] are optional - STUN is not required
  /// for all deployments (e.g., when behind a SIP-aware firewall or using
  /// a SIP ALG).
  /// If [audioCodecs] is not provided or empty, [defaultAudioCodecs] will be used.
  ///
  /// Throws [SipAccountValidationException] if validation fails.
  SipAccount({
    required this.userName,
    required this.password,
    required this.sipServer,
    required int sipServerPort,
    this.stunServer = '',
    int stunServerPort = 3478,
    String outboundServer = '',
    int outboundServerPort = 0,
    this.displayName = '',
    this.authName = '',
    this.userDomain = '',
    this.licenseKey = '',
    this.registerTimeout = 120,
    this.registerRetryTimes = 3,
    this.videoBitrate = 500,
    this.videoFrameRate = 10,
    this.videoWidth = 352,
    this.videoHeight = 288,
    List<AudioCodec>? audioCodecs,
  })  : sipServerPort = sipServerPort,
        stunServerPort = stunServerPort,
        outboundServer = outboundServer,
        outboundServerPort = outboundServerPort,
        audioCodecs = (audioCodecs == null || audioCodecs.isEmpty)
            ? defaultAudioCodecs
            : audioCodecs {
    _validate();
  }

  /// Validates all fields and throws [SipAccountValidationException] if invalid.
  void _validate() {
    // Validate required fields are not empty
    if (userName.trim().isEmpty) {
      throw const SipAccountValidationException('userName cannot be empty');
    }
    if (password.isEmpty) {
      throw const SipAccountValidationException('password cannot be empty');
    }
    if (sipServer.trim().isEmpty) {
      throw const SipAccountValidationException('sipServer cannot be empty');
    }

    // Validate server addresses
    if (!_isValidHostOrIp(sipServer)) {
      throw SipAccountValidationException(
        'sipServer "$sipServer" is not a valid hostname or IP address',
      );
    }
    // stunServer is optional - only validate if provided
    if (stunServer.isNotEmpty && !_isValidHostOrIp(stunServer)) {
      throw SipAccountValidationException(
        'stunServer "$stunServer" is not a valid hostname or IP address',
      );
    }
    if (outboundServer.isNotEmpty && !_isValidHostOrIp(outboundServer)) {
      throw SipAccountValidationException(
        'outboundServer "$outboundServer" is not a valid hostname or IP address',
      );
    }

    // Validate port ranges
    _validatePort(sipServerPort, 'sipServerPort');
    // Only validate stunServerPort if stunServer is provided
    if (stunServer.isNotEmpty) {
      _validatePort(stunServerPort, 'stunServerPort');
    }
    if (outboundServerPort != 0) {
      _validatePort(outboundServerPort, 'outboundServerPort');
    }
  }

  /// Validates that a port number is within the valid range (1-65535).
  void _validatePort(int port, String fieldName) {
    if (port < minPort || port > maxPort) {
      throw SipAccountValidationException(
        '$fieldName must be between $minPort and $maxPort, got $port',
      );
    }
  }

  /// Checks if the given string is a valid hostname or IP address.
  static bool _isValidHostOrIp(String value) {
    final trimmed = value.trim();
    return _hostnameRegex.hasMatch(trimmed) ||
        _ipv4Regex.hasMatch(trimmed) ||
        _ipv6Regex.hasMatch(trimmed);
  }

  /// Converts this account configuration to a Map for method channel communication.
  ///
  /// Returns a Map containing all account settings that can be passed
  /// to the native platform via MethodChannel.
  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'password': password,
      'sipServer': sipServer,
      'sipServerPort': sipServerPort,
      'stunServer': stunServer,
      'stunServerPort': stunServerPort,
      'outboundServer': outboundServer,
      'outboundServerPort': outboundServerPort,
      'displayName': displayName,
      'authName': authName,
      'userDomain': userDomain,
      'licenseKey': licenseKey,
      'registerTimeout': registerTimeout,
      'registerRetryTimes': registerRetryTimes,
      'videoBitrate': videoBitrate,
      'videoFrameRate': videoFrameRate,
      'videoWidth': videoWidth,
      'videoHeight': videoHeight,
      'audioCodecs': audioCodecs.map((e) => e.value).toList(),
    };
  }
}
