import 'package:portsip/models/audio_codec.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/sip_account.dart';

import 'portsip_platform_interface.dart';

// Export all event classes for convenient access
export 'package:portsip/models/portsip_events.dart';

/// Exception thrown when SDK operations are called in an invalid state.
///
/// This exception is thrown when:
/// - Methods are called before [Portsip.initialize] has been called
/// - Methods are called after [Portsip.dispose] has been called
class PortsipStateException implements Exception {
  /// A message describing the invalid state.
  final String message;

  /// Creates a new [PortsipStateException] with the given [message].
  const PortsipStateException(this.message);

  @override
  String toString() => 'PortsipStateException: $message';
}

/// Represents the lifecycle state of the PortSIP SDK.
enum PortsipState {
  /// SDK has not been initialized yet.
  /// Call [Portsip.initialize] to transition to [initialized].
  uninitialized,

  /// SDK is initialized and ready for use.
  /// Call [Portsip.dispose] to transition to [disposed].
  initialized,

  /// SDK has been disposed and cannot be used.
  /// Create a new [Portsip] instance if needed.
  disposed,
}

/// Main class for the PortSIP Flutter plugin.
///
/// This class provides a high-level API for integrating PortSIP VoIP SDK
/// functionality into Flutter applications. It supports:
/// - SIP registration and account management
/// - Outgoing voice calls (make, hang up)
/// - Call controls (hold, mute, DTMF)
/// - Audio device management (loudspeaker toggle)
/// - iOS CallKit integration
///
/// **Note**: This plugin is designed for outgoing calls only. Incoming call
/// functionality is not supported.
///
/// ## Lifecycle Management
///
/// The SDK must be initialized before use and disposed when no longer needed:
///
/// ```dart
/// final portsip = Portsip();
///
/// // Check state before operations
/// if (!portsip.isInitialized) {
///   await portsip.initialize(...);
/// }
///
/// // Use the SDK...
///
/// // Clean up when done
/// await portsip.dispose();
///
/// // After dispose, isDisposed is true and the instance cannot be reused
/// // Create a new instance if needed
/// ```
///
/// ## Session ID Type Consistency
///
/// Session IDs are used to identify active calls across the plugin. Due to
/// platform differences in the native PortSIP SDKs:
/// - **Android**: Uses `Long` (64-bit signed integer)
/// - **iOS**: Uses `Int` (64-bit on modern devices, but SDK returns 32-bit values)
/// - **Dart**: Uses `int` (64-bit on all platforms)
///
/// **Important**: For maximum compatibility across platforms, session IDs
/// returned by [makeCall] should be treated as fitting within a **32-bit
/// signed integer range** (-2,147,483,648 to 2,147,483,647). The PortSIP SDK
/// typically generates session IDs within this range.
///
/// Example usage:
/// ```dart
/// final portsip = Portsip();
///
/// // Set up event listener (recommended - supports multiple listeners)
/// final subscription = portsip.events.listen((event) {
///   print('Event: ${event.name}, Data: ${event.data}');
/// });
///
/// // Initialize SDK
/// await portsip.initialize(
///   transport: TransportType.udp,
///   localIP: '0.0.0.0',
///   localSIPPort: 5060,
///   // ... other parameters
/// );
///
/// // Don't forget to cancel the subscription when done
/// subscription.cancel();
///
/// // Dispose when done
/// await portsip.dispose();
/// ```
class Portsip {
  /// The current lifecycle state of the SDK.
  PortsipState _state = PortsipState.uninitialized;

  /// Returns the current lifecycle state of the SDK.
  PortsipState get state => _state;

  /// Returns true if the SDK has been initialized and is ready for use.
  ///
  /// This is equivalent to checking `state == PortsipState.initialized`.
  bool get isInitialized => _state == PortsipState.initialized;

  /// Returns true if the SDK has been disposed.
  ///
  /// Once disposed, this instance cannot be reused. Create a new [Portsip]
  /// instance if SIP functionality is needed again.
  bool get isDisposed => _state == PortsipState.disposed;

  /// Throws [PortsipStateException] if the SDK is disposed.
  void _checkNotDisposed() {
    if (_state == PortsipState.disposed) {
      throw const PortsipStateException(
        'SDK has been disposed. Create a new Portsip instance to use the SDK again.',
      );
    }
  }

  /// Throws [PortsipStateException] if the SDK is not initialized.
  void _checkInitialized() {
    _checkNotDisposed();
    if (_state != PortsipState.initialized) {
      throw const PortsipStateException(
        'SDK is not initialized. Call initialize() first.',
      );
    }
  }

