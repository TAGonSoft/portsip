import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:portsip/models/audio_codec.dart';
import 'package:portsip/models/portsip_events.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/sip_account.dart';

import 'portsip_platform_interface.dart';

/// Method channel implementation of [PortsipPlatform].
///
/// This class provides the concrete implementation of the PortSIP platform
/// interface using Flutter's MethodChannel for communication with native
/// iOS and Android code.
///
/// Events from the native side are received via method calls from native
/// to Flutter, which are dispatched via a broadcast [StreamController] to
/// allow multiple listeners.
class MethodChannelPortsip extends PortsipPlatform {
  /// Creates a new [MethodChannelPortsip] instance.
  ///
  /// The method call handler is initialized eagerly during construction
  /// to avoid race conditions with lazy initialization.
  MethodChannelPortsip() {
    _initializeHandler();
  }

  /// The method channel used to interact with the native platform.
  ///
  /// Channel name: "portsip"
  @visibleForTesting
  final methodChannel = const MethodChannel('portsip');

  /// Log tag for debug output
  static const String _tag = '[PortSIP]';

  /// Flag to enable/disable debug logging (default: false)
  bool _logsEnabled = false;

  /// Broadcast stream controller for PortSIP events.
  ///
  /// Uses broadcast stream to allow multiple listeners.
  /// Initialized once during construction via [_initializeHandler].
  late final StreamController<PortsipEvent> _eventController;

  /// Whether the plugin has been disposed.
  bool _isDisposed = false;

  /// Helper to log method calls
  void _logCall(String method, [Map<String, dynamic>? args]) {
    if (!_logsEnabled) return;
    debugPrint('$_tag ▶ $method${args != null ? ' | args: $args' : ''}');
  }

  /// Helper to log method responses
  void _logResponse(String method, dynamic result) {
    if (!_logsEnabled) return;
    final status = (result is int && result < 0) ? '❌' : '✓';
    debugPrint('$_tag ◀ $method | $status result: $result');
  }

  /// Helper to log events from native
  void _logEvent(String event, Map<String, dynamic>? data) {
    if (!_logsEnabled) return;
    debugPrint('$_tag ⚡ EVENT: $event${data != null ? ' | data: $data' : ''}');
  }

  /// Helper to log errors from platform exceptions
  void _logError(String method, PlatformException e) {
    debugPrint('$_tag ❌ $method | PlatformException: ${e.code} - ${e.message}');
  }

  /// Enables or disables debug logging for the plugin.
  @override
  void setLogsEnabled({required bool enabled}) {
    _logsEnabled = enabled;
    try {
      methodChannel.invokeMethod<void>('setLogsEnabled', {'enabled': enabled});
    } on PlatformException catch (e) {
      _logError('setLogsEnabled', e);
    }
  }

  /// Initializes the method call handler and creates the broadcast stream.
  ///
  /// Called once during construction to ensure thread-safe initialization.
  void _initializeHandler() {
    _eventController = StreamController<PortsipEvent>.broadcast();

    methodChannel.setMethodCallHandler((call) async {
      if (_isDisposed) return;

      final args = call.arguments;
      Map<String, dynamic>? castedArgs;
      if (args is Map) {
        castedArgs = Map<String, dynamic>.from(args);
      }

      _logEvent(call.method, castedArgs);
      _eventController.add(PortsipEvent(call.method, castedArgs));
    });
  }

  /// Returns a broadcast stream of PortSIP SDK events.
  ///
  /// This stream can have multiple listeners. Each listener receives all
  /// events from the native side (iOS/Android).
  ///
  /// Example:
  /// ```dart
  /// final subscription = platform.events.listen((event) {
  ///   print('Event: ${event.name}, Data: ${event.data}');
  /// });
  /// ```
  @override
  Stream<PortsipEvent> get events => _eventController.stream;

  /// Initializes the PortSIP SDK with the provided configuration.
  ///
  /// Invokes the native 'initialize' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
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
    final args = {
      'transport': transport.value,
      'localIP': localIP,
      'localSIPPort': localSIPPort,
      'logLevel': logLevel.value,
      'logFilePath': logFilePath,
      'maxCallLines': maxCallLines,
      'sipAgent': sipAgent,
      'audioDeviceLayer': audioDeviceLayer,
      'videoDeviceLayer': videoDeviceLayer,
      'tlsCertificatesRootPath': tlsCertificatesRootPath,
      'tlsCipherList': tlsCipherList,
      'verifyTLSCertificate': verifyTLSCertificate,
      'dnsServers': dnsServers,
      'ptime': ptime,
      'maxPtime': maxPtime,
    };
    _logCall('initialize', args);
    try {
      final result = await methodChannel.invokeMethod<int>('initialize', args);
      _logResponse('initialize', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('initialize', e);
      return -1;
    }
  }

