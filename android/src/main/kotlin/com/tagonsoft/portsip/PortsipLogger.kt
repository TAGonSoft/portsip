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

    /** Log method call: ▶ methodName | args: {...} */
    fun logCall(component: String, method: String, args: Map<String, Any?>? = null) {
        if (!isEnabled) return
        val msg = if (args != null) "▶ $method | args: $args" else "▶ $method"
        Log.d(TAG, "[$component] $msg")
    }

    /** Log method response: ◀ methodName | ✓/❌ result: value */
    fun logResponse(component: String, method: String, result: Any?) {
        if (!isEnabled) return
        val status = if (result is Int && result < 0) "❌" else "✓"
        Log.d(TAG, "[$component] ◀ $method | $status result: $result")
    }

    /** Log event: ⚡ EVENT: eventName */
    fun logEvent(component: String, eventName: String) {
        if (isEnabled) Log.d(TAG, "[$component] ⚡ EVENT: $eventName")
    }
}
