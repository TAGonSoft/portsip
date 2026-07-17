package com.tagonsoft.portsip

import android.content.ComponentName
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telecom.CallAudioState
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager

/**
 * Android ConnectionService implementation - equivalent to iOS CallKit.
 *
 * This service provides:
 * - Native call UI on Android
 * - Background call protection
 * - System call management integration
 * - Audio routing through system
 *
 * Thread Safety:
 * - Connection operations are synchronized using connectionLock
 * - Phone account operations are synchronized using phoneAccountLock
 * This prevents race conditions between system callbacks and plugin method calls.
 */
class PortsipConnectionService : ConnectionService() {

    companion object {
        private const val COMPONENT = "ConnectionService"

        /** Singleton instance for accessing from PortsipController */
        @Volatile
        private var instance: PortsipConnectionService? = null

        /** Phone account handle for this service */
        private var phoneAccountHandle: PhoneAccountHandle? = null

        /** Lock for synchronizing phone account operations */
        private val phoneAccountLock = Any()

        /** Maps PortSIP session IDs to Connection objects */
        private val sessionToConnection = mutableMapOf<Long, PortsipConnection>()

        /** Lock for synchronizing connection operations */
        private val connectionLock = Any()

        /**
         * Merged-conference tracking (set by [reportConferenceMerged], cleared
         * by [clearConferenceTracking]). After a merge only the primary leg
         * has a Connection; if its session ends while another leg survives,
         * the Connection is transferred to the survivor — destroying the last
         * Connection tears down the call audio route. Guarded by
         * [connectionLock].
         */
        private var conferencePrimarySession: Long? = null
        private val conferenceMergedAwaySessions = mutableSetOf<Long>()

        /** Whether ConnectionService is currently enabled */
        @Volatile
        var isEnabled = false
            private set

        /** Last known speaker state to prevent duplicate events */
        @Volatile
        private var lastSpeakerState: Boolean? = null

        /** App name for display in call UI */
        @Volatile
        private var appName: String = "PortSIP"

        /**
         * Configures the ConnectionService with app settings.
         * Must be called before enabling the service.
         *
         * @param context Application context
         * @param appName App name to display in call UI
         * @param canUseConnectionService Whether to enable ConnectionService
         */
        fun configure(context: Context, appName: String, canUseConnectionService: Boolean = true) {
            this.appName = appName

            if (!canUseConnectionService) {
                disable(context)
                return
            }

            try {
                synchronized(phoneAccountLock) {
                    // Create phone account handle
                    val componentName = ComponentName(context, PortsipConnectionService::class.java)
                    phoneAccountHandle = PhoneAccountHandle(componentName, "PortsipAccount")

                    // Register phone account with system
                    val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                    if (telecomManager == null) {
                        PortsipLogger.e(COMPONENT, "TelecomManager not available")
                        isEnabled = false
                        return
                    }
                    val phoneAccount = PhoneAccount.builder(phoneAccountHandle, appName)
                        .setCapabilities(
                            PhoneAccount.CAPABILITY_SELF_MANAGED
                        )
                        .addSupportedUriScheme(PhoneAccount.SCHEME_SIP)
                        .addSupportedUriScheme(PhoneAccount.SCHEME_TEL)
                        .build()

                    telecomManager.registerPhoneAccount(phoneAccount)

                    isEnabled = true
                    PortsipLogger.d(COMPONENT, "ConnectionService configured with app name: $appName")
                }
            } catch (e: Exception) {
                PortsipLogger.e(COMPONENT, "Failed to configure ConnectionService: ${e.message}", e)
                isEnabled = false
            }
        }

        /**
         * Enables or disables ConnectionService at runtime.
         *
         * @param context Application context
         * @param enabled Whether to enable ConnectionService
         */
        fun setEnabled(context: Context, enabled: Boolean) {
            if (enabled) {
                synchronized(phoneAccountLock) {
                    if (phoneAccountHandle != null) {
                        isEnabled = true
                        PortsipLogger.d(COMPONENT, "ConnectionService enabled")
                    } else {
                        PortsipLogger.w(COMPONENT, "Cannot enable ConnectionService - not configured")
                    }
                }
            } else {
                disable(context)
            }
        }

        /**
         * Disables ConnectionService and cleans up.
         */
        private fun disable(context: Context) {
            isEnabled = false

            // End all active calls
            synchronized(connectionLock) {
                sessionToConnection.values.forEach { connection ->
                    connection.setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
                    connection.destroy()
                }
                sessionToConnection.clear()
                conferencePrimarySession = null
                conferenceMergedAwaySessions.clear()
            }

            // Unregister phone account
            synchronized(phoneAccountLock) {
                phoneAccountHandle?.let { handle ->
                    try {
                        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                        if (telecomManager != null) {
                            telecomManager.unregisterPhoneAccount(handle)
                        } else {
                            PortsipLogger.w(COMPONENT, "TelecomManager not available for unregistering phone account")
                        }
                    } catch (e: Exception) {
                        PortsipLogger.e(COMPONENT, "Failed to unregister phone account: ${e.message}")
                    }
                }
            }

            PortsipLogger.d(COMPONENT, "ConnectionService disabled")
        }

        /**
         * Reports an outgoing call to the system.
         * Creates a Connection and registers it with TelecomManager.
         *
         * @param context Application context
         * @param sessionId PortSIP session ID
         * @param callee The callee's identifier
         * @param hasVideo Whether the call has video
         * @param displayName Name shown in the system call UI (callee if null)
         */
        fun reportOutgoingCall(
            context: Context,
            sessionId: Long,
            callee: String,
            hasVideo: Boolean,
            displayName: String? = null
        ) {
            if (!isEnabled) {
                PortsipLogger.d(COMPONENT, "ConnectionService not enabled, skipping outgoing call report")
                return
            }

            val handle = synchronized(phoneAccountLock) {
                phoneAccountHandle
            } ?: run {
                PortsipLogger.e(COMPONENT, "Phone account handle not initialized")
                return
            }

            // Reap connections Telecom already considers finished (ghosts from a
            // previous call whose SIP BYE never made it out). We must NOT reap a
            // genuinely active/held call: a conference adds a second call while the
            // first is still up (held), and both need to coexist so the system UI
            // can offer Hold/Swap. Only DISCONNECTED leftovers are cleared.
            synchronized(connectionLock) {
                val stale = sessionToConnection.filterValues {
                    it.state == Connection.STATE_DISCONNECTED
                }
                if (stale.isNotEmpty()) {
                    PortsipLogger.w(
                        COMPONENT,
                        "Reaping ${stale.size} disconnected connection(s) before new call"
                    )
                    stale.forEach { (sid, conn) ->
                        conn.destroy()
                        sessionToConnection.remove(sid)
                    }
                }
            }

            try {
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                if (telecomManager == null) {
                    PortsipLogger.e(COMPONENT, "TelecomManager not available for reporting outgoing call")
                    PortsipEventBridge.shared.sendEvent(
                        "onConnectionServiceFailure",
                        mapOf(
                            PortsipConstants.EventKeys.SESSION_ID to sessionId,
                            PortsipConstants.EventKeys.REASON to "TelecomManager not available"
                        )
                    )
                    return
                }

                // Create URI for the callee
                val uri = Uri.fromParts(PhoneAccount.SCHEME_SIP, callee, null)
                val callExtras = Bundle().apply {
                    putLong(PortsipConstants.BundleExtras.SESSION_ID, sessionId)
                    putString(PortsipConstants.BundleExtras.CALLEE, callee)
                    putBoolean(PortsipConstants.BundleExtras.HAS_VIDEO, hasVideo)
                    displayName?.let {
                        putString(PortsipConstants.BundleExtras.DISPLAY_NAME, it)
                    }
                }
                val extras = Bundle().apply {
                    putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle)
                    putBundle(TelecomManager.EXTRA_OUTGOING_CALL_EXTRAS, callExtras)
                }

                // Request to place the call
                telecomManager.placeCall(uri, extras)

                PortsipLogger.d(COMPONENT, "Reported outgoing call for session $sessionId to $callee")
            } catch (e: SecurityException) {
                PortsipLogger.e(COMPONENT, "Security exception reporting outgoing call: ${e.message}")
            } catch (e: Exception) {
                PortsipLogger.e(COMPONENT, "Failed to report outgoing call: ${e.message}", e)
            }
        }