  /// Returns a broadcast stream of PortSIP SDK events.
  ///
  /// This stream supports multiple listeners and emits events such as:
  /// - Registration events: `onRegisterSuccess`, `onRegisterFailure`
  /// - Call events: `onInviteTrying`, `onInviteRinging`, `onInviteAnswered`,
  ///   `onInviteConnected`, `onInviteClosed`, `onInviteFailure`
  /// - Remote state events: `onRemoteHold`, `onRemoteUnHold`
  /// - CallKit events (iOS): `onCallKitHold`, `onCallKitMute`, etc.
  ///
  /// Example:
  /// ```dart
  /// // Single listener
  /// portsip.events.listen((event) {
  ///   print('Event: ${event.name}');
  /// });
  ///
  /// // Multiple listeners are supported
  /// portsip.events.listen((event) => handleCallEvents(event));
  /// portsip.events.listen((event) => logAllEvents(event));
  /// ```
  Stream<PortsipEvent> get events => PortsipPlatform.instance.events;

  /// Returns a broadcast stream of typed PortSIP SDK events.
  ///
  /// This stream automatically converts generic events to typed subclasses,
  /// allowing for type-safe event handling with pattern matching.
  ///
  /// Example:
  /// ```dart
  /// portsip.typedEvents.listen((event) {
  ///   switch (event) {
  ///     case RegisterSuccessEvent():
  ///       print('Registered: ${event.statusCode}');
  ///     case InviteConnectedEvent():
  ///       print('Call connected: ${event.sessionId}');
  ///     case InviteFailureEvent():
  ///       print('Call failed: ${event.reason}');
  ///     default:
  ///       print('Other event: ${event.name}');
  ///   }
  /// });
  /// ```
  Stream<PortsipEvent> get typedEvents =>
      PortsipPlatform.instance.events.map(toTypedEvent);

  /// Initializes the PortSIP SDK with the provided configuration.
  ///
  /// This method must be called before any other PortSIP SDK functions are used.
  ///
  /// [transport] - The SIP transport protocol (e.g., UDP, TCP, TLS).
  /// [localIP] - The local IP address to bind the SIP stack to.
  /// [localSIPPort] - The local SIP port to listen on.
  /// [logLevel] - The desired logging level for the SDK.
  /// [logFilePath] - The directory path where SDK logs will be saved.
  /// [maxCallLines] - The maximum number of concurrent call lines the SDK can handle.
  /// [sipAgent] - The User-Agent string to be used in SIP messages.
  /// [audioDeviceLayer] - The audio device layer to use (e.g., CoreAudio, OpenSL ES).
  /// [videoDeviceLayer] - The video device layer to use.
  /// [tlsCertificatesRootPath] - The root path for TLS certificates.
  /// [tlsCipherList] - A string specifying the TLS cipher list.
  /// [verifyTLSCertificate] - A boolean indicating whether to verify TLS certificates.
  /// [dnsServers] - A comma-separated string of DNS server IP addresses.
  ///
  /// Returns 0 if initialization is successful, otherwise a negative error code.

  Future<int> initialize({
    required TransportType transport,
    required String localIP,
    required int localSIPPort,
    required PortsipLogLevel logLevel,
    required String logFilePath,
    required int maxCallLines,
    required String sipAgent,
    required int audioDeviceLayer,
    required int videoDeviceLayer,
    required String tlsCertificatesRootPath,
    required String tlsCipherList,
    required bool verifyTLSCertificate,
    required String dnsServers,
    int ptime = 20,
    int maxPtime = 60,
  }) async {
    _checkNotDisposed();
    if (_state == PortsipState.initialized) {
      throw const PortsipStateException(
        'SDK is already initialized. Call dispose() first before reinitializing.',
      );
    }

    final result = await PortsipPlatform.instance.initialize(
      transport: transport,
      localIP: localIP,
      localSIPPort: localSIPPort,
      logLevel: logLevel,
      logFilePath: logFilePath,
      maxCallLines: maxCallLines,
      sipAgent: sipAgent,
      audioDeviceLayer: audioDeviceLayer,
      videoDeviceLayer: videoDeviceLayer,
      tlsCertificatesRootPath: tlsCertificatesRootPath,
      tlsCipherList: tlsCipherList,
      verifyTLSCertificate: verifyTLSCertificate,
      dnsServers: dnsServers,
      ptime: ptime,
      maxPtime: maxPtime,
    );

    if (result >= 0) {
      _state = PortsipState.initialized;
    }

    return result;
  }

