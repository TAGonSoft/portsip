/// Call state enumeration representing different call statuses
enum CallStatus { idle, calling, ringing, connected, holding, failed }

/// State class for managing call-related data
class CallState {
  final CallStatus status;
  final String phoneNumber;
  final int sessionId;
  final String errorMessage;
  final bool isMuted;
  final bool isOnHold;
  final bool isSpeakerOn;
  final Duration duration;

  const CallState({
    this.status = CallStatus.idle,
    this.phoneNumber = '',
    this.sessionId = -1,
    this.errorMessage = '',
    this.isMuted = false,
    this.isOnHold = false,
    this.isSpeakerOn = false,
    this.duration = Duration.zero,
  });

  CallState copyWith({
    CallStatus? status,
    String? phoneNumber,
    int? sessionId,
    String? errorMessage,
    bool? isMuted,
    bool? isOnHold,
    bool? isSpeakerOn,
    Duration? duration,
  }) {
    return CallState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      sessionId: sessionId ?? this.sessionId,
      errorMessage: errorMessage ?? this.errorMessage,
      isMuted: isMuted ?? this.isMuted,
      isOnHold: isOnHold ?? this.isOnHold,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      duration: duration ?? this.duration,
    );
  }
}