        /**
         * Reports that a call has connected.
         *
         * @param sessionId PortSIP session ID
         */
        fun reportCallConnected(sessionId: Long) {
            if (!isEnabled) return

            synchronized(connectionLock) {
                sessionToConnection[sessionId]?.let { connection ->
                    connection.setActive()
                    PortsipLogger.d(COMPONENT, "Call connected for session $sessionId")
                }
            }
        }

        /**
         * Reports that a call has ended.
         *
         * @param sessionId PortSIP session ID
         * @param reason The reason the call ended
         */
        fun reportCallEnded(sessionId: Long, reason: Int = DisconnectCause.REMOTE) {
            if (!isEnabled) return

            synchronized(connectionLock) {
                sessionToConnection[sessionId]?.let { connection ->
                    connection.setDisconnected(DisconnectCause(reason))
                    connection.destroy()
                    sessionToConnection.remove(sessionId)
                    // No calls left → forget the route intent so the next call
                    // starts on the earpiece, and withdraw our communication-device
                    // request so it can't pin the next call's audio.
                    if (sessionToConnection.isEmpty()) {
                        desiredRoute = ROUTE_EARPIECE
                        clearCommDeviceRequest(null)
                    }
                    PortsipLogger.d(COMPONENT, "Call ended for session $sessionId with reason $reason")
                }
            }
        }

