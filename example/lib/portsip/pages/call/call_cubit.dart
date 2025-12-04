import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:portsip/portsip.dart';

import 'package:portsip_example/portsip/repository/portsip_repository.dart';
import 'call_state.dart';

class CallCubit extends Cubit<CallState> {
  final PortsipRepository _repository = PortsipRepository.instance;
  Timer? _durationTimer;

  CallCubit() : super(const CallState()) {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Subscribe to typed events stream and filter for call events
    _eventSubscription = _repository.events.listen((event) {
      if (event is InviteRingingEvent) {
        _handleCallRinging(event);
      } else if (event is InviteAnsweredEvent) {
        _handleCallAnswered(event);
      } else if (event is InviteConnectedEvent) {
        _handleCallConnected(event);
      } else if (event is InviteClosedEvent) {
        _handleCallClosed(event);
      } else if (event is InviteFailureEvent) {
        _handleCallFailure(event);
      } else if (event is RemoteHoldEvent) {
        _handleRemoteHold(event);
      } else if (event is RemoteUnHoldEvent) {
        _handleRemoteUnHold(event);
      } else if (event is CallKitMuteEvent) {
        _handleCallKitMute(event);
      } else if (event is CallKitHoldEvent) {
        _handleCallKitHold(event);
      } else if (event is CallKitSpeakerEvent) {
        _handleCallKitSpeaker(event);
      } else if (event is CallKitDTMFEvent) {
        _handleCallKitDTMF(event);
      } else if (event is ConnectionServiceEndCallEvent) {
        _handleConnectionServiceEndCall(event);
      } else if (event is ConnectionServiceHoldEvent) {
        _handleConnectionServiceHold(event);
      } else if (event is ConnectionServiceMuteEvent) {
        _handleConnectionServiceMute(event);
      } else if (event is ConnectionServiceSpeakerEvent) {
        _handleConnectionServiceSpeaker(event);
      } else if (event is ConnectionServiceDTMFEvent) {
        _handleConnectionServiceDTMF(event);
      } else if (event is ConnectionServiceFailureEvent) {
        _handleConnectionServiceFailure(event);
      }
    });
  }

