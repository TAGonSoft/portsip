/// Typed event classes for PortSIP SDK events.
///
/// These classes provide strongly-typed access to event data from the native SDK.
library;

/// Base class for PortSIP events with name, data, and timestamp.
///
/// This class can be extended to create custom typed event classes.
class PortsipEvent {
  /// The name of the event (e.g., "onRegisterSuccess", "onInviteConnected")
  final String name;

  /// Optional data associated with the event
  final Map<String, dynamic>? data;

  /// Timestamp when the event was created
  final DateTime timestamp;

  PortsipEvent(this.name, this.data) : timestamp = DateTime.now();

  @override
  String toString() => 'PortsipEvent($name, $data)';
}

// =============================================================================
// Registration Events
// =============================================================================

/// Event emitted when SIP registration succeeds.
class RegisterSuccessEvent extends PortsipEvent {
  /// Status text from the server (e.g., "OK")
  final String statusText;

  /// Status code from the server (e.g., 200)
  final int statusCode;

  RegisterSuccessEvent(this.statusText, this.statusCode)
      : super('onRegisterSuccess', {
          'statusText': statusText,
          'statusCode': statusCode,
        });
}

/// Event emitted when SIP registration fails.
class RegisterFailureEvent extends PortsipEvent {
  /// Status text describing the failure
  final String statusText;

  /// Status code from the server
  final int statusCode;

  RegisterFailureEvent(this.statusText, this.statusCode)
      : super('onRegisterFailure', {
          'statusText': statusText,
          'statusCode': statusCode,
        });
}

// =============================================================================
// Call Events (Outgoing Calls)
// =============================================================================

/// Event emitted when an outgoing call is trying to connect.
class InviteTryingEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  InviteTryingEvent(this.sessionId)
      : super('onInviteTrying', {'sessionId': sessionId});
}

/// Event emitted when the remote party is ringing.
class InviteRingingEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  InviteRingingEvent(this.sessionId)
      : super('onInviteRinging', {'sessionId': sessionId});
}

/// Event emitted when the call is answered by the remote party.
class InviteAnsweredEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  InviteAnsweredEvent(this.sessionId)
      : super('onInviteAnswered', {'sessionId': sessionId});
}

/// Event emitted when the call is fully connected.
class InviteConnectedEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  InviteConnectedEvent(this.sessionId)
      : super('onInviteConnected', {'sessionId': sessionId});
}

/// Event emitted when a call is closed/ended.
class InviteClosedEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  InviteClosedEvent(this.sessionId)
      : super('onInviteClosed', {'sessionId': sessionId});
}

/// Event emitted when a call fails.
class InviteFailureEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// Reason for the failure
  final String reason;

  /// Error code
  final int code;

  InviteFailureEvent(this.sessionId, this.reason, this.code)
      : super('onInviteFailure', {
          'sessionId': sessionId,
          'reason': reason,
          'code': code,
        });
}

// =============================================================================
// Remote State Events
// =============================================================================

/// Event emitted when the remote party puts the call on hold.
class RemoteHoldEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  RemoteHoldEvent(this.sessionId)
      : super('onRemoteHold', {'sessionId': sessionId});
}

/// Event emitted when the remote party resumes the call from hold.
class RemoteUnHoldEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  RemoteUnHoldEvent(this.sessionId)
      : super('onRemoteUnHold', {'sessionId': sessionId});
}

// =============================================================================
// Audio Session Events (iOS only)
// =============================================================================

/// Event emitted when iOS audio session configuration fails (iOS only).
///
/// This event is sent during controller initialization if the AVAudioSession
/// cannot be configured for voice chat mode.
class AudioSessionErrorEvent extends PortsipEvent {
  /// The error message describing what failed
  final String error;

  /// The NSError code from iOS
  final int errorCode;

  /// The NSError domain from iOS (e.g., "NSOSStatusErrorDomain")
  final String errorDomain;

