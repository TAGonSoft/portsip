package com.tagonsoft.portsip

import android.util.Log

/**
 * Centralized logging utility for the PortSIP plugin.
 *
 * All logs respect the `setLogsEnabled()` setting from Flutter.
 * When disabled, no logs are output. When enabled, all logs appear in Logcat.
 */
object PortsipLogger {

    private const val TAG = "[PortSIP-Android]"

    /** Whether logging is enabled. Controlled by `setLogsEnabled()` from Flutter. */
    @Volatile
    var isEnabled: Boolean = false

    /** Debug log */
    fun d(component: String, message: String) {
        if (isEnabled) Log.d(TAG, "[$component] $message")
    }

    /** Warning log */
    fun w(component: String, message: String) {
        if (isEnabled) Log.w(TAG, "[$component] $message")
    }

    /** Error log */
    fun e(component: String, message: String) {
        if (isEnabled) Log.e(TAG, "[$component] $message")
    }

    /** Error log with exception */
    fun e(component: String, message: String, throwable: Throwable) {
        if (isEnabled) Log.e(TAG, "[$component] $message", throwable)
    }

    /** Argument keys whose values are never printed — see [redactArgs]. */
    private val SECRET_ARGS = setOf("password", "licenseKey")

    /**
     * The arguments with secrets replaced by their length. `register` carries
     * the SIP password and `setLicenseKey` the license key; logging is on in
     * release builds too, so both would otherwise sit in Logcat — and a
     * password copied out of a log pasted into a ticket still works.
     */
    private fun redactArgs(args: Map<String, Any?>): Map<String, Any?> =
        args.mapValues { (key, value) ->
            if (key in SECRET_ARGS) {
                "<redacted, ${(value as? String)?.length ?: 0} chars>"
            } else {
                value
            }
        }

    /** Log method call: ▶ methodName | args: {...} */
    fun logCall(component: String, method: String, args: Map<String, Any?>? = null) {
        if (!isEnabled) return
        val msg = if (args != null) "▶ $method | args: ${redactArgs(args)}" else "▶ $method"
        Log.d(TAG, "[$component] $msg")
    }

    /** Log method response: ◀ methodName | ✓/❌ result: value */
    fun logResponse(component: String, method: String, result: Any?) {
        if (!isEnabled) return
        // beginOutgoingCall hands out negative pending ids by design (0 = failed).
        val failed = if (method == "beginOutgoingCall") result == 0 else result is Int && result < 0
        val status = if (failed) "❌" else "✓"
        Log.d(TAG, "[$component] ◀ $method | $status result: $result")
    }

    /** Log event: ⚡ EVENT: eventName */
    fun logEvent(component: String, eventName: String) {
        if (isEnabled) Log.d(TAG, "[$component] ⚡ EVENT: $eventName")
    }
}
