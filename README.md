# PortSIP Flutter Plugin

> **⚠️ IMPORTANT DISCLAIMER**
>
> This is an **unofficial, community-developed** Flutter wrapper for the [PortSIP VoIP SDK](https://www.portsip.com/download-portsip-voip-sdk/).
>
> **This package is NOT affiliated with, endorsed by, or officially supported by PortSIP Solutions, Inc.**
>
> For official SDK documentation and support, please visit [portsip.com](https://www.portsip.com/).

## License & Trademark

- **PortSIP®** is a registered trademark of PortSIP Solutions, Inc.
- The PortSIP SDK binaries used with this plugin are subject to [PortSIP's licensing terms](https://www.portsip.com/)
- A valid **PortSIP license is required for production use** (testing works without a license)
- This Flutter wrapper code is provided under the **MIT License**

**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.**

A Flutter plugin that integrates the PortSIP VoIP SDK, enabling SIP-based voice communications in your Flutter applications.

This plugin provides a cross-platform Dart API built on top of the native PortSIP SDK for iOS and Android, simplifying VoIP integration in Flutter apps.

> **Important:** The PortSIP SDK binaries are **not included** with this plugin. You must download the SDK (V19.6.2) from PortSIP and configure it in your app. See the [SDK Setup](#sdk-setup-required) section below.

## Resources

- [PortSIP VoIP SDK](https://www.portsip.com/download-portsip-voip-sdk/)
- [PortSIP SDK Documentation](https://support.portsip.com/development-portsip/getting-started)

## Features

- **SIP Registration** - Register and authenticate with SIP servers
- **Outgoing Voice Calls** - Make and manage outgoing audio calls
- **Call Controls** - Hold, mute, DTMF tones, loudspeaker toggle, audio route selection (Android)
- **Conference Calls** - Merge calls into a native conference (`requestCallGroup`, `endCallAndResume`)
- **Call Statistics** - Poll RTP media statistics during a call (`getStatistics`)
- **Call Recording** - Record a call to a file (`startRecord`, `stopRecord`), or capture the raw audio stream to a stereo WAVE file (`startPcmRecord`, `stopPcmRecord`, Android)
- **Play to Remote** - Play an audio file into the outgoing stream (`startPlayingFileToRemote`)
- **Audio Codecs** - Configure preferred audio codecs (OPUS, G.722, G.729, etc.)
- **Audio Processing** - AEC, AGC, ANS, CNG, VAD for enhanced audio quality
- **Audio QoS** - DSCP marking on the audio channel (`enableAudioQos`)
- **SIP Signaling Logs** - Mirror sent and received SIP messages into the platform logs (`enableCallbackSignaling`)
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
  portsip: ^0.1.2
```

### SDK Setup (Required)

This plugin requires the **PortSIP VoIP SDK V19.6.2** native binaries, which are **not included** with the plugin. You must download and configure them for each platform.

**Download the SDK:**
1. Visit the [PortSIP VoIP SDK download page](https://www.portsip.com/download-portsip-voip-sdk/)
2. Download the SDK package for both iOS and Android

---

### iOS Setup

#### Step 1: Place the SDK Framework

1. Extract `PortSIPVoIPSDK.xcframework` from the downloaded SDK package
2. Create a `Frameworks` directory inside your app's `ios/` folder:
   ```
   your_app/
   └── ios/
       └── Frameworks/
           └── PortSIPVoIPSDK.xcframework/
   ```
3. Copy `PortSIPVoIPSDK.xcframework` into `ios/Frameworks/`

#### Step 2: Embed the Framework in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Go to **General** > **Frameworks, Libraries, and Embedded Content**
4. Click **+** > **Add Other...** > **Add Files...**
5. Navigate to `ios/Frameworks/` and select `PortSIPVoIPSDK.xcframework`
6. Make sure it is set to **Embed & Sign**

> **Important:** If you skip Step 2, the app will compile but crash at launch with a `dyld: Library not loaded` error because the framework is not embedded in the app bundle.

#### Step 3: Add Required Permissions

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Required for voice calls</string>
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>audio</string>
</array>
```

#### Step 4: Install Pods

```bash
cd ios
pod install
```

---

### Android Setup

#### Step 1: Place the SDK AAR

1. Extract `portsipvoipsdk.aar` from the downloaded SDK package
2. Create a `libs` directory inside your app's `android/app/` folder (if it doesn't already exist):
   ```
   your_app/
   └── android/
       └── app/
           └── libs/
               └── portsipvoipsdk.aar
   ```
3. Copy `portsipvoipsdk.aar` into `android/app/libs/`

#### Step 2: Add the AAR as a Dependency

Add the following to your `android/app/build.gradle` (Groovy) or `android/app/build.gradle.kts` (Kotlin DSL):

**Kotlin DSL (`build.gradle.kts`):**
```kotlin
repositories {
    flatDir {
        dirs("libs")
    }
}

dependencies {
    implementation(":portsipvoipsdk@aar")
}
```

**Groovy (`build.gradle`):**
```groovy
repositories {
    flatDir {
        dirs 'libs'
    }
}

dependencies {
    implementation(name: 'portsipvoipsdk', ext: 'aar')
}
```

#### Step 3: Add Required Permissions

Add the following to your `android/app/src/main/AndroidManifest.xml`:

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
await portsip.enableAudioManager(enable: true);  // For DTMF; use false with ConnectionService audio routing

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
    userName: "1001",
    password: "secret",
    sipServer: "sip.example.com",
    sipServerPort: 5060,
    displayName: "John Doe",
    authName: "1001",
    userDomain: "sip.example.com",
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
        userName: "1001",
        password: "password123",
        sipServer: "sip.example.com",
        sipServerPort: 5060,
        displayName: "User 1001",
        authName: "1001",
        userDomain: "sip.example.com",
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
| `onCallKitHold` | `sessionId`, `onHold` | User toggled hold from CallKit UI |
| `onCallKitMute` | `sessionId`, `muted` | User toggled mute from CallKit UI |
| `onCallKitSpeaker` | `sessionId`, `enableSpeaker` | User toggled speaker from CallKit UI |
| `onCallKitDTMF` | `sessionId`, `digits` | User sent DTMF from CallKit UI |
| `onCallKitEndCall` | `sessionId` | User ended call from CallKit UI |
| `onCallKitFailure` | `sessionId`, `error` | CallKit failed (call auto-terminated) |

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
| `onConnectionServiceHold` | `sessionId`, `onHold` | User toggled hold from system UI |
| `onConnectionServiceMute` | `sessionId`, `muted` | User toggled mute from system UI |
| `onConnectionServiceAudioRoute` | `sessionId`, `availablePorts`, `currentPort` | Audio route changed (system UI or `setAudioRoute`) |
| `onConnectionServiceDTMF` | `sessionId`, `digits` | User sent DTMF from system UI |
| `onConnectionServiceFailure` | `sessionId`, `message` | ConnectionService operation failed |

### Audio Routing (Android)

With ConnectionService enabled, the system (Telecom) owns the call's audio
route. Use `setAudioRoute` to switch outputs and listen to
`ConnectionServiceAudioRouteEvent` to drive a route picker:

```dart
// kinds: builtInReceiver | builtInSpeaker | bluetooth | headphones
await portsip.setAudioRoute(kind: 'bluetooth');

portsip.typedEvents.listen((event) {
  if (event is ConnectionServiceAudioRouteEvent) {
    print('Available: ${event.availablePorts}, current: ${event.currentPort}');
  }
});
```

> **Important:** When routing audio through ConnectionService, call
> `enableAudioManager(enable: false)` — the SDK's built-in audio manager
> competes with Telecom and resets the route on every new call leg.
>
> On iOS `setAudioRoute` returns -1; use `setLoudspeakerStatus` instead
> (Bluetooth/headphones are handled by the system).

## Audio Processing

The plugin provides audio processing features to enhance call quality:

| Method | Platform | Description |
|--------|----------|-------------|
| `enableAEC` | Android | Acoustic Echo Cancellation - removes echo from speaker-to-mic feedback |
| `enableAGC` | Android | Automatic Gain Control - maintains consistent audio levels |
| `enableANS` | Android | Automatic Noise Suppression - reduces background noise |
| `enableCNG` | Both | Comfort Noise Generation - generates background noise during silence |
| `enableVAD` | Both | Voice Activity Detection - detects speech to reduce bandwidth |
| `enableAudioManager` | Android | Required for DTMF; pass `false` when routing audio through ConnectionService |
| `setSrtpPolicy` | Both | SRTP encryption: 0=None, 1=Prefer, 2=Force |
| `enable3GppTags` | Both | 3GPP headers for carrier compatibility |
| `enableAudioQos` | Both | DSCP marking on the audio channel: 46 (Expedited Forwarding) when on, 0 when off |

> **Note:** On iOS, AEC/AGC/ANS are handled at the system level via AVAudioSession.

```dart
// Configure audio processing after initialize()
await portsip.enableCNG(enable: true);
await portsip.enableVAD(enable: true);
await portsip.setSrtpPolicy(policy: 1); // Prefer SRTP
await portsip.enableAudioQos(enable: true); // Best-effort: many networks rewrite DSCP

// Android-specific
if (Platform.isAndroid) {
  await portsip.enableAEC(enable: true);
  await portsip.enableAGC(enable: true);
  await portsip.enableAudioManager(enable: true);
}
```

## Call Recording

`startRecord` writes the call audio to a file and `stopRecord` closes it.

```dart
await portsip.startRecord(
  sessionId: sessionId,
  recordFilePath: directory.path, // must already exist
  recordFileName: 'call', // no extension — the SDK appends it
  audioChannels: 1,
  fileFormat: PortsipRecordFileFormat.wave,
  audioRecordMode: PortsipRecordMode.both, // local mic + remote party
  videoRecordMode: PortsipRecordMode.none,
);

await portsip.stopRecord(sessionId: sessionId);
```

| Parameter | Description |
|-----------|-------------|
| `recordFilePath` | Directory the file is written to. **It must already exist** — the SDK does not create it. |
| `recordFileName` | File name **without** an extension — the SDK appends the one matching `fileFormat`, so passing `call.wav` writes `call.wav.wav`. |
| `appendTimeStamp` | Appends a timestamp to the file name. |
| `audioChannels` | 1 = mono, 2 = stereo. |
| `fileFormat` | `PortsipRecordFileFormat`: `wave`, `amr` (mono only), `mp3`, `mp4` (video). |
| `audioRecordMode` / `videoRecordMode` | `PortsipRecordMode`: `none`, `receive`, `send`, `both`. |

> **Recording is per session, not per call.** The SDK has no conference-level
> recorder, so a conference must be recorded by calling `startRecord` on every
> leg — each leg writing its own file. Stop a leg's recording before ending
> that leg, so the SDK can finalise the file while the session still exists.

### Raw Audio Recording (Android)

`startPcmRecord` is an alternative to `startRecord` that writes the PCM the SDK
hands to its audio stream callback, instead of routing it through the SDK's own
recorder. Both directions land in one stereo `<recordFileName>.wav` — **what
this side sent on the left channel, what it received on the right** — so
neither party can clip the other and the two stay separable for anything
reading the file later. A call that only ever produced one direction stays
mono.

```dart
await portsip.startPcmRecord(
  sessionId: sessionId,
  recordFilePath: directory.path, // must already exist
  recordFileName: 'call', // no extension — `.wav` is appended
);

// Returns the finished recording's path, or null if nothing was captured.
final path = await portsip.stopPcmRecord(sessionId: sessionId);
```

While the call runs, each direction is written to its own `.partN` scratch file
next to the recording; `stopPcmRecord` interleaves them, deletes the parts and
completes once the finished file is on disk — for a long call that takes a
moment. Parts stranded by a process killed mid-call are swept the next time a
recording starts in that directory.

> **Stopping after the call has ended is the ordinary case.** Calling
> `stopPcmRecord` from an `onInviteClosed` handler still returns the recording.
> An app that never calls it at all loses the recording — the parts are closed
> when the call ends, but only `stopPcmRecord` merges them.

| | `startRecord` | `startPcmRecord` |
|---|---|---|
| Platforms | iOS + Android | Android only (returns -1 / null on iOS) |
| Formats | `wave`, `amr`, `mp3`, `mp4` | 16-bit PCM WAVE only |
| Video | Yes (`mp4`) | No |
| Channel layout | Mixed per `audioRecordMode` | Sent left, received right |
| Result | File written by the SDK | Path returned by `stopPcmRecord` |

Both recorders can run on the same session; they write independent files.

## Playing a File to the Remote Party

`startPlayingFileToRemote` feeds an audio file into the stream the remote party
receives — in-call announcements, hold music, prompts.

```dart
await portsip.startPlayingFileToRemote(
  sessionId: sessionId,
  fileUrl: '${directory.path}/announcement.wav',
  loop: false,
  // Remote party hears the file AND the live microphone.
  playAudio: PortsipPlayFileAudioMode.mixedWithMicrophone,
);

await portsip.stopPlayingFileToRemote(sessionId: sessionId);
```

| `playAudio` | Effect |
|-------------|--------|
| `none` | The file's audio isn't played (video-only playback). |
| `fileOnly` | The file replaces the microphone — the caller isn't heard. |
| `mixedWithMicrophone` | The file plays over the live microphone. **Default.** |

> Playback is per session, like recording. To reach every participant of a
> conference, play the file on each leg.

## SIP Signaling Logs

`enableCallbackSignaling` mirrors the SIP messages the SDK sends and/or receives
into the platform logs — Logcat on Android, the Xcode console on iOS. It is a
diagnostic aid only: the SDK hands the plugin a copy of each message, so turning
it on cannot alter, delay or block what goes on the wire.

```dart
portsip.setLogsEnabled(enabled: true); // signaling logs also require this
await portsip.enableCallbackSignaling(sending: true, received: true);
```

Both directions are off by default. Messages are logged only while
`setLogsEnabled` is on, and the digest `response="..."` in `Authorization` and
`Proxy-Authorization` headers is masked before logging. The rest of each message
— SIP URIs, `Call-ID`, nonces, `User-Agent` — is logged verbatim, so leave this
off in release builds.

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

Before running the example app, you must set up the PortSIP SDK:

1. Download the SDK from [PortSIP](https://www.portsip.com/download-portsip-voip-sdk/)
2. **iOS**: Copy `PortSIPVoIPSDK.xcframework` to `example/ios/Frameworks/`
3. **iOS**: Open `example/ios/Runner.xcworkspace` in Xcode, add the framework to Runner target as **Embed & Sign**
4. **Android**: Copy `portsipvoipsdk.aar` to `example/android/app/libs/`

Then:

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

## Troubleshooting

### iOS

**`dyld: Library not loaded: @rpath/PortSIPVoIPSDK.framework/PortSIPVoIPSDK`**
- The framework is not embedded in the app bundle.
- Open Xcode, select Runner target > General > Frameworks, Libraries, and Embedded Content > set `PortSIPVoIPSDK.xcframework` to **Embed & Sign**.

**`missing or invalid CFBundleExecutable in its Info.plist`**
- The SDK framework's `Info.plist` may be missing the `CFBundleExecutable` key.
- Fix by running: `plutil -insert CFBundleExecutable -string "PortSIPVoIPSDK" <path-to-framework>/Info.plist` for both the device and simulator slices inside the `.xcframework`.

**`No such module 'PortSIPVoIPSDK'`**
- The framework is not in the expected location.
- Verify `PortSIPVoIPSDK.xcframework` exists at `ios/Frameworks/PortSIPVoIPSDK.xcframework/`.

### Android

**`ClassNotFoundException: com.portsip.PortSipSdk`**
- The SDK AAR is not included in app dependencies.
- Add a `flatDir` repository and `implementation(name: 'portsipvoipsdk', ext: 'aar')` to `android/app/build.gradle`.

**`Unresolved reference` errors during build**
- The AAR is not in the expected location.
- Verify `portsipvoipsdk.aar` exists at `android/app/libs/portsipvoipsdk.aar`.

## Limitations

- **Outgoing calls only**: The current version supports outgoing calls. Incoming call support is planned for a future release.
- **Voice only**: Video call functionality is not supported.