  /// Configures the SIP account credentials and server settings.
  ///
  /// This method sets up the SIP user credentials but does not register
  /// with the server. Call [registerServer] after this to complete registration.
  ///
  /// [account] - The SIP account configuration containing credentials and server info
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> register({required SipAccount account}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.register(account: account);
  }

  /// Make an outgoing call
  ///
  /// [callee] - The SIP URI or phone number to call
  /// [sendSdp] - Whether to send SDP in the INVITE
  /// [videoCall] - Must be false (video calls not supported, audio only)
  ///
  /// Returns the session ID if successful (>= 0), or error code (< 0).
  ///
  /// **Note**: The returned session ID fits within a 32-bit signed integer range
  /// for cross-platform compatibility. See class documentation for details.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  /// [reportToConnectionService] - Whether to report this call to the system
  /// call UI (CallKit / Android ConnectionService). Pass false for additional
  /// conference legs so the whole conference stays one system call.
  ///
  /// [displayName] - Name the system call UI shows for the callee. The number
  /// is shown when omitted. Set it at call time: iOS does not reliably honor
  /// display updates on outgoing calls after they start.
  Future<int> makeCall({
    required String callee,
    required bool sendSdp,
    required bool videoCall,
    bool reportToConnectionService = true,
    String? displayName,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.makeCall(
      callee: callee,
      sendSdp: sendSdp,
      videoCall: videoCall,
      reportToConnectionService: reportToConnectionService,
      displayName: displayName,
    );
  }

  /// Hang up a call
  ///
  /// [sessionId] - The session ID of the call to hang up
  ///
  /// Returns 0 if successful
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  /// [reportToConnectionService] - When false, drops just this SIP session
  /// without ending the system call (CallKit / ConnectionService) or stopping
  /// the shared audio session. Use for removing a single conference leg.
  Future<int> hangUp({
    required int sessionId,
    bool reportToConnectionService = true,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.hangUp(
      sessionId: sessionId,
      reportToConnectionService: reportToConnectionService,
    );
  }

  /// Put a call on hold
  ///
  /// [sessionId] - The session ID of the call to hold
  ///
  /// Returns 0 if successful
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> hold({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.hold(sessionId: sessionId);
  }

  /// Resume a call from hold
  ///
  /// [sessionId] - The session ID of the call to unhold
  ///
  /// Returns 0 if successful
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> unHold({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.unHold(sessionId: sessionId);
  }

  /// Swap which of two calls is on hold: put [holdSessionId] on hold and
  /// resume [unholdSessionId] in one native call.
  ///
  /// Prefer this over separate [hold]/[unHold] calls when swapping: on iOS
  /// the CallKit mirror must be a single atomic transaction, or CallKit can
  /// end one of the calls (one-active-call enforcement).
  ///
  /// Returns 0 if successful.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> swapHold({
    required int holdSessionId,
    required int unholdSessionId,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.swapHold(
      holdSessionId: holdSessionId,
      unholdSessionId: unholdSessionId,
    );
  }

  /// Ends [endSessionId] and resumes [resumeSessionId] in one atomic
  /// transaction, keeping exactly one active call in the system call UI.
  ///
  /// Returns 0 if successful.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  Future<int> endCallAndResume({
    required int endSessionId,
    required int resumeSessionId,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.endCallAndResume(
      endSessionId: endSessionId,
      resumeSessionId: resumeSessionId,
    );
  }

  /// Create an audio conference bridge. Sessions joined via [joinToConference]
  /// are mixed together so all participants hear each other.
  ///
  /// Returns the conference id (>= 0) on success, or an error code (< 0).
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  Future<int> createAudioConference() async {
    _checkInitialized();
    return await PortsipPlatform.instance.createAudioConference();
  }

  /// Join a session into the existing conference. The session must not be on
  /// hold — un-hold it first.
  ///
  /// [sessionId] - The session ID to join into the conference.
  ///
  /// Returns 0 if successful.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  Future<int> joinToConference({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.joinToConference(
      sessionId: sessionId,
    );
  }

