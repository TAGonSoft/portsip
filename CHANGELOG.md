## 0.0.9

* **Feature**: Audio conferencing on both platforms. Adds `createAudioConference()`,
`joinToConference({sessionId})`, `removeFromConference({sessionId})`, and
`destroyConference()` to build and tear down a mixing bridge so all participants
hear each other.
* **Feature**: Expose `swapHold({holdSessionId, unholdSessionId})` — atomically
holds one call and resumes another. Required on iOS, where the CallKit mirror
must be a single transaction or CallKit's one-active-call enforcement can end a
call when swapping with separate hold/unHold calls.
* **Feature**: Expose `reportConferenceMerged({primarySessionId, mergedAwaySessionIds})`.
Ends the CallKit / ConnectionService calls for merged-away legs (their SIP
sessions stay live in the bridge) so the OS presents one call instead of several.
* **Feature**: Expose `updateOsCallDisplay({sessionId, displayName})` to update
the name the system call UI shows for a session — e.g. a conference title after
a merge.
* **Feature**: New `CallKitMergeEvent` (`onCallKitMerge`, iOS only) emitted when
the user taps Merge in the system call UI (`CXSetGroupCallAction`), carrying both
`sessionId` and `otherSessionId` so the app can bridge them into a conference.
* **Feature**: `makeCall(...)` gains `reportToConnectionService` (default `true`)
and `displayName`. Pass `reportToConnectionService: false` for additional
conference legs to keep the whole conference as one system call; set `displayName`
at call time since iOS doesn't reliably honor display updates after an outgoing
call starts.
* **Feature**: `hangUp(...)` gains `reportToConnectionService` (default `true`).
Pass `false` to drop a single conference leg without ending the system call or
tearing down the shared audio session.

## 0.0.8

* **Feature**: Expose `refreshRegistration({int expires = 0})` on both
platforms. Call it when the device's network changes (e.g. WiFi to cellular
handoff) — the native SDK re-registers over the new network interface. Pass
`expires: 0` (default) to keep the previously negotiated expiry and force an
immediate re-register.
* **Feature**: Expose `updateCall({sessionId, enableAudio, enableVideo})` on
both platforms. Sends a re-INVITE that renegotiates the media streams of an
established call — use it after a network change to re-anchor audio to the
new interface.
* **Feature**: Expose `enableSessionTimer({int timerSeconds = 90, int refreshMode = 0})`
on both platforms. Enables SIP session timers (RFC 4028) so a dead call leg is
reaped by the server at expiry when the client stops refreshing (e.g. lost
network mid-call), instead of lingering for minutes. Minimum 90s; refreshMode
0 = UAC (caller) refreshes, 1 = UAS (callee).

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
