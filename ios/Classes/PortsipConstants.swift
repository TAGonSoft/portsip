import Foundation

/// Constants used throughout the PortSIP plugin.
/// Centralizes magic strings to improve maintainability and prevent typos.
enum PortsipConstants {

    /// Event data keys used when sending events to Flutter.
    enum EventKeys {
        /// Key for session ID in event data
        static let sessionId = "sessionId"

        /// Key for reason/error message
        static let reason = "reason"

        /// Key for hold state
        static let onHold = "onHold"

        /// Key for mute state
        static let muted = "muted"

        /// Key for speaker enabled state
        static let enableSpeaker = "enableSpeaker"

        /// Key for DTMF digit/digits
        static let digits = "digits"

        /// Key for error message
        static let error = "error"

        /// Key for status text
        static let statusText = "statusText"

        /// Key for status code
        static let statusCode = "statusCode"

        /// Key for SIP message
        static let sipMessage = "sipMessage"

        /// Key for caller display name
        static let callerDisplayName = "callerDisplayName"

        /// Key for caller
        static let caller = "caller"

        /// Key for callee display name
        static let calleeDisplayName = "calleeDisplayName"

        /// Key for callee
        static let callee = "callee"

        /// Key for audio codecs
        static let audioCodecs = "audioCodecs"

        /// Key for video codecs
        static let videoCodecs = "videoCodecs"

        /// Key for exists audio flag
        static let existsAudio = "existsAudio"

        /// Key for exists video flag
        static let existsVideo = "existsVideo"

        /// Key for failure code
        static let code = "code"
    }

    /// Argument keys used when receiving method calls from Flutter.
    enum ArgumentKeys {
        static let sessionId = "sessionId"
        static let callee = "callee"
        static let hasVideo = "hasVideo"
        static let onHold = "onHold"
        static let muted = "muted"
        static let muteVideo = "muteVideo"
        static let enableSpeaker = "enableSpeaker"
        static let digit = "digit"
    }
}
