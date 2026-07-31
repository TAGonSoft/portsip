import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:portsip/models/audio_codec.dart';
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
    if (!_logsEnabled) return;
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

  /// Unregisters the SIP account from the server. The SDK remains
  /// initialized and the account can be re-registered later.
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
    bool reportToConnectionService = true,
    String? displayName,
  }) async {
    final args = {
      'callee': callee,
      'sendSdp': sendSdp,
      'videoCall': videoCall,
      'reportToConnectionService': reportToConnectionService,
      if (displayName != null) 'displayName': displayName,
    };
    _logCall('makeCall', args);
    try {
      // Use dynamic to handle both Long (Android) and Int (iOS)
      final result = await methodChannel.invokeMethod<dynamic>(
        'makeCall',
        args,
      );
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
  Future<int> hangUp({
    required int sessionId,
    bool reportToConnectionService = true,
  }) async {
    final args = {
      'sessionId': sessionId,
      'reportToConnectionService': reportToConnectionService,
    };
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

  /// Swaps which of two calls is on hold (atomic system-call mirror).
  ///
  /// Invokes the native 'swapHold' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> swapHold({
    required int holdSessionId,
    required int unholdSessionId,
  }) async {
    final args = {
      'holdSessionId': holdSessionId,
      'unholdSessionId': unholdSessionId,
    };
    _logCall('swapHold', args);
    try {
      final result = await methodChannel.invokeMethod<int>('swapHold', args);
      _logResponse('swapHold', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('swapHold', e);
      return -1;
    }
  }

  /// Ends one leg and resumes another atomically (keeps one active system call).
  ///
  /// Invokes the native 'endCallAndResume' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> endCallAndResume({
    required int endSessionId,
    required int resumeSessionId,
  }) async {
    final args = {
      'endSessionId': endSessionId,
      'resumeSessionId': resumeSessionId,
    };
    _logCall('endCallAndResume', args);
    try {
      final result =
          await methodChannel.invokeMethod<int>('endCallAndResume', args);
      _logResponse('endCallAndResume', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('endCallAndResume', e);
      return -1;
    }
  }

  /// Creates an audio conference bridge.
  ///
  /// Invokes the native 'createAudioConference' method via MethodChannel.
  ///
  /// Returns the conference id (>= 0) on success, -1 or error code on failure.
  @override
  Future<int> createAudioConference() async {
    _logCall('createAudioConference');
    try {
      final result = await methodChannel.invokeMethod<int>(
        'createAudioConference',
      );
      _logResponse('createAudioConference', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('createAudioConference', e);
      return -1;
    }
  }

  /// Joins a session into the existing conference.
  ///
  /// Invokes the native 'joinToConference' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> joinToConference({required int sessionId}) async {
    final args = {'sessionId': sessionId};
    _logCall('joinToConference', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'joinToConference',
        args,
      );
      _logResponse('joinToConference', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('joinToConference', e);
      return -1;
    }
  }

  /// Removes a session from the existing conference.
  ///
  /// Invokes the native 'removeFromConference' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> removeFromConference({required int sessionId}) async {
    final args = {'sessionId': sessionId};
    _logCall('removeFromConference', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'removeFromConference',
        args,
      );
      _logResponse('removeFromConference', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('removeFromConference', e);
      return -1;
    }
  }

  /// Destroys the existing conference bridge.
  ///
  /// Invokes the native 'destroyConference' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> destroyConference() async {
    _logCall('destroyConference');
    try {
      final result = await methodChannel.invokeMethod<int>('destroyConference');
      _logResponse('destroyConference', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('destroyConference', e);
      return -1;
    }
  }

  /// Groups the given sessions into one native conference call.
  ///
  /// Invokes the native 'requestCallGroup' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> requestCallGroup({required List<int> sessionIds}) async {
    final args = {'sessionIds': sessionIds};
    _logCall('requestCallGroup', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'requestCallGroup',
        args,
      );
      _logResponse('requestCallGroup', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('requestCallGroup', e);
      return -1;
    }
  }

  /// Collapses a merged conference to a single system call.
  ///
  /// Invokes the native 'reportConferenceMerged' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @Deprecated('Use requestCallGroup for native call grouping.')
  @override
  Future<int> reportConferenceMerged({
    required int primarySessionId,
    required List<int> mergedAwaySessionIds,
  }) async {
    final args = {
      'primarySessionId': primarySessionId,
      'mergedAwaySessionIds': mergedAwaySessionIds,
    };
    _logCall('reportConferenceMerged', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'reportConferenceMerged',
        args,
      );
      _logResponse('reportConferenceMerged', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('reportConferenceMerged', e);
      return -1;
    }
  }

  /// Updates the display name the system call UI shows for a session.
  ///
  /// Invokes the native 'updateOsCallDisplay' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> updateOsCallDisplay({
    required int sessionId,
    required String displayName,
  }) async {
    final args = {'sessionId': sessionId, 'displayName': displayName};
    _logCall('updateOsCallDisplay', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'updateOsCallDisplay',
        args,
      );
      _logResponse('updateOsCallDisplay', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('updateOsCallDisplay', e);
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

  @override
  Future<int> setAudioRoute({required String kind}) async {
    final args = {'kind': kind};
    _logCall('setAudioRoute', args);
    try {
      await methodChannel.invokeMethod<void>('setAudioRoute', args);
      _logResponse('setAudioRoute', 0);
      return 0;
    } on PlatformException catch (e) {
      _logError('setAudioRoute', e);
      return -1;
    } on MissingPluginException {
      // Not implemented on this platform (iOS routes via setLoudspeakerStatus).
      _logResponse('setAudioRoute', -1);
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
      final result = await methodChannel.invokeMethod<int>(
        'configureConnectionService',
        args,
      );
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
      final result = await methodChannel.invokeMethod<int>(
        'enableConnectionService',
        args,
      );
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
      final result = await methodChannel.invokeMethod<int>(
        'setLicenseKey',
        args,
      );
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
      final result = await methodChannel.invokeMethod<int>(
        'setAudioCodecs',
        args,
      );
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
      final result = await methodChannel.invokeMethod<int>(
        'enableAudioManager',
        args,
      );
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
      final result = await methodChannel.invokeMethod<int>(
        'setSrtpPolicy',
        args,
      );
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
      final result = await methodChannel.invokeMethod<int>(
        'enable3GppTags',
        args,
      );
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
      final result = await methodChannel.invokeMethod<int>(
        'registerServer',
        args,
      );
      _logResponse('registerServer', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('registerServer', e);
      return -1;
    }
  }

  /// Refreshes the registration with the SIP server.
  ///
  /// Invokes the native 'refreshRegistration' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> refreshRegistration({int expires = 0}) async {
    final args = {'expires': expires};
    _logCall('refreshRegistration', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'refreshRegistration',
        args,
      );
      _logResponse('refreshRegistration', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('refreshRegistration', e);
      return -1;
    }
  }

  /// Enables SIP session timers (RFC 4028).
  ///
  /// Invokes the native 'enableSessionTimer' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> enableSessionTimer({
    int timerSeconds = 90,
    int refreshMode = 0,
  }) async {
    final args = {'timerSeconds': timerSeconds, 'refreshMode': refreshMode};
    _logCall('enableSessionTimer', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'enableSessionTimer',
        args,
      );
      _logResponse('enableSessionTimer', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('enableSessionTimer', e);
      return -1;
    }
  }

  /// Updates an active call session (sends a re-INVITE).
  ///
  /// Invokes the native 'updateCall' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> updateCall({
    required int sessionId,
    bool enableAudio = true,
    bool enableVideo = false,
  }) async {
    final args = {
      'sessionId': sessionId,
      'enableAudio': enableAudio,
      'enableVideo': enableVideo,
    };
    _logCall('updateCall', args);
    try {
      final result = await methodChannel.invokeMethod<int>('updateCall', args);
      _logResponse('updateCall', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('updateCall', e);
      return -1;
    }
  }

  /// Requests RTP statistics for a session; the result arrives as an
  /// `onStatistics` event on the events stream.
  ///
  /// Invokes the native 'getStatistics' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> getStatistics({required int sessionId}) async {
    final args = {'sessionId': sessionId};
    _logCall('getStatistics', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'getStatistics',
        args,
      );
      _logResponse('getStatistics', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('getStatistics', e);
      return -1;
    }
  }

  /// Starts recording the call on a session.
  ///
  /// Invokes the native 'startRecord' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
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
    final args = {
      'sessionId': sessionId,
      'recordFilePath': recordFilePath,
      'recordFileName': recordFileName,
      'appendTimeStamp': appendTimeStamp,
      'audioChannels': audioChannels,
      'fileFormat': fileFormat.value,
      'audioRecordMode': audioRecordMode.value,
      'videoRecordMode': videoRecordMode.value,
    };
    _logCall('startRecord', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'startRecord',
        args,
      );
      _logResponse('startRecord', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('startRecord', e);
      return -1;
    }
  }

  /// Stops the recording running on a session.
  ///
  /// Invokes the native 'stopRecord' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> stopRecord({required int sessionId}) async {
    final args = {'sessionId': sessionId};
    _logCall('stopRecord', args);
    try {
      final result = await methodChannel.invokeMethod<int>('stopRecord', args);
      _logResponse('stopRecord', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('stopRecord', e);
      return -1;
    }
  }

  /// Plays a file into the stream sent to the remote party.
  ///
  /// Invokes the native 'startPlayingFileToRemote' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> startPlayingFileToRemote({
    required int sessionId,
    required String fileUrl,
    bool loop = false,
    PortsipPlayFileAudioMode playAudio =
        PortsipPlayFileAudioMode.mixedWithMicrophone,
  }) async {
    final args = {
      'sessionId': sessionId,
      'fileUrl': fileUrl,
      'loop': loop,
      'playAudio': playAudio.value,
    };
    _logCall('startPlayingFileToRemote', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'startPlayingFileToRemote',
        args,
      );
      _logResponse('startPlayingFileToRemote', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('startPlayingFileToRemote', e);
      return -1;
    }
  }

  /// Stops the file playback running on a session.
  ///
  /// Invokes the native 'stopPlayingFileToRemote' method via MethodChannel.
  ///
  /// Returns 0 on success, -1 or error code on failure.
  @override
  Future<int> stopPlayingFileToRemote({required int sessionId}) async {
    final args = {'sessionId': sessionId};
    _logCall('stopPlayingFileToRemote', args);
    try {
      final result = await methodChannel.invokeMethod<int>(
        'stopPlayingFileToRemote',
        args,
      );
      _logResponse('stopPlayingFileToRemote', result);
      return result ?? -1;
    } on PlatformException catch (e) {
      _logError('stopPlayingFileToRemote', e);
      return -1;
    }
  }

  /// Tears down the native SDK while keeping the plugin (and its event
  /// stream) alive. Used to swap SIP users at runtime.
  @override
  Future<void> unInitialize() async {
    if (_isDisposed) return;
    _logCall('unInitialize');
    try {
      await methodChannel.invokeMethod<void>('unInitialize');
      _logResponse('unInitialize', 'done');
    } on PlatformException catch (e) {
      _logError('unInitialize', e);
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
