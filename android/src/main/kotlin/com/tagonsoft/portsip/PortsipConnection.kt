package com.tagonsoft.portsip

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.telecom.CallAudioState
import android.telecom.Connection
import android.telecom.DisconnectCause

/**
 * Represents a single call connection for Android's ConnectionService.
 * This is the Android equivalent of a CallKit call on iOS.
 *
 * Each connection handles user interactions from the system call UI:
 * - End call
 * - Hold/unhold
 * - Mute/unmute
 * - Speaker toggle
 * - DTMF input
 */
class PortsipConnection(
    private val context: Context,
    private var sessionId: Long
) : Connection() {

    companion object {
        private const val COMPONENT = "Connection"
    }

    /**
     * The merged-conference primary ended but this Connection lives on as the
     * surviving leg's system call — retarget the system-UI callbacks (end,
     * hold, DTMF, …) at the surviving session.
     */
    fun adoptSession(newSessionId: Long) {
        PortsipLogger.d(COMPONENT, "Connection adopting session $newSessionId (was $sessionId)")
        sessionId = newSessionId
    }

    init {
        // Set initial properties
        connectionProperties = PROPERTY_SELF_MANAGED

        // Set audio mode hint
        audioModeIsVoip = true

        PortsipLogger.d(COMPONENT, "Connection created for session $sessionId")
    }

    /**
     * Called when the user disconnects the call from the system UI.
     * This is equivalent to iOS CallKit's CXEndCallAction.
     */
    override fun onDisconnect() {
        PortsipLogger.d(COMPONENT, "onDisconnect for session $sessionId")

        // Notify PortsipController to end the call
        PortsipController.shared.handleConnectionServiceEndCall(sessionId)

        // Update connection state
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()

        // Send event to Flutter
        PortsipEventBridge.shared.sendEvent(
            "onConnectionServiceEndCall",
            mapOf(PortsipConstants.EventKeys.SESSION_ID to sessionId)
        )
    }

    /**
     * Called when the user aborts (cancels) the call from the system UI.
     */
    override fun onAbort() {
        PortsipLogger.d(COMPONENT, "onAbort for session $sessionId")

        // Notify PortsipController to end the call
        PortsipController.shared.handleConnectionServiceEndCall(sessionId)

        // Update connection state
        setDisconnected(DisconnectCause(DisconnectCause.CANCELED))
        destroy()

        // Send event to Flutter
        PortsipEventBridge.shared.sendEvent(
            "onConnectionServiceEndCall",
            mapOf(PortsipConstants.EventKeys.SESSION_ID to sessionId)
        )
    }

    /**
     * Called when the user puts the call on hold from the system UI.
     * This is equivalent to iOS CallKit's CXSetHeldCallAction.
     */
    override fun onHold() {
        PortsipLogger.d(COMPONENT, "onHold for session $sessionId")

        // Notify PortsipController to hold the call
        PortsipController.shared.handleConnectionServiceHold(sessionId, true)

        // Update connection state
        setOnHold()

        // Send event to Flutter
        PortsipEventBridge.shared.sendEvent(
            "onConnectionServiceHold",
            mapOf(
                PortsipConstants.EventKeys.SESSION_ID to sessionId,
                PortsipConstants.EventKeys.ON_HOLD to true
            )
        )
    }

    /**
     * Called when the user takes the call off hold from the system UI.
     */
    override fun onUnhold() {
        PortsipLogger.d(COMPONENT, "onUnhold for session $sessionId")

        // Notify PortsipController to unhold the call
        PortsipController.shared.handleConnectionServiceHold(sessionId, false)

        // Update connection state
        setActive()

        // Send event to Flutter
        PortsipEventBridge.shared.sendEvent(
            "onConnectionServiceHold",
            mapOf(
                PortsipConstants.EventKeys.SESSION_ID to sessionId,
                PortsipConstants.EventKeys.ON_HOLD to false
            )
        )
    }

    /**
     * Called when the audio state changes (mute, speaker, etc.).
     * This handles mute toggle from the system UI.
     */
    override fun onCallAudioStateChanged(state: CallAudioState?) {
        state?.let {
          try {
            PortsipLogger.d(COMPONENT, "onCallAudioStateChanged for session $sessionId: muted=${it.isMuted}, route=${it.route}")

            // Handle mute state change
            // Note: We don't need to call muteSession here as the SDK handles audio
            // We just notify Flutter about the state change
            PortsipEventBridge.shared.sendEvent(
                "onConnectionServiceMute",
                mapOf(
                    PortsipConstants.EventKeys.SESSION_ID to sessionId,
                    PortsipConstants.EventKeys.MUTED to it.isMuted
                )
            )

            // Audio route change. Telecom owns the route; the SDK follows.
            val route = it.route
            val want = PortsipConnectionService.getDesiredRoute()
            val reconfiguring = PortsipConnectionService.isAudioReconfiguring()
            val wantReachable = (it.supportedRouteMask and want) != 0

            // During a resume Telecom drops the route to the earpiece. If that's not
            // what the user picked, re-assert their route instead of accepting the
            // reset — this is what preserves speaker/BT across hold/swap/merge.
            if (reconfiguring && route != want && wantReachable) {
                PortsipLogger.d(COMPONENT, "re-asserting route $want during reconfiguration")
                PortsipConnectionService.applyAudioRoute(want)
                // Report the route we're restoring so the UI doesn't flash the
                // transient earpiece; the real onCallAudioStateChanged that follows
                // applyAudioRoute will confirm it.
                emitRouteForReassert(want, it)
                return@let
            }

            // A genuine route change (user picked in-app or via the system UI):
            // record it as the desired route and tell the SDK to follow speaker/
            // earpiece (BT/headset are followed by the SDK's AppRTC manager).
            if (!reconfiguring) {
                PortsipConnectionService.setDesiredRoute(route)
            }
            // Physically apply the route via setCommunicationDevice — works for USB
            // headsets and forces the speaker even with a headset plugged in (AppRTC
            // refused both). Single physical router for all outputs.
            PortsipConnectionService.routeToDevice(context, route)
            PortsipEventBridge.shared.sendEvent(
                "onConnectionServiceAudioRoute",
                mapOf(PortsipConstants.EventKeys.SESSION_ID to sessionId) +
                    PortsipConnectionService.routeStateMap(it)
            )
          } catch (e: Throwable) {
            // Never let route handling crash the call (esp. release builds).
            PortsipLogger.e(COMPONENT, "onCallAudioStateChanged failed: $e")
          }
        }
    }

    /** Emits the route state with [route] forced as current (used while we
     *  re-assert it during a reconfiguration, before Telecom confirms). */
    private fun emitRouteForReassert(route: Int, state: CallAudioState) {
        val base = PortsipConnectionService.routeStateMap(state).toMutableMap()
        @Suppress("UNCHECKED_CAST")
        val ports = base["availablePorts"] as? List<Map<String, Any>> ?: emptyList()
        val wantKind = when (route) {
            CallAudioState.ROUTE_SPEAKER -> "builtInSpeaker"
            CallAudioState.ROUTE_BLUETOOTH -> "bluetooth"
            CallAudioState.ROUTE_WIRED_HEADSET -> "headphones"
            else -> "builtInReceiver"
        }
        val current = ports.firstOrNull { it["kind"] == wantKind }
        if (current != null) base["currentPort"] = current
        PortsipEventBridge.shared.sendEvent(
            "onConnectionServiceAudioRoute",
            mapOf(PortsipConstants.EventKeys.SESSION_ID to sessionId) + base
        )
    }

    /**
     * Called when the user plays DTMF tones from the system UI.
     * This is equivalent to iOS CallKit's CXPlayDTMFCallAction.
     */
    override fun onPlayDtmfTone(c: Char) {
        PortsipLogger.d(COMPONENT, "onPlayDtmfTone for session $sessionId: $c")

        // Convert char to DTMF code using the enum
        val dtmfCode = DTMFCode.fromCharacter(c)

        if (dtmfCode != null) {
            // Notify PortsipController to send DTMF
            PortsipController.shared.performDTMFAction(sessionId, c.toString())

            // Send event to Flutter
            PortsipEventBridge.shared.sendEvent(
                "onConnectionServiceDTMF",
                mapOf(
                    PortsipConstants.EventKeys.SESSION_ID to sessionId,
                    PortsipConstants.EventKeys.DIGIT to c.toString()
                )
            )
        }
    }

    /**
     * Called when DTMF tone playback should stop.
     */
    override fun onStopDtmfTone() {
        PortsipLogger.d(COMPONENT, "onStopDtmfTone for session $sessionId")
        // DTMF tone duration is handled by the SDK
    }

    /**
     * Called when the connection is shown (call UI is displayed).
     */
    override fun onShowIncomingCallUi() {
        PortsipLogger.d(COMPONENT, "onShowIncomingCallUi for session $sessionId")
        // Not implemented - outgoing calls only
    }

    /**
     * Called when silence is requested (e.g., volume down during ringing).
     */
    override fun onSilence() {
        PortsipLogger.d(COMPONENT, "onSilence for session $sessionId")
        // Optional: Could mute ringtone here
    }

    /**
     * Called when the user requests to start a call.
     * For self-managed connections, this is called after onCreateOutgoingConnection.
     */
    override fun onAnswer() {
        PortsipLogger.d(COMPONENT, "onAnswer for session $sessionId")
        // Not implemented - outgoing calls only, no answer needed
    }

    /**
     * Called when the user rejects a call.
     */
    override fun onReject() {
        PortsipLogger.d(COMPONENT, "onReject for session $sessionId")
        // Not implemented - outgoing calls only
    }
}