  AudioSessionErrorEvent(this.error, this.errorCode, this.errorDomain)
      : super('onAudioSessionError', {
          'error': error,
          'errorCode': errorCode,
          'errorDomain': errorDomain,
        });
}

// =============================================================================
// CallKit Events (iOS only)
// =============================================================================

/// Event emitted when the user toggles hold via CallKit (iOS only).
class CallKitHoldEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// Whether the call is now on hold
  final bool onHold;

  CallKitHoldEvent(this.sessionId, this.onHold)
      : super('onCallKitHold', {'sessionId': sessionId, 'onHold': onHold});
}

/// Event emitted when the user toggles mute via CallKit (iOS only).
class CallKitMuteEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// Whether the call is now muted
  final bool muted;

  CallKitMuteEvent(this.sessionId, this.muted)
      : super('onCallKitMute', {'sessionId': sessionId, 'muted': muted});
}

/// Event emitted when the user toggles speaker via CallKit (iOS only).
class CallKitSpeakerEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// Whether the speaker is now enabled
  final bool enableSpeaker;

  CallKitSpeakerEvent(this.sessionId, this.enableSpeaker)
      : super('onCallKitSpeaker', {
          'sessionId': sessionId,
          'enableSpeaker': enableSpeaker,
        });
}

/// Event emitted when the user sends DTMF via CallKit (iOS only).
class CallKitDTMFEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// The DTMF digits sent
  final String digits;

  CallKitDTMFEvent(this.sessionId, this.digits)
      : super('onCallKitDTMF', {'sessionId': sessionId, 'digits': digits});
}

/// Event emitted when the user ends a call via CallKit (iOS only).
class CallKitEndCallEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  CallKitEndCallEvent(this.sessionId)
      : super('onCallKitEndCall', {'sessionId': sessionId});
}

/// Event emitted when CallKit fails to report an outgoing call (iOS only).
class CallKitFailureEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// The error message
  final String error;

  CallKitFailureEvent(this.sessionId, this.error)
      : super('onCallKitFailure', {'sessionId': sessionId, 'error': error});
}

// =============================================================================
// ConnectionService Events (Android only)
// =============================================================================

/// Event emitted when the user ends a call via ConnectionService (Android only).
class ConnectionServiceEndCallEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  ConnectionServiceEndCallEvent(this.sessionId)
      : super('onConnectionServiceEndCall', {'sessionId': sessionId});
}

/// Event emitted when the user toggles hold via ConnectionService (Android only).
class ConnectionServiceHoldEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// Whether the call is now on hold
  final bool onHold;

  ConnectionServiceHoldEvent(this.sessionId, this.onHold)
      : super('onConnectionServiceHold', {
          'sessionId': sessionId,
          'onHold': onHold,
        });
}

/// Event emitted when the user toggles mute via ConnectionService (Android only).
class ConnectionServiceMuteEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// Whether the call is now muted
  final bool muted;

  ConnectionServiceMuteEvent(this.sessionId, this.muted)
      : super('onConnectionServiceMute', {
          'sessionId': sessionId,
          'muted': muted,
        });
}

/// Event emitted when the user toggles speaker via ConnectionService (Android only).
class ConnectionServiceSpeakerEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// Whether the speaker is now enabled
  final bool enableSpeaker;

  ConnectionServiceSpeakerEvent(this.sessionId, this.enableSpeaker)
      : super('onConnectionServiceSpeaker', {
          'sessionId': sessionId,
          'enableSpeaker': enableSpeaker,
        });
}

/// Event emitted when the user sends DTMF via ConnectionService (Android only).
class ConnectionServiceDTMFEvent extends PortsipEvent {
  /// The session ID of the call
  final int sessionId;

  /// The DTMF digits sent
  final String digits;

  ConnectionServiceDTMFEvent(this.sessionId, this.digits)
      : super('onConnectionServiceDTMF', {
          'sessionId': sessionId,
          'digits': digits,
        });
}

/// Event emitted when a ConnectionService operation fails (Android only).
class ConnectionServiceFailureEvent extends PortsipEvent {
  /// The session ID of the call (if applicable)
  final int? sessionId;

