import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:portsip/models/audio_codec.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/sip_account.dart';

import 'portsip_method_channel.dart';

// Export all event classes from the events file
export 'package:portsip/models/portsip_events.dart';

// Re-import for use in this file
import 'package:portsip/models/portsip_events.dart';

/// Abstract platform interface for the PortSIP Flutter plugin.
///
/// This class defines the contract for platform-specific implementations
/// of the PortSIP VoIP SDK. It provides methods for SIP registration,
/// call management, and audio/video controls.
///
/// Platform-specific implementations (iOS and Android) extend this class
/// and provide their native implementations via method channels.
abstract class PortsipPlatform extends PlatformInterface {
  /// Constructs a PortsipPlatform.
  PortsipPlatform() : super(token: _token);

  static final Object _token = Object();

  static PortsipPlatform _instance = MethodChannelPortsip();

  /// The default instance of [PortsipPlatform] to use.
  ///
  /// Defaults to [MethodChannelPortsip].
  static PortsipPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PortsipPlatform] when
  /// they register themselves.
  static set instance(PortsipPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a broadcast stream of PortSIP SDK events.
  ///
  /// This stream can have multiple listeners. Each listener receives all
  /// events from the native side (iOS/Android) such as registration success,
  /// call state changes, etc.
  ///
  /// Example:
  /// ```dart
  /// final subscription = PortsipPlatform.instance.events.listen((event) {
  ///   print('Event: ${event.name}, Data: ${event.data}');
  /// });
  /// ```
  Stream<PortsipEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  /// Initializes the PortSIP SDK with the provided configuration.
  ///
  /// This method must be called before any other PortSIP SDK operations.
  ///
  /// Parameters:
  /// - [transport]: The SIP transport protocol (UDP, TCP, or TLS)
  /// - [localIP]: The local IP address to bind (use "0.0.0.0" for auto-detect)
  /// - [localSIPPort]: The local SIP port to listen on
  /// - [logLevel]: The logging level for the SDK
  /// - [logFilePath]: The directory path where SDK logs will be saved
  /// - [maxCallLines]: Maximum number of concurrent call lines
  /// - [sipAgent]: The User-Agent string for SIP messages
  /// - [audioDeviceLayer]: Audio device layer (0 for default)
  /// - [videoDeviceLayer]: Video device layer (0 for default)
  /// - [tlsCertificatesRootPath]: Root path for TLS certificates
  /// - [tlsCipherList]: TLS cipher list configuration
  /// - [verifyTLSCertificate]: Whether to verify TLS certificates
  /// - [dnsServers]: Comma-separated DNS server addresses
  /// - [ptime]: Audio packet time in milliseconds (default: 20)
  /// - [maxPtime]: Maximum audio packet time in milliseconds (default: 60)
  ///
  /// Returns 0 on success, negative error code on failure.
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
    throw UnimplementedError('initialize has not been implemented.');
  }

  /// Configures the SIP account credentials and server settings.
  ///
  /// This method sets up the SIP user credentials but does not register
  /// with the server. Call [registerServer] after this to complete registration.
  ///
  /// Parameters:
  /// - [account]: The SIP account configuration containing credentials and server info
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> register({required SipAccount account}) async {
    throw UnimplementedError('register has not been implemented.');
  }

  /// Unregisters from the SIP server and releases SDK resources.
  ///
  /// This should be called when logging out or shutting down SIP functionality.
  Future<void> unRegister() async {
    throw UnimplementedError('unRegister has not been implemented.');
  }

  /// Initiates an outgoing call to the specified callee.
  ///
  /// Parameters:
  /// - [callee]: The SIP URI or phone number to call
  /// - [sendSdp]: Whether to send SDP in the INVITE request
  /// - [videoCall]: True for video call, false for audio-only
  ///
  /// Returns the session ID (>= 0) on success, negative error code on failure.
  Future<int> makeCall({
    required String callee,
    required bool sendSdp,
    required bool videoCall,
  }) async {
    throw UnimplementedError('makeCall has not been implemented.');
  }

  /// Terminates an active call.
  ///
  /// Parameters:
  /// - [sessionId]: The session ID of the call to terminate
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> hangUp({required int sessionId}) async {
    throw UnimplementedError('hangUp has not been implemented.');
  }

  /// Puts a call on hold.
  ///
  /// Parameters:
  /// - [sessionId]: The session ID of the call to hold
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> hold({required int sessionId}) async {
    throw UnimplementedError('hold has not been implemented.');
  }

  /// Resumes a call that was previously put on hold.
  ///
  /// Parameters:
  /// - [sessionId]: The session ID of the call to resume
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> unHold({required int sessionId}) async {
    throw UnimplementedError('unHold has not been implemented.');
  }

  /// Mutes or unmutes audio/video streams for a call session.
  ///
  /// Parameters:
  /// - [sessionId]: The session ID of the call
  /// - [muteIncomingAudio]: True to mute incoming audio (speaker)
  /// - [muteOutgoingAudio]: True to mute outgoing audio (microphone)
  /// - [muteIncomingVideo]: True to mute incoming video
  /// - [muteOutgoingVideo]: True to mute outgoing video (camera)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> muteSession({
    required int sessionId,
    required bool muteIncomingAudio,
    required bool muteOutgoingAudio,
    required bool muteIncomingVideo,
    required bool muteOutgoingVideo,
  }) async {
    throw UnimplementedError('muteSession has not been implemented.');
  }

  /// Enables or disables the loudspeaker (speakerphone).
  ///
  /// Parameters:
  /// - [enable]: True to enable loudspeaker, false for earpiece
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> setLoudspeakerStatus({required bool enable}) async {
    throw UnimplementedError('setLoudspeakerStatus has not been implemented.');
  }

  /// Sends a DTMF (Dual-Tone Multi-Frequency) tone during a call.
  ///
  /// Parameters:
  /// - [sessionId]: The session ID of the active call
  /// - [dtmf]: The DTMF digit to send (0-9 for digits, 10 for *, 11 for #)
  /// - [playDtmfTone]: Whether to play the tone locally
  /// - [dtmfMethod]: DTMF transmission method:
  ///   - 0: RFC2833 (default, recommended)
  ///   - 1: SIP INFO
  ///   - 2: In-band audio
  /// - [dtmfDuration]: Duration of the tone in milliseconds (default: 160)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> sendDtmf({
    required int sessionId,
    required int dtmf,
    required bool playDtmfTone,
    int dtmfMethod = 0,
    int dtmfDuration = 160,
  }) async {
    throw UnimplementedError('sendDtmf has not been implemented.');
  }

  /// Configures CallKit provider with app name and settings (iOS only).
  ///
  /// On Android, use [configureConnectionService] instead.
  ///
  /// Parameters:
  /// - [appName]: The app name to display in CallKit UI
  /// - [canUseCallKit]: Whether to enable CallKit integration (default: true)
  /// - [iconTemplateImageName]: Optional icon template image name for CallKit UI
  Future<void> configureCallKit({
    required String appName,
    bool canUseCallKit = true,
    String? iconTemplateImageName,
  }) async {
    throw UnimplementedError('configureCallKit has not been implemented.');
  }

  /// Enables or disables CallKit integration at runtime (iOS only).
  ///
  /// On Android, use [enableConnectionService] instead.
  ///
  /// Parameters:
  /// - [enabled]: Whether to enable CallKit
  Future<void> enableCallKit({required bool enabled}) async {
    throw UnimplementedError('enableCallKit has not been implemented.');
  }

  /// Configures ConnectionService with app name and settings (Android only).
  ///
  /// ConnectionService is Android's equivalent to iOS CallKit, providing:
  /// - Native call UI on Android
  /// - Background call protection
  /// - System call management integration
  ///
  /// On iOS, use [configureCallKit] instead.
  ///
  /// Parameters:
  /// - [appName]: The app name to display in the system call UI
  /// - [canUseConnectionService]: Whether to enable ConnectionService (default: true)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> configureConnectionService({
    required String appName,
    bool canUseConnectionService = true,
  }) async {
    throw UnimplementedError('configureConnectionService has not been implemented.');
  }

  /// Enables or disables ConnectionService at runtime (Android only).
  ///
  /// On iOS, use [enableCallKit] instead.
  ///
  /// Parameters:
  /// - [enabled]: Whether to enable ConnectionService
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> enableConnectionService({required bool enabled}) async {
    throw UnimplementedError('enableConnectionService has not been implemented.');
  }

  /// Sets the PortSIP license key.
  ///
  /// This should be called after [initialize] and before [register].
  ///
  /// Parameters:
  /// - [licenseKey]: The PortSIP license key
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> setLicenseKey({required String licenseKey}) async {
    throw UnimplementedError('setLicenseKey has not been implemented.');
  }

  /// Enables or disables plugin debug logging.
  ///
  /// When enabled, logs method calls, responses, and events for debugging.
  /// Default is disabled (false).
  ///
  /// Parameters:
  /// - [enabled]: Whether to enable debug logging
  void setLogsEnabled({required bool enabled}) {
    throw UnimplementedError('setLogsEnabled has not been implemented.');
  }

  /// Configures audio codecs for the SIP session.
  ///
  /// This should be called after [initialize] and before making calls.
  /// The order of codecs in the list determines the preference order.
  ///
  /// Parameters:
  /// - [audioCodecs]: List of audio codecs to enable, in preference order
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> setAudioCodecs({required List<AudioCodec> audioCodecs}) async {
    throw UnimplementedError('setAudioCodecs has not been implemented.');
  }

  /// Enables or disables the audio manager.
  ///
  /// This is critical for DTMF functionality on Android.
  /// Should be called after [register] and before making calls.
  ///
  /// Parameters:
  /// - [enable]: Whether to enable the audio manager (default: true)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> enableAudioManager({required bool enable}) async {
    throw UnimplementedError('enableAudioManager has not been implemented.');
  }

  /// Sets the SRTP (Secure Real-time Transport Protocol) policy.
  ///
  /// Controls how SRTP is used for call encryption.
  /// Should be called after [register] and before making calls.
  ///
  /// Parameters:
  /// - [policy]: SRTP policy value:
  ///   - 0: None (no SRTP, unencrypted RTP)
  ///   - 1: Prefer (prefer SRTP but allow non-SRTP if peer doesn't support it)
  ///   - 2: Force (require SRTP, fail if peer doesn't support it)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> setSrtpPolicy({required int policy}) async {
    throw UnimplementedError('setSrtpPolicy has not been implemented.');
  }

  /// Enables or disables 3GPP tags in SIP messages.
  ///
  /// 3GPP (3rd Generation Partnership Project) tags add additional headers
  /// to SIP messages for compatibility with certain carriers.
  /// Should be called after [register] and before making calls.
  ///
  /// Parameters:
  /// - [enable]: Whether to enable 3GPP tags (default: false)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> enable3GppTags({required bool enable}) async {
    throw UnimplementedError('enable3GppTags has not been implemented.');
  }

  /// Enables or disables Acoustic Echo Cancellation (AEC).
  ///
  /// AEC removes echo from the audio signal caused by speaker-to-microphone
  /// feedback. This is important for preventing the remote party from hearing
  /// their own voice echoed back.
  ///
  /// Parameters:
  /// - [enable]: Whether to enable AEC (default: true)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> enableAEC({required bool enable}) async {
    throw UnimplementedError('enableAEC has not been implemented.');
  }

  /// Enables or disables Automatic Gain Control (AGC).
  ///
  /// AGC automatically adjusts the microphone volume to maintain consistent
  /// audio levels, ensuring the speaker's voice is at an appropriate volume
  /// regardless of their distance from the microphone.
  ///
  /// Parameters:
  /// - [enable]: Whether to enable AGC (default: true)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> enableAGC({required bool enable}) async {
    throw UnimplementedError('enableAGC has not been implemented.');
  }

  /// Enables or disables Comfort Noise Generation (CNG).
  ///
  /// CNG generates artificial background noise during silent periods to avoid
  /// dead silence, which can make users think the connection was lost.
  ///
  /// Parameters:
  /// - [enable]: Whether to enable CNG (default: true)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> enableCNG({required bool enable}) async {
    throw UnimplementedError('enableCNG has not been implemented.');
  }

  /// Enables or disables Voice Activity Detection (VAD).
  ///
  /// VAD detects when speech is present and can be used to reduce bandwidth
  /// by not transmitting audio during silence.
  ///
  /// Parameters:
  /// - [enable]: Whether to enable VAD (default: true)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> enableVAD({required bool enable}) async {
    throw UnimplementedError('enableVAD has not been implemented.');
  }

  /// Enables or disables Automatic Noise Suppression (ANS).
  ///
  /// ANS reduces background noise in the audio signal, improving voice clarity
  /// in noisy environments.
  ///
  /// Parameters:
  /// - [enable]: Whether to enable ANS (default: false)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> enableANS({required bool enable}) async {
    throw UnimplementedError('enableANS has not been implemented.');
  }

  /// Registers with the SIP server.
  ///
  /// This should be called after [register] to complete the server registration.
  /// For P2P mode (when sipServer was empty in [register]), this method is not needed.
  ///
  /// Parameters:
  /// - [registerTimeout]: Registration timeout in seconds (default: 120)
  /// - [registerRetryTimes]: Number of retry attempts on failure (default: 3)
  ///
  /// Returns 0 on success, negative error code on failure.
  Future<int> registerServer({
    int registerTimeout = 120,
    int registerRetryTimes = 3,
  }) async {
    throw UnimplementedError('registerServer has not been implemented.');
  }

  /// Disposes of all SDK resources and cleans up.
  ///
  /// This method should be called when the plugin is no longer needed,
  /// typically when the app is shutting down or the user logs out.
  ///
  /// This method:
  /// - Unregisters from the SIP server
  /// - Removes all observers and listeners
  /// - Releases native SDK resources
  /// - Clears event stream handlers
  ///
  /// After calling dispose(), the plugin instance should not be used.
  /// Create a new instance if SIP functionality is needed again.
  Future<void> dispose() async {
    throw UnimplementedError('dispose has not been implemented.');
  }
}