  /// Remove a session from the existing conference.
  ///
  /// [sessionId] - The session ID to remove from the conference.
  ///
  /// Returns 0 if successful.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  Future<int> removeFromConference({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.removeFromConference(
      sessionId: sessionId,
    );
  }

  /// Destroy the existing conference bridge.
  ///
  /// Returns 0 if successful.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  Future<int> destroyConference() async {
    _checkInitialized();
    return await PortsipPlatform.instance.destroyConference();
  }

  /// Groups [sessionIds] into one native conference call in the system call UI.
  /// No call is ended; listen on `onCallKitMerge` to build the audio bridge.
  ///
  /// Returns 0 if successful.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  Future<int> requestCallGroup({required List<int> sessionIds}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.requestCallGroup(
      sessionIds: sessionIds,
    );
  }

  /// Collapse a merged conference to a SINGLE system call: ends the CallKit /
  /// ConnectionService calls for the merged-away legs (their SIP sessions stay
  /// live in the conference bridge) so the OS shows one call instead of several.
  ///
  /// [primarySessionId] - The leg whose system call represents the conference.
  /// [mergedAwaySessionIds] - The other legs whose system calls to end.
  ///
  /// Returns 0 if successful.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  @Deprecated(
    'Use requestCallGroup for native call grouping; ending the merged-away '
    'call tears down the audio session.',
  )
  Future<int> reportConferenceMerged({
    required int primarySessionId,
    required List<int> mergedAwaySessionIds,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.reportConferenceMerged(
      primarySessionId: primarySessionId,
      mergedAwaySessionIds: mergedAwaySessionIds,
    );
  }

  /// Update the display name the system call UI (CallKit / ConnectionService)
  /// shows for [sessionId]'s call — e.g. a conference title after a merge.
  /// No-op for sessions without a system call.
  ///
  /// On iOS this also re-handles the call with a generic handle carrying the
  /// display string (outgoing calls otherwise ignore caller-name updates).
  ///
  /// Returns 0 if successful.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  Future<int> updateOsCallDisplay({
    required int sessionId,
    required String displayName,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.updateOsCallDisplay(
      sessionId: sessionId,
      displayName: displayName,
    );
  }

  /// Mute or unmute a session
  ///
  /// [sessionId] - The session ID
  /// [muteIncomingAudio] - Mute incoming audio
  /// [muteOutgoingAudio] - Mute outgoing audio (microphone)
  /// [muteIncomingVideo] - Mute incoming video
  /// [muteOutgoingVideo] - Mute outgoing video (camera)
  ///
  /// Returns 0 if successful
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> muteSession({
    required int sessionId,
    required bool muteIncomingAudio,
    required bool muteOutgoingAudio,
    required bool muteIncomingVideo,
    required bool muteOutgoingVideo,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.muteSession(
      sessionId: sessionId,
      muteIncomingAudio: muteIncomingAudio,
      muteOutgoingAudio: muteOutgoingAudio,
      muteIncomingVideo: muteIncomingVideo,
      muteOutgoingVideo: muteOutgoingVideo,
    );
  }

  /// Enable or disable loudspeaker
  ///
  /// [enable] - true to enable loudspeaker, false for earpiece
  ///
  /// Returns 0 if successful
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> setLoudspeakerStatus({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.setLoudspeakerStatus(enable: enable);
  }

  /// Routes the current call's audio to a specific output (Android, Telecom-owned).
  ///
  /// [kind] - one of: builtInReceiver, builtInSpeaker, bluetooth, headphones.
  /// Returns 0 if successful, -1 on iOS (not implemented there — use
  /// [setLoudspeakerStatus], or route via AVAudioSession in the app).
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or disposed.
  Future<int> setAudioRoute({required String kind}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.setAudioRoute(kind: kind);
  }

  /// Send DTMF tone
  ///
  /// [sessionId] - The session ID
  /// [dtmf] - The DTMF tone (0-9, *, #)
  /// [playDtmfTone] - Whether to play the tone locally
  /// [dtmfMethod] - DTMF method: 0 = RFC2833 (default), 1 = INFO, 2 = INBAND
  /// [dtmfDuration] - Duration of the DTMF tone in milliseconds (default: 160)
  ///
  /// Returns 0 if successful
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> sendDtmf({
    required int sessionId,
    required int dtmf,
    required bool playDtmfTone,
    int dtmfMethod = 0,
    int dtmfDuration = 160,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.sendDtmf(
      sessionId: sessionId,
      dtmf: dtmf,
      playDtmfTone: playDtmfTone,
      dtmfMethod: dtmfMethod,
      dtmfDuration: dtmfDuration,
    );
  }

  /// Configure CallKit for iOS (no-op on Android)
  ///
  /// [appName] - The app name to display in CallKit UI
  /// [canUseCallKit] - Whether to enable CallKit integration (default: true)
  /// [iconTemplateImageName] - Optional icon template image name for CallKit UI
  ///
  /// This method should be called after initialize() to enable CallKit on iOS.
  /// On Android, this method does nothing.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<void> configureCallKit({
    required String appName,
    bool canUseCallKit = true,
    String? iconTemplateImageName,
  }) async {
    _checkInitialized();
    await PortsipPlatform.instance.configureCallKit(
      appName: appName,
      canUseCallKit: canUseCallKit,
      iconTemplateImageName: iconTemplateImageName,
    );
  }

  /// Enable or disable CallKit at runtime (iOS only)
  ///
  /// [enabled] - Whether to enable CallKit
  ///
  /// On Android, this method does nothing.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<void> enableCallKit({required bool enabled}) async {
    _checkInitialized();
    await PortsipPlatform.instance.enableCallKit(enabled: enabled);
  }

  /// Configure ConnectionService for Android (no-op on iOS)
  ///
  /// [appName] - The app name to display in the system call UI
  /// [canUseConnectionService] - Whether to enable ConnectionService integration (default: true)
  ///
  /// This method should be called after initialize() to enable native call UI on Android.
  /// On iOS, this method does nothing (use configureCallKit instead).
  ///
  /// Returns 0 on success, negative error code on failure.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> configureConnectionService({
    required String appName,
    bool canUseConnectionService = true,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.configureConnectionService(
      appName: appName,
      canUseConnectionService: canUseConnectionService,
    );
  }

  /// Enable or disable ConnectionService at runtime (Android only)
  ///
  /// [enabled] - Whether to enable ConnectionService
  ///
  /// On iOS, this method does nothing (use enableCallKit instead).
  ///
  /// Returns 0 on success, negative error code on failure.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableConnectionService({required bool enabled}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableConnectionService(
      enabled: enabled,
    );
  }

  /// Set the PortSIP license key
  ///
  /// [licenseKey] - The PortSIP license key
  ///
  /// This should be called after initialize() and before register().
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> setLicenseKey({required String licenseKey}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.setLicenseKey(licenseKey: licenseKey);
  }

  /// Enable or disable plugin debug logs
  ///
  /// [enabled] - true to enable debug logging, false to disable (default: false)
  ///
  /// When enabled, logs method calls, responses, and events for debugging.
  /// This affects logging on Dart, iOS, and Android layers.
  void setLogsEnabled({required bool enabled}) {
    PortsipPlatform.instance.setLogsEnabled(enabled: enabled);
  }

  /// Configure audio codecs for the SIP session
  ///
  /// [audioCodecs] - List of audio codecs to enable
  ///
  /// This should be called after initialize() and before making calls.
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> setAudioCodecs({required List<AudioCodec> audioCodecs}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.setAudioCodecs(
      audioCodecs: audioCodecs,
    );
  }

  /// Enable or disable the audio manager
  ///
  /// [enable] - true to enable audio manager, false to disable (default: true)
  ///
  /// This is critical for DTMF functionality on Android.
  /// Should be called after register() and before making calls.
  ///
  /// Android: when calls are reported to the ConnectionService and audio is
  /// routed through Telecom ([setAudioRoute]), pass false. The SDK's built-in
  /// audio manager competes with Telecom and resets the route to earpiece on
  /// every new call leg.
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableAudioManager({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableAudioManager(enable: enable);
  }

  /// Set the SRTP (Secure Real-time Transport Protocol) policy
  ///
  /// [policy] - SRTP policy value:
  ///   - 0: None (no SRTP, unencrypted RTP)
  ///   - 1: Prefer (prefer SRTP but allow non-SRTP if peer doesn't support it)
  ///   - 2: Force (require SRTP, fail if peer doesn't support it)
  ///
  /// Controls how SRTP is used for call encryption.
  /// Should be called after register() and before making calls.
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> setSrtpPolicy({required int policy}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.setSrtpPolicy(policy: policy);
  }

  /// Enable or disable 3GPP tags in SIP messages
  ///
  /// [enable] - true to enable 3GPP tags, false to disable (default: false)
  ///
  /// 3GPP (3rd Generation Partnership Project) tags add additional headers
  /// to SIP messages for compatibility with certain carriers.
  /// Should be called after register() and before making calls.
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enable3GppTags({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enable3GppTags(enable: enable);
  }

  /// Enable or disable Acoustic Echo Cancellation (AEC)
  ///
  /// **Android only** - On iOS, this returns 0 without any effect as iOS
  /// handles AEC at the system level via AVAudioSession.
  ///
  /// [enable] - true to enable AEC, false to disable (default: true)
  ///
  /// AEC removes echo from the audio signal caused by speaker-to-microphone
  /// feedback. This is important for preventing the remote party from hearing
  /// their own voice echoed back.
  ///
  /// Should be called after initialize() and before making calls.
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableAEC({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableAEC(enable: enable);
  }

  /// Enable or disable Automatic Gain Control (AGC)
  ///
  /// **Android only** - On iOS, this returns 0 without any effect as iOS
  /// handles AGC at the system level via AVAudioSession.
  ///
  /// [enable] - true to enable AGC, false to disable (default: true)
  ///
  /// AGC automatically adjusts the microphone volume to maintain consistent
  /// audio levels, ensuring the speaker's voice is at an appropriate volume
  /// regardless of their distance from the microphone.
  ///
  /// Should be called after initialize() and before making calls.
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableAGC({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableAGC(enable: enable);
  }

  /// Enable or disable Comfort Noise Generation (CNG)
  ///
  /// [enable] - true to enable CNG, false to disable (default: true)
  ///
  /// CNG generates artificial background noise during silent periods to avoid
  /// dead silence, which can make users think the connection was lost.
  ///
  /// Should be called after initialize() and before making calls.
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableCNG({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableCNG(enable: enable);
  }

  /// Enable or disable Voice Activity Detection (VAD)
  ///
  /// [enable] - true to enable VAD, false to disable (default: true)
  ///
  /// VAD detects when speech is present and can be used to reduce bandwidth
  /// by not transmitting audio during silence.
  ///
  /// Should be called after initialize() and before making calls.
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableVAD({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableVAD(enable: enable);
  }

  /// Enable or disable Automatic Noise Suppression (ANS)
  ///
  /// **Android only** - On iOS, this returns 0 without any effect as the
  /// PortSIP iOS SDK does not expose this method.
  ///
  /// [enable] - true to enable ANS, false to disable (default: false)
  ///
  /// ANS reduces background noise in the audio signal, improving voice clarity
  /// in noisy environments.
  ///
  /// Should be called after initialize() and before making calls.
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableANS({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableANS(enable: enable);
  }

  /// Register with the SIP server
  ///
  /// This should be called after register() to complete the server registration.
  /// For P2P mode (when sipServer was empty in register()), this method is not needed.
  ///
  /// [registerTimeout] - Registration timeout in seconds (default: 120)
  /// [registerRetryTimes] - Number of retry attempts (default: 3)
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> registerServer({
    int registerTimeout = 120,
    int registerRetryTimes = 3,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.registerServer(
      registerTimeout: registerTimeout,
      registerRetryTimes: registerRetryTimes,
    );
  }

  /// Refresh the registration with the SIP server
  ///
  /// Call this when the device's network changes (e.g. WiFi to cellular
  /// handoff) — the SDK re-registers over the new network interface and
  /// updates any active call session so audio resumes.
  ///
  /// [expires] - Registration expiry in seconds. Pass 0 (default) to keep the
  /// previously negotiated expiry and force an immediate re-register.
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> refreshRegistration({int expires = 0}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.refreshRegistration(expires: expires);
  }

  /// Enable SIP session timers (RFC 4028) for all subsequent calls.
  ///
  /// The call negotiates a `Session-Expires` interval and the refresher
  /// periodically re-INVITEs/UPDATEs to keep it alive. If a party stops
  /// refreshing (e.g. the client loses network mid-call), the other side
  /// terminates the session at expiry — so the server reaps a dead leg in
  /// ~[timerSeconds] instead of holding it open for minutes.
  ///
  /// [timerSeconds] - Session interval in seconds. Minimum 90 (SDK requirement).
  /// [refreshMode] - 0 = caller/UAC refreshes (default), 1 = callee/UAS.
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableSessionTimer({
    int timerSeconds = 90,
    int refreshMode = 0,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableSessionTimer(
      timerSeconds: timerSeconds,
      refreshMode: refreshMode,
    );
  }

  /// Update an active call session (sends a re-INVITE)
  ///
  /// Renegotiates the media streams of an established call. Use it to add or
  /// remove audio/video, or after a network change (WiFi ↔ cellular handoff)
  /// to re-anchor the media streams to the new network interface.
  ///
  /// [sessionId] - The session ID of the call to update
  /// [enableAudio] - true to keep/enable the audio stream (default: true)
  /// [enableVideo] - true to enable the video stream (default: false)
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> updateCall({
    required int sessionId,
    bool enableAudio = true,
    bool enableVideo = false,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.updateCall(
      sessionId: sessionId,
      enableAudio: enableAudio,
      enableVideo: enableVideo,
    );
  }

  /// Request RTP media statistics for a session.
  ///
  /// The statistics are delivered asynchronously on the [events] / [typedEvents]
  /// stream as an `onStatistics` ([StatisticsEvent]) carrying a JSON `stat`
  /// string with byte/packet/jitter/loss counters. Call this periodically (e.g.
  /// once per second) while a call is up to track its data usage.
  ///
  /// [sessionId] - The session ID of the call to inspect.
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> getStatistics({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.getStatistics(sessionId: sessionId);
  }

  /// Enable or disable QoS DSCP marking on the audio channel.
  ///
  /// The SDK marks audio packets DSCP 46 (Expedited Forwarding) when enabled,
  /// 0 when disabled. Best-effort: many Wi-Fi and carrier networks rewrite or
  /// ignore DSCP.
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableAudioQos({required bool enable}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableAudioQos(enable: enable);
  }

  /// Mirror sent and/or received SIP messages into the platform logs.
  ///
  /// A diagnostic aid for SIP-level troubleshooting: the SDK hands the plugin a
  /// copy of each message, so enabling this cannot alter, delay or block what
  /// goes on the wire. Both directions are off by default.
  ///
  /// Messages are logged to Logcat on Android and the Xcode console on iOS, and
  /// only while [setLogsEnabled] is on. Digest `response="..."` values are
  /// redacted; SIP URIs, Call-IDs and nonces still appear, so leave this off in
  /// release builds.
  ///
  /// [sending] - true to log messages the SDK sends
  /// [received] - true to log messages the SDK receives
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> enableCallbackSignaling({
    required bool sending,
    required bool received,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.enableCallbackSignaling(
      sending: sending,
      received: received,
    );
  }

  /// Start recording the call on a session.
  ///
  /// Recording is per session, not per call: the SDK has no conference-level
  /// recorder, so a conference is recorded by calling this once per leg (each
  /// leg writing its own file).
  ///
  /// [sessionId] - The session ID of the call to record.
  /// [recordFilePath] - Directory the file is written to. It must already
  /// exist; the SDK does not create it.
  /// [recordFileName] - File name *without* an extension, e.g. `call`. The
  /// SDK appends the extension matching [fileFormat] itself, so passing
  /// `call.wav` writes `call.wav.wav`.
  /// [appendTimeStamp] - Appends a timestamp to the file name when true.
  /// [audioChannels] - 1 for mono, 2 for stereo.
  /// [fileFormat] - Container for the recording (default: WAVE).
  /// [audioRecordMode] - Which audio directions to capture (default: both).
  /// [videoRecordMode] - Which video directions to capture (default: none).
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> startRecord({
    required int sessionId,
    required String recordFilePath,
    required String recordFileName,
    bool appendTimeStamp = false,
    int audioChannels = 1,
    PortsipRecordFileFormat fileFormat = PortsipRecordFileFormat.wave,
    PortsipRecordMode audioRecordMode = PortsipRecordMode.both,
    PortsipRecordMode videoRecordMode = PortsipRecordMode.none,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.startRecord(
      sessionId: sessionId,
      recordFilePath: recordFilePath,
      recordFileName: recordFileName,
      appendTimeStamp: appendTimeStamp,
      audioChannels: audioChannels,
      fileFormat: fileFormat,
      audioRecordMode: audioRecordMode,
      videoRecordMode: videoRecordMode,
    );
  }

  /// Stop the recording running on a session.
  ///
  /// [sessionId] - The session ID whose recording should stop.
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> stopRecord({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.stopRecord(sessionId: sessionId);
  }

  /// Write a session's raw audio stream to a WAVE file.
  ///
  /// An alternative to [startRecord] that writes the PCM the SDK delivers to
  /// its audio stream callback, rather than routing it through the SDK's own
  /// recorder. Both directions are captured into one stereo `<recordFileName>.wav`
  /// — sent audio on the left channel, received on the right — so neither side
  /// can clip the other and the two remain separable. A call that produced only
  /// one direction stays mono.
  ///
  /// [recordFilePath] must already exist; it is not created.
  ///
  /// **Android only** - On iOS, this returns -1 without any effect, as the
  /// iOS SDK has no raw audio stream callback.
  ///
  /// Returns 0 if successful, error code otherwise. A missing
  /// [recordFilePath] returns -1.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> startPcmRecord({
    required int sessionId,
    required String recordFilePath,
    required String recordFileName,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.startPcmRecord(
      sessionId: sessionId,
      recordFilePath: recordFilePath,
      recordFileName: recordFileName,
    );
  }

  /// Stop the raw-audio recording on a session and finalise its files.
  ///
  /// Completes once the per-direction parts have been merged and the file is on
  /// disk, which for a long call takes a moment.
  ///
  /// If the call ended before this is called, the recording is still collectable
  /// — stopping from an `onInviteClosed` handler is the ordinary case.
  ///
  /// [sessionId] - The session ID whose recording should stop.
  ///
  /// **Android only** - On iOS, this returns null without any effect, as the
  /// iOS SDK has no raw audio stream callback.
  ///
  /// Returns the finished recording's path, or null if nothing was captured.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<String?> stopPcmRecord({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.stopPcmRecord(sessionId: sessionId);
  }

  /// Play a file into the stream sent to the remote party.
  ///
  /// The remote party hears the file as if it were coming from the
  /// microphone. With the default
  /// [PortsipPlayFileAudioMode.mixedWithMicrophone] the microphone stays live
  /// underneath it, which is what an in-call announcement wants — use
  /// [PortsipPlayFileAudioMode.fileOnly] to replace the caller's voice
  /// instead.
  ///
  /// [sessionId] - The session ID of the call to play into.
  /// [fileUrl] - Path or URL of the file, e.g. `/announcement.wav`.
  /// [loop] - Repeat the file instead of stopping when it ends.
  /// [playAudio] - How the file's audio mixes with the microphone.
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> startPlayingFileToRemote({
    required int sessionId,
    required String fileUrl,
    bool loop = false,
    PortsipPlayFileAudioMode playAudio =
        PortsipPlayFileAudioMode.mixedWithMicrophone,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.startPlayingFileToRemote(
      sessionId: sessionId,
      fileUrl: fileUrl,
      loop: loop,
      playAudio: playAudio,
    );
  }

  /// Stop the file playback running on a session.
  ///
  /// [sessionId] - The session ID whose playback should stop.
  ///
  /// Returns 0 if successful, error code otherwise.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> stopPlayingFileToRemote({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.stopPlayingFileToRemote(
      sessionId: sessionId,
    );
  }

  /// Unregister from the SIP server
  ///
  /// This method unregisters from the SIP server without releasing SDK resources.
  /// Use this when you want to temporarily disconnect from the server but may
  /// re-register later without reinitializing the SDK.
  ///
  /// For complete cleanup (unregister + release resources), use [dispose] instead.
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<void> unRegister() async {
    _checkInitialized();
    await PortsipPlatform.instance.unRegister();
  }

  /// Dispose of all SDK resources and clean up
  ///
  /// This method should be called when the plugin is no longer needed,
  /// typically when the app is shutting down or the user logs out.
  ///
  /// This method:
  /// - Unregisters from the SIP server
  /// - Removes all observers and listeners (NotificationCenter on iOS)
  /// - Releases native SDK resources
  /// - Clears event stream handlers
  /// - Disposes CallKit provider (iOS)
  ///
  /// After calling dispose(), this instance should not be used.
  /// Create a new Portsip instance if SIP functionality is needed again.
  ///
  /// Throws [PortsipStateException] if the SDK has already been disposed.
  ///
  /// Note: It is safe to call dispose() even if [initialize] was never called
  /// or failed. In this case, it will simply mark the instance as disposed.
  Future<void> dispose() async {
    _checkNotDisposed();

    // Only call native dispose if we were initialized
    if (_state == PortsipState.initialized) {
      await PortsipPlatform.instance.dispose();
    }

    _state = PortsipState.disposed;
  }

  /// Tears down the native SDK so a different SIP user can be loaded via
  /// [initialize] + [register] again, without shutting down the plugin.
  ///
  /// Use this for runtime user swap (e.g. the user picks a different phone
  /// number). Unlike [dispose] this keeps the event stream and method
  /// channel handler alive — after the next [initialize] events keep flowing
  /// to the same listeners.
  ///
  /// This is a no-op if the SDK is not currently initialized.
  ///
  /// Throws [PortsipStateException] if the SDK has been disposed.
  Future<void> unInitialize() async {
    _checkNotDisposed();

    if (_state == PortsipState.initialized) {
      await PortsipPlatform.instance.unInitialize();
    }

    _state = PortsipState.uninitialized;
  }
}
