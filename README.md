# PortSIP Flutter Plugin

A Flutter plugin that integrates the [PortSIP VoIP SDK](https://www.portsip.com/download-portsip-voip-sdk/), enabling SIP-based voice communications in your Flutter applications.

This plugin provides a cross-platform Dart API built on top of the native PortSIP SDK for iOS and Android, simplifying VoIP integration in Flutter apps.

The PortSIP SDK binaries (V19.6.0) are **included with this plugin** - no manual SDK download required.

## Resources

- [PortSIP VoIP SDK](https://www.portsip.com/download-portsip-voip-sdk/)
- [PortSIP SDK Documentation](https://support.portsip.com/development-portsip/getting-started)

## Features

- **SIP Registration** - Register and authenticate with SIP servers
- **Outgoing Voice Calls** - Make and manage outgoing audio calls
- **Call Controls** - Hold, mute, DTMF tones, loudspeaker toggle
- **Audio Codecs** - Configure preferred audio codecs (OPUS, G.722, G.729, etc.)
- **Audio Processing** - AEC, AGC, ANS, CNG, VAD for enhanced audio quality
- **SRTP Encryption** - Configurable secure RTP policy for encrypted calls
- **iOS CallKit** - Native iOS call UI integration
- **Android ConnectionService** - Native Android call UI integration (system call screen)
- **Real-time Events** - Stream-based event handling with typed event classes
- **Lifecycle Management** - SDK state tracking with proper initialization/disposal

> **Note:** The current version supports **outgoing calls only**. Incoming call support is planned for a future release.

## Platform Support

| Platform | Minimum Version |
|----------|-----------------|
| Android  | API 24+         |
| iOS      | 13.0+           |

## Installation

Add `portsip` to your `pubspec.yaml`:

```yaml
dependencies:
  portsip: ^0.0.1
```

### iOS Setup

Add the following permissions to your `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Required for voice calls</string>
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>audio</string>
</array>
```

### Android Setup

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Required for ConnectionService (native call UI) -->
<uses-permission android:name="android.permission.MANAGE_OWN_CALLS" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_PHONE_CALL" />
```

## Quick Start

### Import

```dart
import 'package:portsip/portsip.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/sip_account.dart';
import 'package:portsip/models/audio_codec.dart';
```

### Initialize and Register

```dart
final portsip = Portsip();

// 1. Initialize SDK
await portsip.initialize(
  transport: TransportType.udp,
  localIP: "0.0.0.0",
  localSIPPort: 5060,
  logLevel: PortsipLogLevel.debug,
  logFilePath: "",
  maxCallLines: 5,
  sipAgent: "Flutter PortSIP Client",
  audioDeviceLayer: 0,
  videoDeviceLayer: 0,
  tlsCertificatesRootPath: "",
  tlsCipherList: "",
  verifyTLSCertificate: false,
  dnsServers: "",
);

// 2. Set license key (optional - you can test without a license)
await portsip.setLicenseKey(licenseKey: "your-license-key");

// 3. Configure audio processing (optional)
await portsip.enableCNG(enable: true);  // Comfort Noise Generation
await portsip.enableVAD(enable: true);  // Voice Activity Detection

// On Android only:
await portsip.enableAEC(enable: true);  // Echo Cancellation
await portsip.enableAGC(enable: true);  // Automatic Gain Control
await portsip.enableAudioManager(enable: true);  // Required for DTMF

// 4. Configure SRTP policy (0=None, 1=Prefer, 2=Force)
await portsip.setSrtpPolicy(policy: 0);

// 5. Configure audio codecs
await portsip.setAudioCodecs(audioCodecs: [
  AudioCodec.opus,
  AudioCodec.g722,
  AudioCodec.pcmu,
]);

// 6. Configure SIP account
await portsip.register(
  account: SipAccount(
    username: "1001",
    displayName: "John Doe",
    authName: "1001",
    password: "secret",
    domain: "sip.example.com",
    serverAddress: "sip.example.com",
    serverPort: 5060,
  ),
);

// 7. Connect to server
await portsip.registerServer();
```

## Complete Outgoing Call Example

Here's a complete example showing how to make and manage outgoing calls using typed events:

```dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:portsip/portsip.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/sip_account.dart';
import 'package:portsip/models/audio_codec.dart';

class CallManager {
  final _portsip = Portsip();
  StreamSubscription<PortsipEvent>? _eventSubscription;
  int? _currentSessionId;
  bool _isRegistered = false;

  /// Initialize SDK and register with SIP server
  Future<void> initialize() async {
    // Setup event listener first
    _setupEventListener();

    // Initialize SDK
    final initResult = await _portsip.initialize(
      transport: TransportType.udp,
      localIP: "0.0.0.0",
      localSIPPort: 5060,
      logLevel: PortsipLogLevel.debug,
      logFilePath: "",
      maxCallLines: 5,
      sipAgent: "My VoIP App",
      audioDeviceLayer: 0,
      videoDeviceLayer: 0,
      tlsCertificatesRootPath: "",
      tlsCipherList: "",
      verifyTLSCertificate: false,
      dnsServers: "1.1.1.1;8.8.8.8",
    );

    if (initResult != 0) {
      throw Exception('Failed to initialize SDK: $initResult');
    }

    // Set license (optional - you can test without a license)
    await _portsip.setLicenseKey(licenseKey: "YOUR_LICENSE_KEY");

    // Configure audio processing
    await _portsip.enableCNG(enable: true);
    await _portsip.enableVAD(enable: true);

    if (Platform.isAndroid) {
      await _portsip.enableAEC(enable: true);
      await _portsip.enableAGC(enable: true);
      await _portsip.enableAudioManager(enable: true);
    }

    // Configure SRTP policy (0=None, 1=Prefer, 2=Force)
    await _portsip.setSrtpPolicy(policy: 0);

    // Configure codecs
    await _portsip.setAudioCodecs(audioCodecs: [
      AudioCodec.opus,
      AudioCodec.g722,
      AudioCodec.pcmu,
      AudioCodec.pcma,
    ]);

    // Configure account
    await _portsip.register(
      account: SipAccount(
        username: "1001",
        displayName: "User 1001",
        authName: "1001",
        password: "password123",
        domain: "sip.example.com",
        serverAddress: "sip.example.com",
        serverPort: 5060,
      ),
    );

    // Register with server
    await _portsip.registerServer();
  }

  /// Setup event listener using typed events for type-safe handling
  void _setupEventListener() {
    _eventSubscription = _portsip.typedEvents.listen((event) {
      switch (event) {
        // Registration events
        case RegisterSuccessEvent():
          _isRegistered = true;
          debugPrint('Registered successfully');
          break;

        case RegisterFailureEvent():
          _isRegistered = false;
          debugPrint('Registration failed: ${event.statusCode} - ${event.statusText}');
          break;

        // Outgoing call progress
        case InviteTryingEvent():
          debugPrint('Call is trying...');
          break;

        case InviteRingingEvent():
          debugPrint('Remote is ringing...');
          break;

        // Call connected
        case InviteAnsweredEvent():
        case InviteConnectedEvent():
          debugPrint('Call connected');
          break;

        // Call ended
        case InviteClosedEvent():
          debugPrint('Call ended');
          _currentSessionId = null;
          break;

        case InviteFailureEvent():
          debugPrint('Call failed: ${event.reason} (${event.code})');
          _currentSessionId = null;
          break;

        // Remote hold/unhold
        case RemoteHoldEvent():
          debugPrint('Remote put call on hold');
          break;

        case RemoteUnHoldEvent():
          debugPrint('Remote resumed call');
          break;

        default:
          debugPrint('Unhandled event: ${event.name}');
      }
    });
  }

  /// Make an outgoing call
  Future<void> makeCall(String number) async {
    if (!_isRegistered) {
      throw Exception('Not registered with SIP server');
    }

    final sessionId = await _portsip.makeCall(
      callee: number, // e.g., "1002" or "sip:1002@sip.example.com"
      sendSdp: true,
      videoCall: false,
    );

    if (sessionId >= 0) {
      _currentSessionId = sessionId;
      debugPrint('Call initiated with session ID: $sessionId');
    } else {
      throw Exception('Failed to make call: $sessionId');
    }
  }

  /// Hang up the current call
  Future<void> hangUp() async {
    if (_currentSessionId == null) return;

    await _portsip.hangUp(sessionId: _currentSessionId!);
    _currentSessionId = null;
  }

  /// Hold the current call
  Future<void> hold() async {
    if (_currentSessionId == null) return;
    await _portsip.hold(sessionId: _currentSessionId!);
  }

  /// Resume a held call
  Future<void> unhold() async {
    if (_currentSessionId == null) return;
    await _portsip.unHold(sessionId: _currentSessionId!);
  }

  /// Mute/unmute microphone
  Future<void> setMuted(bool muted) async {
    if (_currentSessionId == null) return;

    await _portsip.muteSession(
      sessionId: _currentSessionId!,
      muteIncomingAudio: false,
      muteOutgoingAudio: muted,
      muteIncomingVideo: false,
      muteOutgoingVideo: false,
    );
  }

  /// Toggle loudspeaker
  Future<void> setSpeaker(bool enabled) async {
    await _portsip.setLoudspeakerStatus(enable: enabled);
  }

  /// Send DTMF tone (0-9, *, #)
  Future<void> sendDtmf(int digit) async {
    if (_currentSessionId == null) return;

    await _portsip.sendDtmf(
      sessionId: _currentSessionId!,
      dtmf: digit,
      playDtmfTone: true,
    );
  }

  /// Cleanup resources
  Future<void> dispose() async {
    if (_currentSessionId != null) {
      await hangUp();
    }
    await _eventSubscription?.cancel();
    await _portsip.dispose();
  }
}
```

### Usage

```dart
final callManager = CallManager();

// Initialize and register
await callManager.initialize();

// Make a call
await callManager.makeCall("1002");

// During call controls
await callManager.setMuted(true);      // Mute microphone
await callManager.setSpeaker(true);    // Enable loudspeaker
await callManager.sendDtmf(1);         // Send DTMF "1"
await callManager.hold();              // Hold call
await callManager.unhold();            // Resume call

// End call
await callManager.hangUp();

// Cleanup when done
await callManager.dispose();
```

## iOS CallKit Integration

Configure CallKit for native iOS call UI:

```dart
// Configure CallKit
await portsip.configureCallKit(
  appName: "My App",
  canUseCallKit: true,
  iconTemplateImageName: "CallKitIcon", // Optional: 40x40 PNG in Assets
);

// Enable/disable CallKit at runtime
await portsip.enableCallKit(enabled: true);
```

### CallKit Events

| Event | Data | Description |
|-------|------|-------------|
| `onCallKitHold` | `sessionId`, `isHold` | User toggled hold from CallKit UI |
| `onCallKitMute` | `sessionId`, `isMuted` | User toggled mute from CallKit UI |
| `onCallKitSpeaker` | `sessionId`, `isSpeaker` | User toggled speaker from CallKit UI |
| `onCallKitDTMF` | `sessionId`, `digit` | User sent DTMF from CallKit UI |
| `onCallKitFailure` | `sessionId`, `reason` | CallKit failed (call auto-terminated) |

## Android ConnectionService Integration

ConnectionService is Android's equivalent to iOS CallKit, providing native call UI on Android devices:

```dart
// Configure ConnectionService (call during app initialization)
await portsip.configureConnectionService(
  appName: "My VoIP App",
  canUseConnectionService: true,
);

// Enable/disable ConnectionService at runtime
await portsip.enableConnectionService(enabled: true);
```

### ConnectionService Events

| Event | Data | Description |
|-------|------|-------------|
| `onConnectionServiceEndCall` | `sessionId` | User ended call from system UI |
| `onConnectionServiceHold` | `sessionId`, `isHold` | User toggled hold from system UI |
| `onConnectionServiceMute` | `sessionId`, `isMuted` | User toggled mute from system UI |
| `onConnectionServiceSpeaker` | `sessionId`, `isSpeaker` | User toggled speaker from system UI |
| `onConnectionServiceDTMF` | `sessionId`, `digit` | User sent DTMF from system UI |
| `onConnectionServiceFailure` | `reason` | ConnectionService operation failed |

## Audio Processing

The plugin provides audio processing features to enhance call quality:

| Method | Platform | Description |
|--------|----------|-------------|
| `enableAEC` | Android | Acoustic Echo Cancellation - removes echo from speaker-to-mic feedback |
| `enableAGC` | Android | Automatic Gain Control - maintains consistent audio levels |
| `enableANS` | Android | Automatic Noise Suppression - reduces background noise |
| `enableCNG` | Both | Comfort Noise Generation - generates background noise during silence |
| `enableVAD` | Both | Voice Activity Detection - detects speech to reduce bandwidth |
| `enableAudioManager` | Android | Required for DTMF functionality |
| `setSrtpPolicy` | Both | SRTP encryption: 0=None, 1=Prefer, 2=Force |
| `enable3GppTags` | Both | 3GPP headers for carrier compatibility |

> **Note:** On iOS, AEC/AGC/ANS are handled at the system level via AVAudioSession.

```dart
// Configure audio processing after initialize()
await portsip.enableCNG(enable: true);
await portsip.enableVAD(enable: true);
await portsip.setSrtpPolicy(policy: 1); // Prefer SRTP

// Android-specific
if (Platform.isAndroid) {
  await portsip.enableAEC(enable: true);
  await portsip.enableAGC(enable: true);
  await portsip.enableAudioManager(enable: true);
}
```

## Events Reference

The plugin supports two event streams:
- `events` - Raw events with `name` and `data` fields
- `typedEvents` - Strongly-typed event classes for pattern matching

### Using Typed Events (Recommended)

```dart
portsip.typedEvents.listen((event) {
  switch (event) {
    case RegisterSuccessEvent():
      print('Registered: ${event.statusCode}');
    case InviteConnectedEvent():
      print('Call connected: ${event.sessionId}');
    case InviteFailureEvent():
      print('Call failed: ${event.reason}');
    default:
      print('Event: ${event.name}');
  }
});
```

### Registration Events

| Event | Typed Class | Data |
|-------|-------------|------|
| `onRegisterSuccess` | `RegisterSuccessEvent` | `statusCode`, `statusText` |
| `onRegisterFailure` | `RegisterFailureEvent` | `statusCode`, `statusText` |

### Call Events

| Event | Typed Class | Data |
|-------|-------------|------|
| `onInviteTrying` | `InviteTryingEvent` | `sessionId` |
| `onInviteRinging` | `InviteRingingEvent` | `sessionId`, `statusCode`, `statusText` |
| `onInviteAnswered` | `InviteAnsweredEvent` | `sessionId` |
| `onInviteConnected` | `InviteConnectedEvent` | `sessionId` |
| `onInviteClosed` | `InviteClosedEvent` | `sessionId` |
| `onInviteFailure` | `InviteFailureEvent` | `sessionId`, `code`, `reason` |

### Hold Events

| Event | Typed Class | Data |
|-------|-------------|------|
| `onRemoteHold` | `RemoteHoldEvent` | `sessionId` |
| `onRemoteUnHold` | `RemoteUnHoldEvent` | `sessionId` |

## Audio Codecs

| Codec | Type | Enum Value |
|-------|------|------------|
| G.711 μ-law | Narrowband | `AudioCodec.pcmu` |
| G.711 A-law | Narrowband | `AudioCodec.pcma` |
| G.723 | Narrowband | `AudioCodec.g723` |
| GSM | Narrowband | `AudioCodec.gsm` |
| G.729 | Narrowband | `AudioCodec.g729` |
| iLBC | Narrowband | `AudioCodec.ilbc` |
| Speex | Narrowband | `AudioCodec.speex` |
| AMR | Narrowband | `AudioCodec.amr` |
| G.722 | Wideband | `AudioCodec.g722` |
| Speex WB | Wideband | `AudioCodec.speexWb` |
| ISAC WB | Wideband | `AudioCodec.isacWb` |
| AMR-WB | Wideband | `AudioCodec.amrWb` |
| OPUS | Wideband | `AudioCodec.opus` |
| ISAC SWB | Super-wideband | `AudioCodec.isacSwb` |
| DTMF | RFC 2833 | `AudioCodec.dtmf` |

## Example App

See the [example](example/) directory for a complete sample application demonstrating:

- **Full registration flow** with timeout handling
- **Outgoing call management** with call duration timer
- **Call controls UI** (hold, mute, speaker, DTMF keypad)
- **BLoC/Cubit state management** pattern
- **Typed event handling** for both CallKit (iOS) and ConnectionService (Android)

### Example App Architecture

```
example/lib/
├── main.dart                           # App entry point
├── router.dart                         # Navigation setup
├── tab_bar_container.dart              # Tab navigation
└── portsip/
    ├── repository/
    │   └── portsip_repository.dart     # Singleton SDK lifecycle manager
    └── pages/
        ├── connection/
        │   ├── connection_page.dart    # Registration UI
        │   ├── connection_cubit.dart   # Registration state management
        │   └── connection_state.dart   # Registration state model
        └── call/
            ├── call_page.dart          # Call UI with controls
            ├── call_cubit.dart         # Call state management
            └── call_state.dart         # Call state model
```

### Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Error Codes

### SIP Response Codes

| Code | Description |
|------|-------------|
| 200 | OK - Request succeeded |
| 401 | Unauthorized - Authentication required |
| 403 | Forbidden - Server refusing request |
| 404 | Not Found - User does not exist |
| 408 | Request Timeout |
| 480 | Temporarily Unavailable |
| 486 | Busy Here - Callee is busy |
| 487 | Request Terminated - Call cancelled |
| 503 | Service Unavailable |
| 603 | Decline - Callee declined |

### SDK Error Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| -1 | General error / Invalid parameter |
| -2 | SDK not initialized |
| -3 | Invalid session ID |
| -11 | No available call line |

## SDK Lifecycle Management

The SDK tracks its state to prevent invalid operations:

```dart
final portsip = Portsip();

// Check SDK state
print(portsip.state);        // PortsipState.uninitialized
print(portsip.isInitialized); // false
print(portsip.isDisposed);    // false

// Initialize
await portsip.initialize(...);
print(portsip.isInitialized); // true

// Use the SDK...

// Cleanup when done
await portsip.dispose();
print(portsip.isDisposed);    // true

// After dispose, create a new instance if needed
final newPortsip = Portsip();
```

### State Exceptions

The SDK throws `PortsipStateException` for invalid operations:
- Calling methods before `initialize()` completes
- Calling methods after `dispose()` has been called
- Calling `initialize()` twice without disposing first

## Limitations

- **Outgoing calls only**: The current version supports outgoing calls. Incoming call support is planned for a future release.
- **Voice only**: Video call functionality is not supported.

## License

This plugin requires a PortSIP license for production use. You can test without a license during development.

For licensing information, visit [PortSIP](https://www.portsip.com/).
