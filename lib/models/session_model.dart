/// Model to track the state of a call session.
///
/// This class represents the current state of a SIP call session,
/// including whether it's on hold, active, part of a conference, etc.
/// Based on the Swift P2PSample Session class from the PortSIP SDK.
///
/// This class is immutable. Use [copyWith] to create modified copies
/// or [SessionModel.initial] to get a fresh initial state.
///
/// ## Session ID Type Consistency
///
/// The [sessionId] field uses Dart's `int` type. Due to platform differences
/// in the native PortSIP SDKs:
/// - **Android**: Uses `Long` (64-bit signed integer)
/// - **iOS**: Uses `Int` (64-bit on modern devices, but SDK returns 32-bit values)
/// - **Dart**: Uses `int` (64-bit on all platforms)
///
/// For maximum cross-platform compatibility, session IDs are validated to
/// fit within a **32-bit signed integer range** (-2,147,483,648 to
/// 2,147,483,647). The PortSIP SDK typically generates session IDs within
/// this range, so this constraint should not affect normal usage.
///
/// Example usage:
/// ```dart
/// final session = SessionModel(
///   sessionId: callSessionId,
///   sessionState: true,
///   videoState: false,
/// );
/// ```
class SessionModel {
  /// Minimum valid session ID (32-bit signed integer minimum).
  static const int minSessionId = -2147483648;

  /// Maximum valid session ID (32-bit signed integer maximum).
  static const int maxSessionId = 2147483647;

  /// Invalid session ID constant.
  static const int invalidSessionId = -1;

  /// Unique session identifier returned by the SDK.
  ///
  /// This value is validated to be within the 32-bit signed integer range
  /// (-2,147,483,648 to 2,147,483,647) for cross-platform compatibility.
  /// Values outside this range will throw an [ArgumentError].
  final int sessionId;

  /// Whether the call is on hold
  final bool holdState;

  /// Whether the session is active (call established)
  final bool sessionState;

  /// Whether this session is part of a conference
  final bool conferenceState;

  /// Whether this is an incoming call waiting to be answered
  final bool recvCallState;

  /// Whether this is a referred call (transferred)
  final bool isReferCall;

  /// Original call session ID (for refer/transfer scenarios)
  final int originCallSessionId;

  /// Whether early media exists (audio before call is answered)
  final bool existEarlyMedia;

  /// Whether this is a video call
  final bool videoState;

  /// Creates a new SessionModel with the specified state.
  ///
  /// All parameters are optional with sensible defaults:
  /// - [sessionId]: Defaults to -1 (invalid session)
  /// - All boolean states default to false
  ///
  /// Throws [ArgumentError] if [sessionId] or [originCallSessionId] is
  /// outside the valid 32-bit signed integer range.
  SessionModel({
    this.sessionId = invalidSessionId,
    this.holdState = false,
    this.sessionState = false,
    this.conferenceState = false,
    this.recvCallState = false,
    this.isReferCall = false,
    this.originCallSessionId = invalidSessionId,
    this.existEarlyMedia = false,
    this.videoState = false,
  }) {
    _validateSessionId(sessionId, 'sessionId');
    _validateSessionId(originCallSessionId, 'originCallSessionId');
  }

  /// Creates an initial session state with default values.
  ///
  /// Returns a new [SessionModel] with sessionId set to -1 and
  /// all boolean states set to false.
  factory SessionModel.initial() => SessionModel();

  /// Validates that a session ID is within the 32-bit signed integer range.
  static void _validateSessionId(int value, String fieldName) {
    if (value < minSessionId || value > maxSessionId) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Session ID must be within 32-bit signed integer range '
            '($minSessionId to $maxSessionId)',
      );
    }
  }

  /// Returns true if the session ID is valid (not -1).
  bool get isValid => sessionId != invalidSessionId;

  /// Creates a copy of this session with the specified fields updated.
  ///
  /// Any field not specified will retain its current value.
  /// Returns a new [SessionModel] instance with the updated values.
  SessionModel copyWith({
    int? sessionId,
    bool? holdState,
    bool? sessionState,
    bool? conferenceState,
    bool? recvCallState,
    bool? isReferCall,
    int? originCallSessionId,
    bool? existEarlyMedia,
    bool? videoState,
  }) {
    return SessionModel(
      sessionId: sessionId ?? this.sessionId,
      holdState: holdState ?? this.holdState,
      sessionState: sessionState ?? this.sessionState,
      conferenceState: conferenceState ?? this.conferenceState,
      recvCallState: recvCallState ?? this.recvCallState,
      isReferCall: isReferCall ?? this.isReferCall,
      originCallSessionId: originCallSessionId ?? this.originCallSessionId,
      existEarlyMedia: existEarlyMedia ?? this.existEarlyMedia,
      videoState: videoState ?? this.videoState,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionModel &&
        other.sessionId == sessionId &&
        other.holdState == holdState &&
        other.sessionState == sessionState &&
        other.conferenceState == conferenceState &&
        other.recvCallState == recvCallState &&
        other.isReferCall == isReferCall &&
        other.originCallSessionId == originCallSessionId &&
        other.existEarlyMedia == existEarlyMedia &&
        other.videoState == videoState;
  }

  @override
  int get hashCode {
    return Object.hash(
      sessionId,
      holdState,
      sessionState,
      conferenceState,
      recvCallState,
      isReferCall,
      originCallSessionId,
      existEarlyMedia,
      videoState,
    );
  }

  @override
  String toString() {
    return 'SessionModel('
        'sessionId: $sessionId, '
        'holdState: $holdState, '
        'sessionState: $sessionState, '
        'conferenceState: $conferenceState, '
        'recvCallState: $recvCallState, '
        'isReferCall: $isReferCall, '
        'originCallSessionId: $originCallSessionId, '
        'existEarlyMedia: $existEarlyMedia, '
        'videoState: $videoState)';
  }
}
