# PortSIP Example App

A complete Flutter application demonstrating the **PortSIP VoIP Plugin** for making outgoing SIP calls.

## Overview

This example app showcases how to integrate SIP-based voice communications into a Flutter application using the PortSIP plugin. It demonstrates:

- SIP account registration with timeout handling
- Making outgoing voice calls with call duration tracking
- Call controls (hold, mute, DTMF, speaker)
- Audio processing configuration (AEC, AGC, CNG, VAD)
- SRTP encryption policy configuration
- iOS CallKit integration for native call UI
- Android ConnectionService integration for native call UI
- Typed event handling with pattern matching
- State management with BLoC/Cubit pattern

> **Note:** The current version supports **outgoing calls only**. Incoming call support is planned for a future release.

## Architecture

The app follows a clean architecture pattern with a singleton repository:

```
lib/
├── main.dart                        # App entry point
├── router.dart                      # GoRouter configuration
├── tab_bar_container.dart           # Tab navigation container
└── portsip/
    ├── repository/
    │   └── portsip_repository.dart  # SDK lifecycle manager (singleton)
    └── pages/
        ├── connection/
        │   ├── connection_page.dart   # Registration UI
        │   ├── connection_cubit.dart  # Registration state management
        │   └── connection_state.dart  # Registration state model
        └── call/
            ├── call_page.dart         # Call UI with controls
            ├── call_cubit.dart        # Call state management
            └── call_state.dart        # Call state model
```

## Prerequisites

- Flutter SDK 3.3.0+
- Dart SDK 3.9.2+
- iOS 13.0+ / Android API 24+
- Access to a SIP server
- PortSIP license key (optional - you can test without a license)

## Getting Started

```bash
cd example
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## Configuration

Update the SIP account details in the connection page with your credentials:

```dart
SipAccount(
  username: "your-extension",
  displayName: "Your Name",
  authName: "your-extension",
  password: "your-password",
  domain: "your-sip-server.com",
  serverAddress: "your-sip-server.com",
  serverPort: 5060,
)
```

## Features Demonstrated

### Repository Pattern

The `PortsipRepository` singleton manages the SDK lifecycle and provides:

- Safe initialization (prevents re-initialization crashes)
- Platform-specific audio processing configuration
- Automatic CallKit/ConnectionService setup
- Typed event stream for state management

```dart
// Access the singleton
final repository = PortsipRepository.instance;

// Initialize once
await repository.initialize();

