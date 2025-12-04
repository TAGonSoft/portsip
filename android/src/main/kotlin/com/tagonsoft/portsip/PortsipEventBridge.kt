package com.tagonsoft.portsip

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge class that handles communication between the PortSIP SDK and Flutter.
 * This class acts as an event dispatcher, forwarding PortSIP SDK events to the Flutter side
 * through a Flutter method channel. It follows the singleton pattern to ensure a single
 * point of communication throughout the application lifecycle.
 *
 * Thread Safety: All events are dispatched to the main thread before invoking Flutter methods,
 * ensuring thread-safe communication regardless of which thread the SDK callbacks arrive on.
 */
class PortsipEventBridge private constructor() {

    private var channel: MethodChannel? = null

    /// Handler for dispatching events to the main thread
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val COMPONENT = "EventBridge"

        /**
         * Singleton instance of PortsipEventBridge
         */
        val shared = PortsipEventBridge()
    }

    /**
     * Sets the Flutter method channel for communication with the Flutter side.
     * This method must be called during plugin initialization to establish the bridge
     * between native Android code and Flutter.
     *
     * @param methodChannel The Flutter method channel instance used to invoke
     *   methods on the Flutter side and send events from the PortSIP SDK
     */
    fun setChannel(methodChannel: MethodChannel) {
        channel = methodChannel
        PortsipLogger.d(COMPONENT, "Flutter channel set: ${channel != null}")
    }

    /**
     * Cleans up resources associated with the event bridge.
     * This method should be called when the plugin is detached from the engine
     * to prevent memory leaks from pending handler messages.
     */
    fun dispose() {
        PortsipLogger.d(COMPONENT, "Disposing event bridge")
        mainHandler.removeCallbacksAndMessages(null)
        channel = null
    }

    /**
     * Sends a PortSIP SDK event to the Flutter side through the method channel.
     * This method is called by the PortSIP SDK delegate methods to forward events
     * such as registration status, incoming calls, call state changes, etc.
     *
     * Thread Safety: Events are always dispatched to the main thread before invoking
     * Flutter's MethodChannel, as required by Flutter's platform channel contract.
     *
     * @param name The name of the event to send (e.g., "onRegisterSuccess", "onInviteIncoming")
     * @param data Optional map containing event-specific data such as session IDs,
     *     caller information, status codes, and other relevant parameters
     */
    fun sendEvent(name: String, data: Map<String, Any?>? = null) {
        PortsipLogger.logEvent(COMPONENT, name)

        // Dispatch to main thread to ensure thread-safe Flutter channel invocation
        if (Looper.myLooper() == Looper.getMainLooper()) {
            // Already on main thread, invoke directly
            if (channel == null) {
                PortsipLogger.w(COMPONENT, "⚠️ Event '$name' dropped: Flutter channel is null. Ensure setChannel() is called during plugin initialization.")
            } else {
                channel?.invokeMethod(name, data)
            }
        } else {
            // Post to main thread
            mainHandler.post {
                if (channel == null) {
                    PortsipLogger.w(COMPONENT, "⚠️ Event '$name' dropped: Flutter channel is null. Ensure setChannel() is called during plugin initialization.")
                } else {
                    channel?.invokeMethod(name, data)
                }
            }
        }
    }
}
