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

/// Container format for a call recording.
///
/// Audio formats apply to `startRecord`'s `fileFormat`; [mp4] is the video
/// container and only makes sense with a video record mode.
enum PortsipRecordFileFormat {
  /// Not recorded.
  none(0),

  /// WAVE — uncompressed PCM. The safest default: no codec dependency.
  wave(1),

  /// AMR — compressed with the AMR codec, mono only.
  amr(2),

  /// MP3 — compressed, smaller files than WAVE.
  mp3(3),

  /// MP4 (AAC + H264) — the video container.
  mp4(4);

  /// The integer value passed to the native SDK
  final int value;
  const PortsipRecordFileFormat(this.value);

  /// Creates a [PortsipRecordFileFormat] from its integer value.
  ///
  /// Returns [PortsipRecordFileFormat.none] if the value doesn't match.
  static PortsipRecordFileFormat fromValue(int value) {
    return PortsipRecordFileFormat.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PortsipRecordFileFormat.none,
    );
  }
}

/// Which direction(s) of a stream a recording captures.
///
/// Applies independently to `startRecord`'s audio and video record modes;
/// pass [none] for the stream you don't want recorded.
enum PortsipRecordMode {
  /// Not recorded.
  none(0),

  /// Only the received data (the remote party).
  receive(1),

  /// Only the sent data (the local party).
  send(2),

  /// Both received and sent data.
  both(3);

  /// The integer value passed to the native SDK
  final int value;
  const PortsipRecordMode(this.value);

  /// Creates a [PortsipRecordMode] from its integer value.
  ///
  /// Returns [PortsipRecordMode.none] if the value doesn't match.
  static PortsipRecordMode fromValue(int value) {
    return PortsipRecordMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PortsipRecordMode.none,
    );
  }
}

/// Which RTP direction(s) a stream callback reports. Values match the SDK's
/// DIRECTION_MODE on both platforms.
enum PortsipRtpDirection {
  none(0),
  sendRecv(1),
  send(2),
  recv(3);

  /// The integer value passed to the native SDK
  final int value;
  const PortsipRtpDirection(this.value);
}

/// How a file played to the remote party is mixed into the outgoing stream.
///
/// Used by `startPlayingFileToRemote`. [mixedWithMicrophone] is what an
/// in-call announcement wants: the remote party hears the file *and* the local
/// microphone, instead of the file replacing the caller's voice.
enum PortsipPlayFileAudioMode {
  /// Don't play the file's audio (video-only playback).
  none(0),

  /// Play the file's audio in place of the microphone.
  fileOnly(1),

  /// Play the file's audio mixed with the microphone.
  mixedWithMicrophone(2);

  /// The integer value passed to the native SDK
  final int value;
  const PortsipPlayFileAudioMode(this.value);

  /// Creates a [PortsipPlayFileAudioMode] from its integer value.
  ///
  /// Returns [PortsipPlayFileAudioMode.none] if the value doesn't match.
  static PortsipPlayFileAudioMode fromValue(int value) {
    return PortsipPlayFileAudioMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PortsipPlayFileAudioMode.none,
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