  /// Configures SIP account credentials and server settings.
  ///
  /// Invokes the native 'register' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> register({required SipAccount account}) async {
    final args = account.toMap();
    _logCall('register', args);
    try {
      final result = await methodChannel.invokeMethod<int>('register', args);
      _logResponse('register', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('register', e);
      return -1;
    }
  }

  /// Unregisters from SIP server and releases resources.
  ///
  /// Invokes the native 'unRegister' method via MethodChannel.
  @override
  Future<void> unRegister() async {
    _logCall('unRegister');
    try {
      await methodChannel.invokeMethod<void>('unRegister');
      _logResponse('unRegister', 'done');
    } on PlatformException catch (e) {
      _logError('unRegister', e);
    }
  }

  /// Initiates an outgoing call.
  ///
  /// Invokes the native 'makeCall' method via MethodChannel.
  ///
  /// Returns session ID on success, -1 or error code on failure.
  /// Note: Android returns Long (64-bit), iOS returns Int. We use dynamic
  /// to handle both and convert to Dart int.
  @override
  Future<int> makeCall({
    required String callee,
    required bool sendSdp,
    required bool videoCall,
  }) async {
    final args = {
      'callee': callee,
      'sendSdp': sendSdp,
      'videoCall': videoCall,
    };
    _logCall('makeCall', args);
    try {
      // Use dynamic to handle both Long (Android) and Int (iOS)
      final result = await methodChannel.invokeMethod<dynamic>('makeCall', args);
      final sessionId = (result as num?)?.toInt() ?? -1;
      _logResponse('makeCall', sessionId);
      return sessionId;
    } on PlatformException catch (e) {
      _logError('makeCall', e);
      return -1;
    }
  }

  /// Terminates an active call.
  ///
  /// Invokes the native 'hangUp' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> hangUp({required int sessionId}) async {
    final args = {'sessionId': sessionId};
    _logCall('hangUp', args);
    try {
      final result = await methodChannel.invokeMethod<int>('hangUp', args);
      _logResponse('hangUp', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('hangUp', e);
      return -1;
    }
  }

  /// Puts a call on hold.
  ///
  /// Invokes the native 'hold' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> hold({required int sessionId}) async {
    final args = {'sessionId': sessionId};
    _logCall('hold', args);
    try {
      final result = await methodChannel.invokeMethod<int>('hold', args);
      _logResponse('hold', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('hold', e);
      return -1;
    }
  }

  /// Resumes a held call.
  ///
  /// Invokes the native 'unHold' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> unHold({required int sessionId}) async {
    final args = {'sessionId': sessionId};
    _logCall('unHold', args);
    try {
      final result = await methodChannel.invokeMethod<int>('unHold', args);
      _logResponse('unHold', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('unHold', e);
      return -1;
    }
  }

