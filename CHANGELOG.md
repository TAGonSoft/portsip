## 0.2.2

* **Feature**: `makeCall({displayNumber})` — the number the system call UI shows
and the OS call history stores, independent of the SIP destination. Defaults to
`callee`, so existing callers are unaffected. Use it when the server requires a
differently formatted destination than the one the user should see: the OS can
only format and dial back a number it can parse.

## 0.2.1

* **Breaking**: the plugin now requires **PortSIP VoIP SDK V19.6.2**. The SDK's
`onRTPPacketCallback` gained a return value in 19.6.2, so building against
19.6.0 or earlier fails to compile. Update the SDK binaries in your app before
upgrading.
* **Feature**: `enableAudioQos({enable})`, wired on both iOS and Android.
* **Feature**: `enableCallbackSignaling({sending, received})`, wired on both iOS
and Android. Mirrors the SIP messages the SDK sends and/or receives into the
platform logs (Logcat / Xcode console).

## 0.2.0

* **Retracted — do not use.** Published in error, shipped 0.1.5's code. Use 0.2.1

## 0.1.5

* **Feature (Android)**: raw audio recording.
`startPcmRecord({sessionId, recordFilePath, recordFileName})` and
`stopPcmRecord({sessionId})` write the PCM the SDK hands to its audio stream
callback, instead of routing it through the SDK's own recorder as
[startRecord] does. Both directions land in one stereo
`<recordFileName>.wav` — sent audio on the left channel, received on the right
— so neither party can clip the other and the two stay separable; a call that
produced only one direction stays mono. `recordFilePath` must be an existing
directory. `stopPcmRecord` merges the per-direction parts off the platform
thread and completes with the finished recording's path, or null if nothing
was captured; stopping from an `onInviteClosed` handler still returns the
recording.

## 0.1.4

* **Feature**: call recording. `startRecord({sessionId, recordFilePath,
recordFileName, appendTimeStamp, audioChannels, fileFormat, audioRecordMode,
videoRecordMode})` and `stopRecord({sessionId})`, wired on both iOS and
Android. `recordFilePath` must be an existing directory — the SDK does not
create it. New [PortsipRecordFileFormat] (`wave | amr | mp3 | mp4`) and
[PortsipRecordMode] (`none | receive | send | both`) enums carry the SDK's
values.
* **Feature**: play a file to the remote party.
`startPlayingFileToRemote({sessionId, fileUrl, loop, playAudio})` and
`stopPlayingFileToRemote({sessionId})`, wired on both iOS and Android. The new
[PortsipPlayFileAudioMode] enum (`none | fileOnly | mixedWithMicrophone`)
controls how the file mixes with the microphone;

## 0.1.3

* **Fix (iOS)**: `startKeepAwake` no longer outlives the SDK. Both teardown
paths now call `stopKeepAwake()` before `unInitialize()`, so a keep-awake
started on background can't leave a background assertion running on a disposed
SDK instance.
* **Fix (iOS)**: background/foreground transitions no longer recreate a
torn-down SDK. The `appDidEnterBackground` / `appWillEnterForeground` handlers
now toggle keep-awake through the backing SDK reference and no-op when the SDK
isn't initialized, instead of lazily spinning up a fresh, unconfigured
instance.

## 0.1.2

* **Feature (Android)**: Telecom-owned audio routing. Adds
`setAudioRoute({kind})` (`builtInReceiver | builtInSpeaker | bluetooth |
headphones`) and the `onConnectionServiceAudioRoute`
([ConnectionServiceAudioRouteEvent]) event carrying `availablePorts` and
`currentPort`, so a route picker can be driven entirely from plugin events.
The chosen route now survives hold, unhold, swap, conference join and
end-and-resume. When routing through Telecom, call
`enableAudioManager(enable: false)` — the SDK's audio manager competes with
Telecom and resets the route on every new call leg.
* **Fix (Android)**: Bluetooth audio no longer drops seconds after connecting.
* **Fix (Android)**: `endCallAndResume` no longer leaves a phantom call in the
system UI and preserves the audio route across the resume.
* **Fix (Android)**: system hold requests are no longer forwarded to the SDK
while a conference is active (they silenced joined legs).
* **Fix (iOS)**: the loudspeaker choice survives answer, hold, swap and merge
instead of resetting to the receiver mid-call.
* **Fix (iOS)**: the system in-call UI's speaker button no longer shows stale
state or stops responding.
* **Fix (iOS)**: Bluetooth audio no longer goes silent after ending one leg of
a multi-call.
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
