## 0.2.0

* **Feature (Android)**: Telecom-owned audio routing. The self-managed
`Connection` is the single owner of the call audio route. Adds
`setAudioRoute({kind})` (`builtInReceiver | builtInSpeaker | bluetooth |
headphones`) and the `onConnectionServiceAudioRoute`
([ConnectionServiceAudioRouteEvent]) event carrying `availablePorts` and
`currentPort` built from Telecom's `CallAudioState`, so a route picker can be
driven entirely from plugin events. `setLoudspeakerStatus` now routes through
Telecom as well. The user's chosen route is re-asserted across hold, unhold,
swap, conference join and end-and-resume (Telecom resets to the earpiece while
media renegotiates). Routes are physically applied via
`AudioManager.setCommunicationDevice` (API 31+), which also supports USB
headsets and forcing the speaker while a headset is plugged in. When using
Telecom routing, call `enableAudioManager(enable: false)` — the SDK's built-in
audio manager competes with Telecom and resets the route to earpiece on every
new call leg.
* **Fix (Android)**: `endCallAndResume` destroys the ended leg's Telecom
`Connection` (previously left a phantom system call that could swallow
audio-route changes) and preserves the user's audio route across the resume.
* **Fix (Android)**: audio-route changes never target a disconnected
`Connection`.
* **Fix (Android)**: while the SDK audio conference is up, Telecom hold
requests (its one-active-call juggling between the legs' Connections) are no
longer forwarded to the SDK — SDK-holding a joined leg turns it sendonly,
breaks that leg's conference audio and starves the mixer
(`popConferenceAudioData failed` log floods).
* **Fix (Android)**: Bluetooth audio no longer drops seconds after connecting.
The plugin never issues `setCommunicationDevice` for Bluetooth anymore —
Telecom's BluetoothRouteManager owns the SCO/BLE link, and pinning an app
request over it (or leaving a stale speaker/earpiece request behind) yanked
audio off the headset when the policy re-evaluated. Switching to Bluetooth now
withdraws the plugin's outstanding request instead; built-in/wired outputs
still route via `setCommunicationDevice` (with a brief retry while a
just-connected headset isn't listed yet), and the request is cleared when the
last call ends.
* **Fix**: `setAudioRoute` returns -1 on platforms where it isn't implemented
(iOS) instead of throwing `MissingPluginException`.

## 0.1.1

* **Feature**: `getStatistics({sessionId})` — requests RTP media statistics for
a session. Results are delivered asynchronously on the events stream as an
`onStatistics` ([StatisticsEvent]) carrying a JSON `stat` string with
byte/packet/jitter/loss counters. Poll periodically (e.g. once per second) to
track the live data usage of an ongoing call. Wired on both iOS and Android.

## 0.1.0

* **BREAKING**: Conference merge no longer ends any call leg. The old
"end the merged-away leg" model tore down the shared audio session and
silenced participants on merge.
* **Feature**: `requestCallGroup({sessionIds})` — group calls into one native
conference in the system UI (iOS `CXSetGroupCallAction`; Android signals the
host to build the SDK bridge). No call is ended; the host is notified via
`onCallKitMerge` to build/confirm the audio bridge.
* **Feature**: `endCallAndResume({endSessionId, resumeSessionId})` — ends one
leg and resumes another atomically, keeping exactly one active system call so
the audio session is never torn down. Prefer over separate `hangUp`/`unHold`.
* **Deprecated**: `reportConferenceMerged(...)` — use `requestCallGroup`.
Ending the merged-away leg tears down the audio session.

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
