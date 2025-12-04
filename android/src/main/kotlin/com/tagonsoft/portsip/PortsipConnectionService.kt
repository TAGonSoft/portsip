package com.tagonsoft.portsip

import android.content.ComponentName
import android.content.Context
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
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
                            PhoneAccount.CAPABILITY_CALL_PROVIDER or
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
         */
        fun reportOutgoingCall(context: Context, sessionId: Long, callee: String, hasVideo: Boolean) {
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

                // Build extras bundle
                val extras = Bundle().apply {
                    putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle)
                    putLong(PortsipConstants.BundleExtras.SESSION_ID, sessionId)
                    putString(PortsipConstants.BundleExtras.CALLEE, callee)
                    putBoolean(PortsipConstants.BundleExtras.HAS_VIDEO, hasVideo)
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
                    PortsipLogger.d(COMPONENT, "Call ended for session $sessionId with reason $reason")
                }
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
            disable(context)
            synchronized(phoneAccountLock) {
                phoneAccountHandle = null
            }
            lastSpeakerState = null
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

        val connection = PortsipConnection(applicationContext, sessionId).apply {
            setAddress(request?.address, TelecomManager.PRESENTATION_ALLOWED)
            setCallerDisplayName(callee, TelecomManager.PRESENTATION_ALLOWED)
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