        /**
         * Collapses a merged conference to a single system call: ends the
         * connections for the merged-away legs (their SIP sessions stay live in
         * the SDK conference bridge) so the OS shows one call, not several.
         *
         * @param primarySessionId The leg whose connection represents the conference
         * @param mergedAwaySessionIds The other legs whose connections to end
         */
        fun reportConferenceMerged(primarySessionId: Long, mergedAwaySessionIds: List<Long>) {
            if (!isEnabled) return

            synchronized(connectionLock) {
                mergedAwaySessionIds.forEach { sessionId ->
                    sessionToConnection[sessionId]?.let { connection ->
                        connection.setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
                        connection.destroy()
                        sessionToConnection.remove(sessionId)
                    }
                }
                conferencePrimarySession = primarySessionId
                conferenceMergedAwaySessions.clear()
                conferenceMergedAwaySessions.addAll(mergedAwaySessionIds)
                // Surviving call must not look held in the system UI.
                sessionToConnection[primarySessionId]?.setActive()
            }
        }

        /**
         * A SIP session is ending. If it's the merged-conference primary and
         * a merged-away leg survives, the Connection is re-keyed to the
         * survivor (the new primary) and its session id is returned — the
         * caller must then NOT destroy the Connection. Returns null when no
         * transfer applies, after pruning [endingSessionId] from the tracking.
         */
        fun transferSystemCallIfNeeded(endingSessionId: Long): Long? {
            synchronized(connectionLock) {
                if (conferencePrimarySession != endingSessionId) {
                    conferenceMergedAwaySessions.remove(endingSessionId)
                    return null
                }
                val survivor = conferenceMergedAwaySessions.firstOrNull()
                val connection = sessionToConnection.remove(endingSessionId)
                if (survivor == null || connection == null) {
                    conferencePrimarySession = null
                    conferenceMergedAwaySessions.clear()
                    return null
                }
                connection.adoptSession(survivor)
                sessionToConnection[survivor] = connection
                conferenceMergedAwaySessions.remove(survivor)
                conferencePrimarySession = survivor
                PortsipLogger.d(
                    COMPONENT,
                    "System call transferred from ended session $endingSessionId to $survivor"
                )
                return survivor
            }
        }

        /**
         * The conference is over (bridge destroyed) — stop tracking it.
         * Existing session→Connection mappings are untouched.
         */
        fun clearConferenceTracking() {
            synchronized(connectionLock) {
                conferencePrimarySession = null
                conferenceMergedAwaySessions.clear()
            }
        }

        /**
         * Updates the name the system call UI shows for a call — used after a
         * transferred Connection (see [transferSystemCallIfNeeded]) so it stops
         * displaying the leg that ended.
         */
        fun updateCallDisplay(sessionId: Long, displayName: String) {
            if (!isEnabled) return

            synchronized(connectionLock) {
                sessionToConnection[sessionId]?.setCallerDisplayName(
                    displayName, TelecomManager.PRESENTATION_ALLOWED
                )
            }
        }