// Listen to typed events
repository.events.listen((event) {
  if (event is RegisterSuccessEvent) {
    // Handle registration success
  }
});
```

### Connection Page

- SDK initialization with safe re-initialization handling
- License key configuration (optional)
- Audio codec selection (G.729, DTMF)
- Audio processing features:
  - CNG (Comfort Noise Generation)
  - VAD (Voice Activity Detection)
  - AEC (Acoustic Echo Cancellation) - Android only
  - AGC (Automatic Gain Control) - Android only
- SRTP policy configuration
- SIP account registration with timeout
- Registration status display (disconnected, connecting, connected, error)
- CallKit configuration (iOS)
- ConnectionService configuration (Android)

### Call Page

- Outgoing call initiation
- Call duration timer
- Active call controls:
  - Hold/Resume
  - Mute/Unmute
  - DTMF keypad
  - Loudspeaker toggle
- Call state display (idle, calling, ringing, connected, holding, failed)
- Error message display
- Call termination
- Native call UI integration via CallKit/ConnectionService

### Typed Event Handling

The app uses typed events for type-safe event handling:

```dart
repository.events.listen((event) {
  if (event is InviteRingingEvent) {
    // Handle ringing
  } else if (event is InviteConnectedEvent) {
    // Handle connected
  } else if (event is InviteFailureEvent) {
    print('Call failed: ${event.reason} (${event.code})');
  } else if (event is CallKitMuteEvent) {
    // Handle CallKit mute action
  } else if (event is ConnectionServiceHoldEvent) {
    // Handle Android ConnectionService hold action
  }
});
```

## State Management

The app uses the **BLoC pattern with Cubit** for state management:

### ConnectionCubit

Manages registration state and SDK initialization:

- `ConnectionStatus`: disconnected, connecting, connected, error
- Registration timeout handling
- Event subscription for registration events

### CallCubit

Manages call state and call controls:

- `CallStatus`: idle, calling, ringing, connected, holding, failed
- Call duration tracking with timer
- Event handling for:
  - Call progress events (ringing, answered, connected, closed, failure)
  - Remote hold/unhold events
  - CallKit events (iOS): mute, hold, speaker, DTMF
  - ConnectionService events (Android): end call, hold, mute, speaker, DTMF

## Dependencies

| Package | Purpose |
|---------|---------|
| `portsip` | PortSIP VoIP plugin |
| `flutter_bloc` | State management |
| `go_router` | Navigation |

## Permissions

The app requires the following permissions:

**iOS** (configured in Info.plist):

- Microphone access (`NSMicrophoneUsageDescription`)
- VoIP background mode
- Audio background mode

**Android** (configured in AndroidManifest.xml):

- `INTERNET`
- `RECORD_AUDIO`
- `MODIFY_AUDIO_SETTINGS`
- `ACCESS_NETWORK_STATE`
- `MANAGE_OWN_CALLS` (for ConnectionService)
- `READ_PHONE_STATE` (for ConnectionService)
- `FOREGROUND_SERVICE_PHONE_CALL` (for ConnectionService)

## Troubleshooting

### Registration fails

- Verify SIP server address and port
- Check username/password credentials
- Ensure network connectivity
- Check registration timeout (default: 30 seconds)

### No audio during call

- Check microphone permissions are granted
- Verify audio codec compatibility with your SIP server
- Check if the call is muted
- On Android, ensure `enableAudioManager(true)` is called

### Call fails immediately

- Ensure SIP registration is active before making calls
- Verify the callee number format
- Check firewall allows SIP traffic (UDP/TCP port 5060)
- Check the error code in `InviteFailureEvent`

### DTMF not working

- On Android, ensure `enableAudioManager(true)` is called during initialization
- Verify the call is in `connected` state before sending DTMF

### CallKit/ConnectionService not working

- **iOS**: Ensure VoIP background mode is enabled in Info.plist
- **Android**: Verify `MANAGE_OWN_CALLS` permission is granted
- Check that CallKit/ConnectionService is configured after `initialize()`

## Native Call UI Integration

The example app demonstrates integration with native call UIs on both platforms:

### iOS (CallKit)

CallKit provides the native iOS call UI, allowing calls to appear like regular phone calls with:

- Lock screen call UI
- System call notifications
- Audio routing controls
- Mute, hold, and speaker buttons

Events handled: `CallKitMuteEvent`, `CallKitHoldEvent`, `CallKitSpeakerEvent`, `CallKitDTMFEvent`

### Android (ConnectionService)

ConnectionService is Android's equivalent to CallKit, providing:

- System call screen integration
- Background call protection
- Native audio routing (speaker, earpiece, Bluetooth)

Events handled: `ConnectionServiceEndCallEvent`, `ConnectionServiceHoldEvent`, `ConnectionServiceMuteEvent`, `ConnectionServiceSpeakerEvent`, `ConnectionServiceDTMFEvent`, `ConnectionServiceFailureEvent`

## Learn More

- [PortSIP Plugin Documentation](../)
- [PortSIP SDK Documentation](https://support.portsip.com/development-portsip/getting-started)
- [Flutter Documentation](https://docs.flutter.dev/)
- [BLoC Pattern](https://bloclibrary.dev/)
- [iOS CallKit](https://developer.apple.com/documentation/callkit)
- [Android ConnectionService](https://developer.android.com/reference/android/telecom/ConnectionService)
