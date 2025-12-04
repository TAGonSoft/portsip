import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:portsip/models/audio_codec.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/sip_account.dart';
import 'package:portsip/portsip.dart';

class PortsipRepository {
  static final PortsipRepository _instance = PortsipRepository._internal();
  final Portsip _portsip = Portsip();

  // Track initialization state to prevent re-initialization crashes
  bool _isInitialized = false;

  // Expose singleton
  static PortsipRepository get instance => _instance;

  /// Returns true if the SDK has been initialized
  bool get isInitialized => _isInitialized;

  PortsipRepository._internal();

  /// Expose the typed events stream directly from the plugin.
  /// No need for manual event transformation - the plugin handles it!
  Stream<PortsipEvent> get events => _portsip.typedEvents;

  /// Get the Portsip instance
  Portsip get portsip => _portsip;

  /// Initializes the Portsip package and configures CallKit.
  /// Safe to call multiple times - will skip if already initialized.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('PortsipRepository: SDK already initialized, skipping');
      return;
    }
    _portsip.setLogsEnabled(enabled: true);

    final result = await _portsip.initialize(
      transport: TransportType.udp,
      localIP: '0.0.0.0',
      localSIPPort: 5060,
      logLevel: PortsipLogLevel.debug,
      logFilePath: '',
      maxCallLines: 1,
      sipAgent: 'PortSIP Flutter Example',
      audioDeviceLayer: 0,
      videoDeviceLayer: 0,
      tlsCertificatesRootPath: '',
      tlsCipherList: '',
      verifyTLSCertificate: false,
      dnsServers: '1.1.1.1;8.8.8.8',
    );

    if (result == 0) {
      _isInitialized = true;

      // Set license key after successful initialization
      await _portsip.setLicenseKey(licenseKey: 'PORTSIP-DEMO-KEY');

      // Configure audio processing features (both platforms where available)
      await _portsip.enableCNG(enable: true);
      await _portsip.enableVAD(enable: true);

      if (Platform.isAndroid) {
        await _portsip.enableAudioManager(enable: true);
        await _portsip.enable3GppTags(enable: false);

        // Configure audio processing features (Android only - iOS handles these at system level)
        await _portsip.enableAEC(enable: true);
        await _portsip.enableAGC(enable: true);
        await _portsip.enableANS(enable: false);

        // Configure ConnectionService for Android
        await _configureConnectionService();
      } else {
        // Configure CallKit for iOS
        await _configureCallKit();
      }

      await _portsip.setSrtpPolicy(policy: 0);

      // Configure audio codecs
      // Example: Enable common codecs (PCMU, PCMA, G729)
      await _portsip.setAudioCodecs(
        audioCodecs: [AudioCodec.g729, AudioCodec.dtmf],
      );

      // Note: registerServer() should be called AFTER register() sets user credentials
      // The correct flow is: initialize() → register() → registerServer()
    } else {
      debugPrint(
        'PortsipRepository: Failed to initialize SDK, error code: $result',
      );
    }
  }

  /// Configures CallKit for iOS (no-op on Android)
  Future<void> _configureCallKit() async {
    if (!Platform.isIOS) return;

    try {
      await _portsip.configureCallKit(
        appName: 'Portsip Example',
        canUseCallKit: true,
      );
    } catch (e) {
      debugPrint('PortsipRepository: Failed to configure CallKit: $e');
    }
  }

  /// Configures ConnectionService for Android (no-op on iOS)
  Future<void> _configureConnectionService() async {
    if (!Platform.isAndroid) return;

    try {
      await _portsip.configureConnectionService(
        appName: 'Portsip Example',
        canUseConnectionService: true,
      );
    } catch (e) {
      debugPrint(
        'PortsipRepository: Failed to configure ConnectionService: $e',
      );
    }
  }

  /// Configures the SIP account credentials and server settings.
  ///
  /// Returns 0 if successful, error code otherwise.
  Future<int> register({required SipAccount account}) async {
    return await _portsip.register(account: account);
  }

  /// Register with the SIP server.
  ///
  /// This should be called after register() to complete the server registration.
  /// Returns 0 if successful, error code otherwise.
  Future<int> registerServer({
    int registerTimeout = 120,
    int registerRetryTimes = 3,
  }) async {
    return await _portsip.registerServer(
      registerTimeout: registerTimeout,
      registerRetryTimes: registerRetryTimes,
    );
  }

  /// Unregisters from the SIP server.
  ///
  /// This method unregisters from the SIP server without releasing SDK resources.
  /// Use this when you want to temporarily disconnect from the server.
  Future<void> unRegister() async {
    await _portsip.unRegister();
  }

  // ============== Call Methods ==============

  /// Make an outgoing call.
  ///
  /// Returns the session ID if successful (>= 0), or error code (< 0).
  Future<int> makeCall({
    required String callee,
    required bool sendSdp,
    required bool videoCall,
  }) async {
    return await _portsip.makeCall(
      callee: callee,
      sendSdp: sendSdp,
      videoCall: videoCall,
    );
  }

  /// Hang up a call.
  ///
  /// Returns 0 if successful.
  Future<int> hangUp({required int sessionId}) async {
    return await _portsip.hangUp(sessionId: sessionId);
  }

  /// Put a call on hold.
  ///
  /// Returns 0 if successful.
  Future<int> hold({required int sessionId}) async {
    return await _portsip.hold(sessionId: sessionId);
  }

  /// Resume a call from hold.
  ///
  /// Returns 0 if successful.
  Future<int> unHold({required int sessionId}) async {
    return await _portsip.unHold(sessionId: sessionId);
  }

  /// Mute or unmute a session.
  ///
  /// Returns 0 if successful.
  Future<int> muteSession({
    required int sessionId,
    required bool muteIncomingAudio,
    required bool muteOutgoingAudio,
    required bool muteIncomingVideo,
    required bool muteOutgoingVideo,
  }) async {
    return await _portsip.muteSession(
      sessionId: sessionId,
      muteIncomingAudio: muteIncomingAudio,
      muteOutgoingAudio: muteOutgoingAudio,
      muteIncomingVideo: muteIncomingVideo,
      muteOutgoingVideo: muteOutgoingVideo,
    );
  }

  /// Enable or disable loudspeaker.
  ///
  /// Returns 0 if successful.
  Future<int> setLoudspeakerStatus({required bool enable}) async {
    return await _portsip.setLoudspeakerStatus(enable: enable);
  }

  /// Send DTMF tone.
  ///
  /// Returns 0 if successful.
  Future<int> sendDtmf({
    required int sessionId,
    required int dtmf,
    required bool playDtmfTone,
    int dtmfMethod = 0,
    int dtmfDuration = 160,
  }) async {
    return await _portsip.sendDtmf(
      sessionId: sessionId,
      dtmf: dtmf,
      playDtmfTone: playDtmfTone,
      dtmfMethod: dtmfMethod,
      dtmfDuration: dtmfDuration,
    );
  }

  /// Disposes of the repository and cleans up SDK resources.
  ///
  /// This method should be called when the repository is no longer needed.
  /// After calling dispose(), initialize() can be called again.
  Future<void> dispose() async {
    await _portsip.dispose();
    _isInitialized = false;
  }
}
