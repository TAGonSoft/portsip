import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:portsip/models/sip_account.dart';
import 'package:portsip/portsip.dart';
import 'package:portsip_example/portsip/pages/connection/connection_state.dart';
import 'package:portsip_example/portsip/repository/portsip_repository.dart'
    hide PortsipEvent;

class ConnectionCubit extends Cubit<ConnectionState> {
  final PortsipRepository _repository = PortsipRepository.instance;

  /// Default registration timeout in seconds
  static const int _defaultRegistrationTimeout = 30;

  ConnectionCubit() : super(ConnectionState()) {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Subscribe to single event stream and filter for registration events
    _eventSubscription = _repository.events.listen((event) {
      if (event is RegisterSuccessEvent) {
        _handleRegisterSuccess(event);
      } else if (event is RegisterFailureEvent) {
        _handleRegisterFailure(event);
      }
    });
  }

  // Single subscription for all events
  StreamSubscription<dynamic>? _eventSubscription;

  // Timer for registration timeout
  Timer? _registrationTimer;

  void _handleRegisterSuccess(RegisterSuccessEvent event) {
    _cancelRegistrationTimer();
    emit(state.copyWith(status: ConnectionStatus.connected, isOnline: true));
  }

  void _handleRegisterFailure(RegisterFailureEvent event) {
    _cancelRegistrationTimer();
    emit(state.copyWith(status: ConnectionStatus.error, isOnline: false));
  }

  void _cancelRegistrationTimer() {
    _registrationTimer?.cancel();
    _registrationTimer = null;
  }

  void _startRegistrationTimer(int timeoutSeconds) {
    _cancelRegistrationTimer();
    _registrationTimer = Timer(Duration(seconds: timeoutSeconds), () {
      // Only timeout if still in connecting state
      if (state.status == ConnectionStatus.connecting) {
        emit(state.copyWith(status: ConnectionStatus.error, isOnline: false));
      }
    });
  }

  Future<void> connect({required SipAccount account}) async {
    emit(state.copyWith(isOnline: true, status: ConnectionStatus.connecting));

    try {
      // Initialize SDK with user provided Local IP
      await _repository.initialize();

      // Step 1: Configure the SIP account (setUser)
      final registerResult = await _repository.register(account: account);

      if (registerResult != 0) {
        emit(state.copyWith(isOnline: false, status: ConnectionStatus.error));
        return;
      }

      // Step 2: Register with the server (if sipServer is provided)
      // For P2P mode (empty sipServer), skip this step
      if (account.sipServer.isNotEmpty) {
        // Start timeout timer before registration attempt
        // Use account timeout if provided, otherwise use default
        final timeoutSeconds =
            account.registerTimeout > 0
                ? account.registerTimeout
                : _defaultRegistrationTimeout;
        _startRegistrationTimer(timeoutSeconds);

        await _repository.registerServer(
          registerTimeout: account.registerTimeout,
          registerRetryTimes: account.registerRetryTimes,
        );

        // Registration events (onRegisterSuccess or onRegisterFailure) will
        // cancel the timer and update state. If neither arrives before timeout,
        // the timer will emit an error state.
      } else {
        // P2P mode - no server registration needed
        emit(
          state.copyWith(isOnline: true, status: ConnectionStatus.connected),
        );
      }
    } catch (e) {
      _cancelRegistrationTimer();
      emit(state.copyWith(isOnline: false, status: ConnectionStatus.error));
    }
  }

  Future<void> disconnect() async {
    _cancelRegistrationTimer();
    await _repository.unRegister();
    emit(
      state.copyWith(isOnline: false, status: ConnectionStatus.disconnected),
    );
  }

  @override
  Future<void> close() {
    _cancelRegistrationTimer();
    _eventSubscription?.cancel();
    return super.close();
  }
}
