## 0.0.7

* **Fix (Android)**: Correctly report and track self-managed outgoing calls with
the system ConnectionService across their full lifecycle (placement, connect,
hang-up), and reliably tear the call down on hang-up.

## 0.0.6

* **iOS**: When the app is swipe-killed (or system-terminated) while a CallKit
call is active, the SIP dialog is now properly closed natively before the
process dies. The controller observes `UIApplication.willTerminateNotification`
and ends each active call and unregisters the device from the
SIP server, so the server no longer holds the call open or keeps the device
registered after termination.

## 0.0.5

* **Fix**: Add `unInitialize()` for runtime SIP user swap. Tears down the native SDK (`unRegisterServer(0)` + `unInitialize()`) so the next `initialize()` + `register()` can load a different user cleanly without hitting `-60095` (`ECoreAllowOnlyOneUser`). Unlike `dispose()`, this keeps the event stream, method-channel handler, iOS observers/CallKit, and Android ConnectionService alive — existing event listeners keep firing after the swap.

## 0.0.4

* **Fix**: Change the CXHandle type from .generic to .phoneNumber when reporting outgoing calls to CallKit via CXStartCallAction.

## 0.0.3

* **Fix**: `unregister` no longer uninitializes the SDK, so calling `register` again afterwards works correctly without requiring a full re-initialization.

## 0.0.2

* **BREAKING CHANGE**: PortSIP VoIP SDK binaries are no longer bundled with the plugin
  - iOS: Developers must place `PortSIPVoIPSDK.xcframework` at `ios/Frameworks/` and embed it in Xcode (Embed & Sign)
  - Android: Developers must place `portsipvoipsdk.jar` at `android/app/libs/` and add it as an `implementation` dependency
  - Plugin package size reduced from ~80MB to under 1MB
  - See README for detailed setup instructions

## 0.0.1

* Initial release of the PortSIP Flutter plugin
* **SIP Registration**: Configure and register SIP accounts with server
* **Outgoing Calls**: Make voice calls with session management
* **Call Controls**: Hold, unhold, mute, and hang up calls
* **DTMF Support**: Send DTMF tones via RFC2833, INFO, or INBAND methods
* **Audio Management**:
  - Loudspeaker toggle
  - Audio codec configuration
  - AEC, AGC, ANS, CNG, and VAD controls
* **iOS CallKit Integration**: Native call UI support for iOS
* **Android ConnectionService**: Native call UI support for Android
* **Security**: SRTP policy configuration and TLS certificate support
* **Event System**: Broadcast stream for SDK events with typed event classes
* **Lifecycle Management**: Proper SDK state management with initialize/dispose
* **Logging**: Configurable debug logging across Dart, iOS, and Android layers
* **3GPP Support**: Optional 3GPP tags for carrier compatibility