  /// Mutes or unmutes audio/video streams.
  ///
  /// Invokes the native 'muteSession' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> muteSession({
    required int sessionId,
    required bool muteIncomingAudio,
    required bool muteOutgoingAudio,
    required bool muteIncomingVideo,
    required bool muteOutgoingVideo,
  }) async {
    final args = {
      'sessionId': sessionId,
      'muteIncomingAudio': muteIncomingAudio,
      'muteOutgoingAudio': muteOutgoingAudio,
      'muteIncomingVideo': muteIncomingVideo,
      'muteOutgoingVideo': muteOutgoingVideo,
    };
    _logCall('muteSession', args);
    try {
      final result = await methodChannel.invokeMethod<int>('muteSession', args);
      _logResponse('muteSession', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('muteSession', e);
      return -1;
    }
  }

  /// Enables or disables loudspeaker.
  ///
  /// Invokes the native 'setLoudspeakerStatus' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 on failure.
  @override
  Future<int> setLoudspeakerStatus({required bool enable}) async {
    final args = {'enable': enable};
    _logCall('setLoudspeakerStatus', args);
    try {
      await methodChannel.invokeMethod<void>('setLoudspeakerStatus', args);
      _logResponse('setLoudspeakerStatus', 0);
      return 0;
    } on PlatformException catch (e) {
      _logError('setLoudspeakerStatus', e);
      return -1;
    }
  }

  /// Sends a DTMF tone during an active call.
  ///
  /// Invokes the native 'sendDtmf' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> sendDtmf({
    required int sessionId,
    required int dtmf,
    required bool playDtmfTone,
    int dtmfMethod = 0,
    int dtmfDuration = 160,
  }) async {
    final args = {
      'sessionId': sessionId,
      'dtmf': dtmf,
      'playDtmfTone': playDtmfTone,
      'dtmfMethod': dtmfMethod,
      'dtmfDuration': dtmfDuration,
    };
    _logCall('sendDtmf', args);
    try {
      final result = await methodChannel.invokeMethod<int>('sendDtmf', args);
      _logResponse('sendDtmf', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('sendDtmf', e);
      return -1;
    }
  }

  /// Configures CallKit provider (iOS only).
  ///
  /// Invokes the native 'configureCallKit' method via MethodChannel.
  /// On Android, this is a no-op.
  @override
  Future<void> configureCallKit({
    required String appName,
    bool canUseCallKit = true,
    String? iconTemplateImageName,
  }) async {
    final args = {
      'appName': appName,
      'canUseCallKit': canUseCallKit,
      if (iconTemplateImageName != null)
        'iconTemplateImageName': iconTemplateImageName,
    };
    _logCall('configureCallKit', args);
    try {
      await methodChannel.invokeMethod<void>('configureCallKit', args);
      _logResponse('configureCallKit', 'done');
    } on PlatformException catch (e) {
      _logError('configureCallKit', e);
    }
  }

  /// Enables or disables CallKit at runtime (iOS only).
  ///
  /// Invokes the native 'enableCallKit' method via MethodChannel.
  /// On Android, this is a no-op.
  @override
  Future<void> enableCallKit({required bool enabled}) async {
    final args = {'enabled': enabled};
    _logCall('enableCallKit', args);
    try {
      await methodChannel.invokeMethod<void>('enableCallKit', args);
      _logResponse('enableCallKit', 'done');
    } on PlatformException catch (e) {
      _logError('enableCallKit', e);
    }
  }

  /// Configures ConnectionService with app name and settings (Android only).
  ///
  /// ConnectionService is Android's equivalent to iOS CallKit, providing:
  /// - Native call UI on Android
  /// - Background call protection
  /// - System call management integration
  ///
  /// Invokes the native 'configureConnectionService' method via MethodChannel.
  /// On iOS, this is a no-op.
  ///
  /// Returns 0 on success, -1 on failure.
  @override
  Future<int> configureConnectionService({
    required String appName,
    bool canUseConnectionService = true,
  }) async {
    final args = {
      'appName': appName,
      'canUseConnectionService': canUseConnectionService,
    };
    _logCall('configureConnectionService', args);
    try {
      final result = await methodChannel.invokeMethod<int>('configureConnectionService', args);
      _logResponse('configureConnectionService', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('configureConnectionService', e);
      return -1;
    }
  }

  /// Enables or disables ConnectionService at runtime (Android only).
  ///
  /// Invokes the native 'enableConnectionService' method via MethodChannel.
  /// On iOS, this is a no-op.
  ///
  /// Returns 0 on success, -1 on failure.
  @override
  Future<int> enableConnectionService({required bool enabled}) async {
    final args = {'enabled': enabled};
    _logCall('enableConnectionService', args);
    try {
      final result = await methodChannel.invokeMethod<int>('enableConnectionService', args);
      _logResponse('enableConnectionService', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enableConnectionService', e);
      return -1;
    }
  }

  /// Sets the PortSIP license key.
  ///
  /// Invokes the native 'setLicenseKey' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> setLicenseKey({required String licenseKey}) async {
    final args = {'licenseKey': licenseKey};
    _logCall('setLicenseKey', args);
    try {
      final result = await methodChannel.invokeMethod<int>('setLicenseKey', args);
      _logResponse('setLicenseKey', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('setLicenseKey', e);
      return -1;
    }
  }

  /// Configures audio codecs for the SIP session.
  ///
  /// Invokes the native 'setAudioCodecs' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> setAudioCodecs({required List<AudioCodec> audioCodecs}) async {
    final args = {
      'audioCodecs': audioCodecs.map((codec) => codec.value).toList(),
    };
    _logCall('setAudioCodecs', args);
    try {
      final result = await methodChannel.invokeMethod<int>('setAudioCodecs', args);
      _logResponse('setAudioCodecs', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('setAudioCodecs', e);
      return -1;
    }
  }

  /// Enables or disables the audio manager.
  ///
  /// Invokes the native 'enableAudioManager' method via MethodChannel.
  /// This is critical for DTMF functionality on Android.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> enableAudioManager({required bool enable}) async {
    final args = {'enable': enable};
    _logCall('enableAudioManager', args);
    try {
      final result = await methodChannel.invokeMethod<int>('enableAudioManager', args);
      _logResponse('enableAudioManager', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enableAudioManager', e);
      return -1;
    }
  }

  /// Sets the SRTP (Secure Real-time Transport Protocol) policy.
  ///
  /// Invokes the native 'setSrtpPolicy' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> setSrtpPolicy({required int policy}) async {
    final args = {'policy': policy};
    _logCall('setSrtpPolicy', args);
    try {
      final result = await methodChannel.invokeMethod<int>('setSrtpPolicy', args);
      _logResponse('setSrtpPolicy', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('setSrtpPolicy', e);
      return -1;
    }
  }

  /// Enables or disables 3GPP tags in SIP messages.
  ///
  /// Invokes the native 'enable3GppTags' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> enable3GppTags({required bool enable}) async {
    final args = {'enable': enable};
    _logCall('enable3GppTags', args);
    try {
      final result = await methodChannel.invokeMethod<int>('enable3GppTags', args);
      _logResponse('enable3GppTags', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enable3GppTags', e);
      return -1;
    }
  }

  /// Enables or disables Acoustic Echo Cancellation (AEC).
  ///
  /// **Android only** - On iOS, this returns 0 without invoking native code
  /// as iOS handles AEC at the system level via AVAudioSession.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> enableAEC({required bool enable}) async {
    // Only call native method on Android - iOS doesn't expose this in the SDK
    if (!Platform.isAndroid) {
      _logCall('enableAEC (skipped on iOS)', {'enable': enable});
      return 0;
    }
    final args = {'enable': enable};
    _logCall('enableAEC', args);
    try {
      final result = await methodChannel.invokeMethod<int>('enableAEC', args);
      _logResponse('enableAEC', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enableAEC', e);
      return -1;
    }
  }

  /// Enables or disables Automatic Gain Control (AGC).
  ///
  /// **Android only** - On iOS, this returns 0 without invoking native code
  /// as iOS handles AGC at the system level via AVAudioSession.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> enableAGC({required bool enable}) async {
    // Only call native method on Android - iOS doesn't expose this in the SDK
    if (!Platform.isAndroid) {
      _logCall('enableAGC (skipped on iOS)', {'enable': enable});
      return 0;
    }
    final args = {'enable': enable};
    _logCall('enableAGC', args);
    try {
      final result = await methodChannel.invokeMethod<int>('enableAGC', args);
      _logResponse('enableAGC', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enableAGC', e);
      return -1;
    }
  }

  /// Enables or disables Comfort Noise Generation (CNG).
  ///
  /// Invokes the native 'enableCNG' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> enableCNG({required bool enable}) async {
    final args = {'enable': enable};
    _logCall('enableCNG', args);
    try {
      final result = await methodChannel.invokeMethod<int>('enableCNG', args);
      _logResponse('enableCNG', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enableCNG', e);
      return -1;
    }
  }

  /// Enables or disables Voice Activity Detection (VAD).
  ///
  /// Invokes the native 'enableVAD' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> enableVAD({required bool enable}) async {
    final args = {'enable': enable};
    _logCall('enableVAD', args);
    try {
      final result = await methodChannel.invokeMethod<int>('enableVAD', args);
      _logResponse('enableVAD', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enableVAD', e);
      return -1;
    }
  }

  /// Enables or disables Automatic Noise Suppression (ANS).
  ///
  /// **Android only** - On iOS, this returns 0 without invoking native code
  /// as the PortSIP iOS SDK does not expose this method.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> enableANS({required bool enable}) async {
    // Only call native method on Android - iOS doesn't expose this in the SDK
    if (!Platform.isAndroid) {
      _logCall('enableANS (skipped on iOS)', {'enable': enable});
      return 0;
    }
    final args = {'enable': enable};
    _logCall('enableANS', args);
    try {
      final result = await methodChannel.invokeMethod<int>('enableANS', args);
      _logResponse('enableANS', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enableANS', e);
      return -1;
    }
  }

  /// Registers with the SIP server.
  ///
  /// Invokes the native 'registerServer' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> registerServer({
    int registerTimeout = 120,
    int registerRetryTimes = 3,
  }) async {
    final args = {
      'registerTimeout': registerTimeout,
      'registerRetryTimes': registerRetryTimes,
    };
    _logCall('registerServer', args);
    try {
      final result = await methodChannel.invokeMethod<int>('registerServer', args);
      _logResponse('registerServer', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('registerServer', e);
      return -1;
    }
  }

  /// Disposes of all SDK resources and cleans up.
  ///
  /// Invokes the native 'dispose' method via MethodChannel.
  /// This clears the method call handler and closes the event stream
  /// to prevent memory leaks.
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _logCall('dispose');
    try {
      // Clear the method call handler to stop receiving events
      methodChannel.setMethodCallHandler(null);

      // Close the event stream controller
      await _eventController.close();

      // Call native dispose
      await methodChannel.invokeMethod<void>('dispose');
      _logResponse('dispose', 'done');
    } on PlatformException catch (e) {
      _logError('dispose', e);
    }
  }
}
