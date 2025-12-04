package com.tagonsoft.portsip

/**
 * Constants used throughout the PortSIP plugin.
 * Centralizes magic strings to improve maintainability and prevent typos.
 */
object PortsipConstants {

    /**
     * Bundle extra keys used for passing data between components.
     * These are used in ConnectionService for outgoing call data.
     */
    object BundleExtras {
        /** Key for the PortSIP session ID (Long) */
        const val SESSION_ID = "sessionId"

        /** Key for the callee identifier (String) */
        const val CALLEE = "callee"

        /** Key for whether the call has video (Boolean) */
        const val HAS_VIDEO = "hasVideo"
    }

    /**
     * Event data keys used when sending events to Flutter.
     */
    object EventKeys {
        /** Key for session ID in event data */
        const val SESSION_ID = "sessionId"

        /** Key for reason/error message */
        const val REASON = "reason"

        /** Key for hold state */
        const val ON_HOLD = "onHold"

        /** Key for mute state */
        const val MUTED = "muted"

        /** Key for speaker enabled state */
        const val ENABLED = "enabled"

        /** Key for DTMF digit */
        const val DIGIT = "digit"
    }
}

/**
 * DTMF (Dual-Tone Multi-Frequency) codes for dial pad tones.
 * These codes map to the standard DTMF keypad digits used in telephony.
 *
 * @property code The numeric code sent to the PortSIP SDK
 * @property character The character representation of the DTMF tone
 */
enum class DTMFCode(val code: Int, val character: Char) {
    DIGIT_0(0, '0'),
    DIGIT_1(1, '1'),
    DIGIT_2(2, '2'),
    DIGIT_3(3, '3'),
    DIGIT_4(4, '4'),
    DIGIT_5(5, '5'),
    DIGIT_6(6, '6'),
    DIGIT_7(7, '7'),
    DIGIT_8(8, '8'),
    DIGIT_9(9, '9'),
    STAR(10, '*'),
    POUND(11, '#');

    companion object {
        /**
         * Creates a DTMFCode from a character.
         * @param char The character to convert (0-9, *, #)
         * @return The corresponding DTMFCode, or null if invalid
         */
        fun fromCharacter(char: Char): DTMFCode? {
            return values().find { it.character == char }
        }

        /**
         * Creates a DTMFCode from a numeric code.
         * @param code The numeric code (0-11)
         * @return The corresponding DTMFCode, or null if invalid
         */
        fun fromCode(code: Int): DTMFCode? {
            return values().find { it.code == code }
        }
    }
}
