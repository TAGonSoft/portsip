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
  Future<int> makeCall({
    required String callee,
    required bool sendSdp,
    required bool videoCall,
  }) async {
    _checkInitialized();
    return await PortsipPlatform.instance.makeCall(
      callee: callee,
      sendSdp: sendSdp,
      videoCall: videoCall,
    );
  }

  /// Hang up a call
  ///
  /// [sessionId] - The session ID of the call to hang up
  ///
  /// Returns 0 if successful
  ///
  /// Throws [PortsipStateException] if the SDK is not initialized or has been disposed.
  Future<int> hangUp({required int sessionId}) async {
    _checkInitialized();
    return await PortsipPlatform.instance.hangUp(sessionId: sessionId);
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
}