        /**
         * Updates the hold state of a call.
         *
         * @param sessionId PortSIP session ID
         * @param onHold Whether the call is on hold
         */
        fun reportCallHeld(sessionId: Long, onHold: Boolean) {
            if (!isEnabled) return

            synchronized(connectionLock) {
                sessionToConnection[sessionId]?.let { connection ->
                    if (onHold) {
                        connection.setOnHold()
                    } else {
                        connection.setActive()
                    }
                    PortsipLogger.d(COMPONENT, "Call hold state updated for session $sessionId: $onHold")
                }
            }
        }

        /**
         * Updates the mute state of a call.
         *
         * @param sessionId PortSIP session ID
         * @param muted Whether the call is muted
         */
        fun reportCallMuted(sessionId: Long, muted: Boolean) {
            if (!isEnabled) return

            // Audio muting is handled through PortSIP SDK, not ConnectionService
            // This method exists for API parity with iOS CallKit
            PortsipLogger.d(COMPONENT, "Call mute state reported for session $sessionId: $muted")
        }

        /**
         * Updates the speaker state to prevent duplicate events.
         *
         * @param enabled Whether the speaker is enabled
         */
        fun updateSpeakerState(enabled: Boolean) {
            lastSpeakerState = enabled
        }

        // --- Telecom is the single owner of Android audio routing -------------
        // Resuming a leg makes Telecom reset the route to the earpiece; we track
        // the user's intended route and, during the reconfiguration window those
        // ops open, re-assert it through Telecom instead of mirroring the reset.

        val ROUTE_EARPIECE = CallAudioState.ROUTE_EARPIECE
        val ROUTE_SPEAKER = CallAudioState.ROUTE_SPEAKER
        val ROUTE_BLUETOOTH = CallAudioState.ROUTE_BLUETOOTH
        val ROUTE_WIRED_HEADSET = CallAudioState.ROUTE_WIRED_HEADSET

        /** The user's intended audio route (a CallAudioState.ROUTE_* value). */
        @Volatile
        private var desiredRoute = CallAudioState.ROUTE_EARPIECE

        /** True while a hold/swap/merge/connect is renegotiating audio. */
        @Volatile
        private var audioReconfiguring = false

        /** Invalidates a stale reconfiguration-window auto-close. */
        @Volatile
        private var reconfigGeneration = 0

        private val mainHandler = Handler(Looper.getMainLooper())

        fun getDesiredRoute(): Int = desiredRoute
        fun isAudioReconfiguring(): Boolean = audioReconfiguring

        /** Records the user's intended audio route. */
        fun setDesiredRoute(route: Int) {
            desiredRoute = route
        }

        /**
         * Opens the audio-reconfiguration window. Called at every hold/unhold/
         * swap/merge/connect so the route Telecom resets while renegotiating media
         * is re-asserted rather than read as the user picking the earpiece.
         * Auto-closes ~2.5s later. Harmless on a plain call.
         */
        fun beginAudioReconfiguration() {
            audioReconfiguring = true
            val gen = ++reconfigGeneration
            mainHandler.postDelayed({
                if (reconfigGeneration == gen) audioReconfiguring = false
            }, 2500L)
        }

        /**
         * Routes the active call's audio to [route] (a CallAudioState.ROUTE_*)
         * through Telecom, the single owner. Also records it as the desired route
         * so it survives a subsequent reconfiguration. No-ops without a live call.
         */
        fun applyAudioRoute(route: Int): Boolean {
            if (!isEnabled) return false
            synchronized(connectionLock) {
                // Never target a disconnected Connection — Telecom ignores route
                // requests on dead calls, silently dropping the change.
                val live = sessionToConnection.values.filter {
                    it.state != Connection.STATE_DISCONNECTED
                }
                val connection = live.firstOrNull {
                    it.state == Connection.STATE_ACTIVE
                } ?: live.firstOrNull() ?: return false
                desiredRoute = route
                connection.setAudioRoute(route)
                PortsipLogger.d(COMPONENT, "applyAudioRoute($route) via Telecom")
                return true
            }
        }

        /** True while at least one Connection is still alive. */
        private fun hasLiveConnection(): Boolean {
            synchronized(connectionLock) {
                return sessionToConnection.values.any {
                    it.state != Connection.STATE_DISCONNECTED
                }
            }
        }

        /**
         * Physically applies an audio route via AudioManager.setCommunicationDevice
         * (API 31+) — the single physical router. Unlike the SDK's setAudioDevice,
         * it handles USB headsets and forces the speaker with a headset plugged in.
         */
        fun routeToDevice(context: Context, route: Int) {
            // A new request invalidates any retries still pending for an old one.
            val gen = ++routeToDeviceGeneration
            routeToDeviceAttempt(context, route, attempt = 0, gen = gen)
        }