  // Single subscription for all events
  StreamSubscription<dynamic>? _eventSubscription;

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newDuration = state.duration + const Duration(seconds: 1);
      emit(state.copyWith(duration: newDuration));
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  // Event handlers
  void _handleCallRinging(InviteRingingEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(status: CallStatus.ringing));
    }
  }

  void _handleCallAnswered(InviteAnsweredEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(status: CallStatus.connected));
      _startTimer();
    }
  }

  void _handleCallConnected(InviteConnectedEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(status: CallStatus.connected));
      _startTimer();
    }
  }

  void _handleCallClosed(InviteClosedEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      _stopTimer();
      emit(const CallState()); // Reset to idle
    }
  }

  void _handleCallFailure(InviteFailureEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: '${event.reason} (Code: ${event.code})',
        ),
      );
      _stopTimer();
    }
  }

  void _handleRemoteHold(RemoteHoldEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(status: CallStatus.holding, isOnHold: true));
    }
  }

  void _handleRemoteUnHold(RemoteUnHoldEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(status: CallStatus.connected, isOnHold: false));
    }
  }

  void _handleCallKitMute(CallKitMuteEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(isMuted: event.muted));
    }
  }

  void _handleCallKitHold(CallKitHoldEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(
        state.copyWith(
          isOnHold: event.onHold,
          status: event.onHold ? CallStatus.holding : CallStatus.connected,
        ),
      );
    }
  }

  void _handleCallKitSpeaker(CallKitSpeakerEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(isSpeakerOn: event.enableSpeaker));
    }
  }

  void _handleCallKitDTMF(CallKitDTMFEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      // Optional: Show feedback or log
    }
  }

  // ConnectionService event handlers (Android)
  void _handleConnectionServiceEndCall(ConnectionServiceEndCallEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      _stopTimer();
      emit(const CallState()); // Reset to idle
    }
  }

  void _handleConnectionServiceHold(ConnectionServiceHoldEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(
        state.copyWith(
          isOnHold: event.onHold,
          status: event.onHold ? CallStatus.holding : CallStatus.connected,
        ),
      );
    }
  }

  void _handleConnectionServiceMute(ConnectionServiceMuteEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(isMuted: event.muted));
    }
  }

  void _handleConnectionServiceSpeaker(ConnectionServiceSpeakerEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(state.copyWith(isSpeakerOn: event.enableSpeaker));
    }
  }

  void _handleConnectionServiceDTMF(ConnectionServiceDTMFEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      // Optional: Show feedback or log
    }
  }

  void _handleConnectionServiceFailure(ConnectionServiceFailureEvent event) {
    final sessionId = event.sessionId;
    if (sessionId == state.sessionId) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: 'ConnectionService error: ${event.message}',
        ),
      );
    }
  }

  /// Update the phone number field
  void updatePhoneNumber(String phoneNumber) {
    emit(state.copyWith(phoneNumber: phoneNumber));
  }

  /// Make an audio call
  Future<void> makeAudioCall() async {
    if (state.phoneNumber.isEmpty) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: 'Please enter a phone number',
        ),
      );
      return;
    }

    if (state.status != CallStatus.idle) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: 'A call is already in progress',
        ),
      );
      return;
    }

    emit(state.copyWith(status: CallStatus.calling, errorMessage: ''));

    try {
      final sessionId = await _repository.makeCall(
        callee: state.phoneNumber,
        sendSdp: true,
        videoCall: false,
      );

      if (sessionId >= 0) {
        emit(state.copyWith(sessionId: sessionId, status: CallStatus.calling));
      } else {
        emit(
          state.copyWith(
            status: CallStatus.failed,
            errorMessage: 'Failed to make call. Error code: $sessionId',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(status: CallStatus.failed, errorMessage: 'Error: $e'),
      );
    }
  }

  /// Hang up the current call
  Future<void> hangUp() async {
    if (state.sessionId < 0) return;

    try {
      final result = await _repository.hangUp(sessionId: state.sessionId);
      if (result == 0) {
        _stopTimer();
        emit(const CallState()); // Reset to idle
      } else {
        emit(
          state.copyWith(
            status: CallStatus.failed,
            errorMessage: 'Error hanging up: $result',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: 'Error hanging up: $e',
        ),
      );
    }
  }

  /// Toggle hold state
  Future<void> toggleHold() async {
    if (state.sessionId < 0 ||
        (state.status != CallStatus.connected &&
            state.status != CallStatus.holding)) {
      return;
    }

    try {
      if (state.isOnHold) {
        final result = await _repository.unHold(sessionId: state.sessionId);
        if (result == 0) {
          emit(state.copyWith(isOnHold: false, status: CallStatus.connected));
        } else {
          emit(
            state.copyWith(
              status: CallStatus.failed,
              errorMessage: 'Failed to unhold. Error code: $result',
            ),
          );
        }
      } else {
        final result = await _repository.hold(sessionId: state.sessionId);
        if (result == 0) {
          emit(state.copyWith(isOnHold: true, status: CallStatus.holding));
        } else {
          emit(
            state.copyWith(
              status: CallStatus.failed,
              errorMessage: 'Failed to hold. Error code: $result',
            ),
          );
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: 'Error toggling hold: $e',
        ),
      );
    }
  }

  /// Toggle mute state
  Future<void> toggleMute() async {
    if (state.sessionId < 0) return;

    try {
      final newMuteState = !state.isMuted;
      final result = await _repository.muteSession(
        sessionId: state.sessionId,
        muteIncomingAudio: newMuteState,
        muteOutgoingAudio: newMuteState,
        muteIncomingVideo: newMuteState,
        muteOutgoingVideo: newMuteState,
      );
      if (result == 0) {
        emit(state.copyWith(isMuted: newMuteState));
      } else {
        emit(
          state.copyWith(
            status: CallStatus.failed,
            errorMessage:
                'Failed to ${newMuteState ? 'mute' : 'unmute'}. Error code: $result',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: 'Error toggling mute: $e',
        ),
      );
    }
  }

  /// Toggle speaker state
  Future<void> toggleSpeaker() async {
    if (state.sessionId < 0) return;

    try {
      final newSpeakerState = !state.isSpeakerOn;
      final result = await _repository.setLoudspeakerStatus(
        enable: newSpeakerState,
      );
      if (result == 0) {
        emit(state.copyWith(isSpeakerOn: newSpeakerState));
      } else {
        emit(
          state.copyWith(
            status: CallStatus.failed,
            errorMessage: 'Failed to toggle speaker. Error code: $result',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: 'Error toggling speaker: $e',
        ),
      );
    }
  }

  /// Send DTMF tone
  Future<void> sendDtmf(String tone) async {
    if (state.sessionId < 0 || state.status != CallStatus.connected) return;

    int dtmfCode;
    if (tone == '*') {
      dtmfCode = 10;
    } else if (tone == '#') {
      dtmfCode = 11;
    } else {
      dtmfCode = int.tryParse(tone) ?? -1;
    }

    if (dtmfCode == -1) return;

    try {
      final result = await _repository.sendDtmf(
        sessionId: state.sessionId,
        dtmf: dtmfCode,
        playDtmfTone: true,
      );
      if (result != 0) {
        emit(
          state.copyWith(
            status: CallStatus.failed,
            errorMessage: 'Failed to send DTMF. Error code: $result',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: CallStatus.failed,
          errorMessage: 'Error sending DTMF: $e',
        ),
      );
    }
  }

  /// Reset call state to idle (used for retry after failure)
  void resetCall() {
    _stopTimer();
    emit(
      state.copyWith(
        status: CallStatus.idle,
        errorMessage: '',
        sessionId: -1,
        duration: Duration.zero,
      ),
    );
  }

  @override
  Future<void> close() {
    // Cancel stream subscription
    _eventSubscription?.cancel();
    _stopTimer();
    return super.close();
  }
}