  /// The error message
  final String message;

  ConnectionServiceFailureEvent(this.sessionId, this.message)
      : super('onConnectionServiceFailure', {
          'sessionId': sessionId,
          'message': message,
        });
}

// =============================================================================
// Helper function to convert generic events to typed events
// =============================================================================

/// Converts a generic [PortsipEvent] to a typed event subclass.
///
/// Returns the appropriate typed event class based on the event name,
/// or the original event if no typed class is defined.
PortsipEvent toTypedEvent(PortsipEvent event) {
  switch (event.name) {
    // Registration events
    case 'onRegisterSuccess':
      return RegisterSuccessEvent(
        event.data?['statusText'] as String? ?? '',
        event.data?['statusCode'] as int? ?? 0,
      );
    case 'onRegisterFailure':
      return RegisterFailureEvent(
        event.data?['statusText'] as String? ?? '',
        event.data?['statusCode'] as int? ?? 0,
      );

    // Call events
    case 'onInviteTrying':
      return InviteTryingEvent(event.data?['sessionId'] as int? ?? -1);
    case 'onInviteRinging':
      return InviteRingingEvent(event.data?['sessionId'] as int? ?? -1);
    case 'onInviteAnswered':
      return InviteAnsweredEvent(event.data?['sessionId'] as int? ?? -1);
    case 'onInviteConnected':
      return InviteConnectedEvent(event.data?['sessionId'] as int? ?? -1);
    case 'onInviteClosed':
      return InviteClosedEvent(event.data?['sessionId'] as int? ?? -1);
    case 'onInviteFailure':
      return InviteFailureEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['reason'] as String? ?? '',
        event.data?['code'] as int? ?? 0,
      );

    // Remote state events
    case 'onRemoteHold':
      return RemoteHoldEvent(event.data?['sessionId'] as int? ?? -1);
    case 'onRemoteUnHold':
      return RemoteUnHoldEvent(event.data?['sessionId'] as int? ?? -1);

    // Audio session events (iOS only)
    case 'onAudioSessionError':
      return AudioSessionErrorEvent(
        event.data?['error'] as String? ?? '',
        event.data?['errorCode'] as int? ?? 0,
        event.data?['errorDomain'] as String? ?? '',
      );

    // CallKit events
    case 'onCallKitHold':
      return CallKitHoldEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['onHold'] as bool? ?? false,
      );
    case 'onCallKitMute':
      return CallKitMuteEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['muted'] as bool? ?? false,
      );
    case 'onCallKitSpeaker':
      return CallKitSpeakerEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['enableSpeaker'] as bool? ?? false,
      );
    case 'onCallKitDTMF':
      return CallKitDTMFEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['digits'] as String? ?? '',
      );
    case 'onCallKitEndCall':
      return CallKitEndCallEvent(
        event.data?['sessionId'] as int? ?? -1,
      );
    case 'onCallKitFailure':
      return CallKitFailureEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['error'] as String? ?? '',
      );

    // ConnectionService events (Android)
    case 'onConnectionServiceEndCall':
      return ConnectionServiceEndCallEvent(
        event.data?['sessionId'] as int? ?? -1,
      );
    case 'onConnectionServiceHold':
      return ConnectionServiceHoldEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['onHold'] as bool? ?? false,
      );
    case 'onConnectionServiceMute':
      return ConnectionServiceMuteEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['muted'] as bool? ?? false,
      );
    case 'onConnectionServiceSpeaker':
      return ConnectionServiceSpeakerEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['enableSpeaker'] as bool? ?? false,
      );
    case 'onConnectionServiceDTMF':
      return ConnectionServiceDTMFEvent(
        event.data?['sessionId'] as int? ?? -1,
        event.data?['digits'] as String? ?? '',
      );
    case 'onConnectionServiceFailure':
      return ConnectionServiceFailureEvent(
        event.data?['sessionId'] as int?,
        event.data?['message'] as String? ?? '',
      );

    default:
      return event;
  }
}