        /** Cancels pending [routeToDeviceAttempt] retries when a newer route arrives. */
        @Volatile
        private var routeToDeviceGeneration = 0

        /** The device type of this app's outstanding setCommunicationDevice
         *  request, or null when none. A stale request stays pinned in the audio
         *  policy and yanks audio off a route the system later moves to. */
        @Volatile
        private var requestedCommDeviceType: Int? = null

        private fun routeToDeviceAttempt(context: Context, route: Int, attempt: Int, gen: Int) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
            val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            // Telecom's BluetoothRouteManager owns the SCO/BLE link — pinning our
            // own request over it drops audio when the link renegotiates. Just
            // withdraw any request we hold and let the SCO link carry the call.
            if (route == ROUTE_BLUETOOTH) {
                clearCommDeviceRequest(am)
                return
            }
            val types = when (route) {
                ROUTE_SPEAKER -> intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
                ROUTE_EARPIECE -> intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE)
                else -> intArrayOf( // wired / USB headset
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_USB_HEADSET,
                )
            }
            val device = am.availableCommunicationDevices.firstOrNull { it.type in types }
            if (device == null) {
                // A just-connected headset may not be listed yet (Telecom reports
                // the route first) — retry briefly or the call stays on the
                // previous output.
                if (attempt < 10) {
                    PortsipLogger.d(
                        COMPONENT,
                        "routeToDevice($route): device not listed yet, retrying (${attempt + 1})"
                    )
                    mainHandler.postDelayed({
                        if (gen == routeToDeviceGeneration && hasLiveConnection()) {
                            routeToDeviceAttempt(context, route, attempt + 1, gen)
                        }
                    }, 300L)
                } else {
                    PortsipLogger.w(COMPONENT, "routeToDevice($route): no device for route")
                }
                return
            }
            // Skip only when OUR request already points there — re-applying churns
            // the output, but the system merely being on the right device isn't
            // enough (a stale request for another output would still pull audio
            // away once the policy re-evaluates).
            if (requestedCommDeviceType == device.type &&
                am.communicationDevice?.type == device.type
            ) {
                PortsipLogger.d(COMPONENT, "routeToDevice($route): already on ${device.type}, skipping")
                return
            }
            val ok = am.setCommunicationDevice(device)
            if (ok) requestedCommDeviceType = device.type
            PortsipLogger.d(COMPONENT, "routeToDevice($route): setCommunicationDevice(${device.type}) -> $ok")
        }

        /** Withdraws this app's communication-device request, if any. */
        private fun clearCommDeviceRequest(am: AudioManager?) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
            if (requestedCommDeviceType == null) return
            val audioManager = am
                ?: instance?.applicationContext?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                ?: return
            audioManager.clearCommunicationDevice()
            requestedCommDeviceType = null
            PortsipLogger.d(COMPONENT, "cleared communication-device request")
        }

        /**
         * Builds the {availablePorts, currentPort} map the Flutter audio-route
         * picker expects, from a Telecom CallAudioState. Generic names — Telecom
         * doesn't carry a wired-headset name and the BT name needs runtime
         * permissions, so the picker shows the route type.
         */
        fun routeStateMap(state: CallAudioState): Map<String, Any> {
            fun port(route: Int): Map<String, Any> = when (route) {
                ROUTE_SPEAKER -> mapOf("uid" to "route:speaker", "name" to "Speaker", "kind" to "builtInSpeaker")
                ROUTE_BLUETOOTH -> mapOf("uid" to "route:bluetooth", "name" to "Bluetooth", "kind" to "bluetooth")
                ROUTE_WIRED_HEADSET -> mapOf("uid" to "route:headset", "name" to "Headphones", "kind" to "headphones")
                else -> mapOf("uid" to "route:earpiece", "name" to "Phone", "kind" to "builtInReceiver")
            }
            val mask = state.supportedRouteMask
            val ports = mutableListOf<Map<String, Any>>()
            // A wired headset replaces the earpiece (Android drops EARPIECE from
            // the mask while one is plugged) — show the headset in its place.
            if (mask and ROUTE_WIRED_HEADSET != 0) {
                ports.add(port(ROUTE_WIRED_HEADSET))
            } else if (mask and ROUTE_EARPIECE != 0) {
                ports.add(port(ROUTE_EARPIECE))
            }
            if (mask and ROUTE_BLUETOOTH != 0) ports.add(port(ROUTE_BLUETOOTH))
            if (mask and ROUTE_SPEAKER != 0) ports.add(port(ROUTE_SPEAKER))
            return mapOf("availablePorts" to ports, "currentPort" to port(state.route))
        }

        /**
         * Gets the session ID for a given connection.
         *
         * @param connection The Connection object
         * @return The session ID, or null if not found
         */
        fun getSessionId(connection: Connection): Long? {
            synchronized(connectionLock) {
                return sessionToConnection.entries.find { it.value == connection }?.key
            }
        }

        /**
         * Registers a connection for a session.
         *
         * @param sessionId PortSIP session ID
         * @param connection The Connection object
         */
        fun registerConnection(sessionId: Long, connection: PortsipConnection) {
            synchronized(connectionLock) {
                sessionToConnection[sessionId] = connection
            }
        }

        /**
         * Disposes of the ConnectionService.
         * Should be called when the plugin is being detached.
         *
         * @param context Application context
         */
        fun dispose(context: Context) {
            clearCommDeviceRequest(
                context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            )
            disable(context)
            synchronized(phoneAccountLock) {
                phoneAccountHandle = null
            }
            lastSpeakerState = null
            desiredRoute = ROUTE_EARPIECE
            audioReconfiguring = false
            instance = null
            PortsipLogger.d(COMPONENT, "ConnectionService disposed")
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        PortsipLogger.d(COMPONENT, "ConnectionService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        PortsipLogger.d(COMPONENT, "ConnectionService destroyed")
    }

    /**
     * Called when an outgoing call is requested.
     * Creates and returns a Connection for the call.
     */
    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        PortsipLogger.d(COMPONENT, "Creating outgoing connection")

        val sessionId = request?.extras?.getLong(PortsipConstants.BundleExtras.SESSION_ID) ?: -1L
        val callee = request?.extras?.getString(PortsipConstants.BundleExtras.CALLEE) ?: ""
        val hasVideo = request?.extras?.getBoolean(PortsipConstants.BundleExtras.HAS_VIDEO) ?: false
        val displayName =
            request?.extras?.getString(PortsipConstants.BundleExtras.DISPLAY_NAME)

        val connection = PortsipConnection(applicationContext, sessionId).apply {
            setAddress(request?.address, TelecomManager.PRESENTATION_ALLOWED)
            setCallerDisplayName(displayName ?: callee, TelecomManager.PRESENTATION_ALLOWED)
            connectionCapabilities = Connection.CAPABILITY_MUTE or
                    Connection.CAPABILITY_HOLD or
                    Connection.CAPABILITY_SUPPORT_HOLD

            if (hasVideo) {
                connectionCapabilities = connectionCapabilities or Connection.CAPABILITY_CAN_UPGRADE_TO_VIDEO
            }

            // Set initial state to dialing
            setDialing()
        }

        // Register the connection
        if (sessionId > 0) {
            registerConnection(sessionId, connection)
        }

        return connection
    }

    /**
     * Called when an outgoing connection request fails.
     */
    override fun onCreateOutgoingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        PortsipLogger.e(COMPONENT, "Failed to create outgoing connection")

        val sessionId = request?.extras?.getLong(PortsipConstants.BundleExtras.SESSION_ID) ?: -1L
        if (sessionId > 0) {
            // Notify Flutter about the failure
            PortsipEventBridge.shared.sendEvent(
                "onConnectionServiceFailure",
                mapOf(
                    PortsipConstants.EventKeys.SESSION_ID to sessionId,
                    PortsipConstants.EventKeys.REASON to "Failed to create connection"
                )
            )
        }
    }

    /**
     * Called when an incoming connection is requested.
     * Note: This plugin is designed for outgoing calls only.
     */
    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection? {
        // Not implemented - this plugin supports outgoing calls only
        PortsipLogger.d(COMPONENT, "Incoming connection not supported")
        return null
    }

    /**
     * Called when an incoming connection request fails.
     */
    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        // Not implemented - this plugin supports outgoing calls only
        PortsipLogger.d(COMPONENT, "Incoming connection failed - not supported")
    }
}
