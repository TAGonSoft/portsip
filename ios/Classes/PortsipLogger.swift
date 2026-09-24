import Foundation

/// Centralized logging utility for the PortSIP plugin.
///
/// All logs respect the `setLogsEnabled()` setting from Flutter.
/// When disabled, no logs are output. When enabled, all logs appear in console.
class PortsipLogger {

    private static let TAG = "[PortSIP-iOS]"

    /// Whether logging is enabled. Controlled by `setLogsEnabled()` from Flutter.
    static var isEnabled: Bool = false

    /// Debug log
    static func d(_ component: String, _ message: String) {
        guard isEnabled else { return }
        print("\(TAG) [\(component)] \(message)")
    }

    /// Warning log
    static func w(_ component: String, _ message: String) {
        guard isEnabled else { return }
        print("\(TAG) [\(component)] ⚠️ \(message)")
    }

    /// Error log
    static func e(_ component: String, _ message: String) {
        guard isEnabled else { return }
        print("\(TAG) [\(component)] ❌ \(message)")
    }

    /// Argument keys whose values are never printed — see `redactArgs`.
    private static let secretArgs: Set<String> = ["password", "licenseKey"]

    /// The arguments with secrets replaced by their length. `register` carries
    /// the SIP password and `setLicenseKey` the license key; logging is on in
    /// release builds too, so both would otherwise sit in the device log — and
    /// a password copied out of a log pasted into a ticket still works.
    private static func redactArgs(_ args: [String: Any]) -> [String: Any] {
        args.reduce(into: [String: Any]()) { redacted, entry in
            guard secretArgs.contains(entry.key) else {
                redacted[entry.key] = entry.value
                return
            }
            let length = (entry.value as? String)?.count ?? 0
            redacted[entry.key] = "<redacted, \(length) chars>"
        }
    }

    /// Log method call: ▶ methodName | args: {...}
    static func logCall(_ component: String, _ method: String, _ args: [String: Any]? = nil) {
        guard isEnabled else { return }
        if let args = args {
            print("\(TAG) [\(component)] ▶ \(method) | args: \(redactArgs(args))")
        } else {
            print("\(TAG) [\(component)] ▶ \(method)")
        }
    }

    /// Log method response: ◀ methodName | ✓/❌ result: value
    static func logResponse(_ component: String, _ method: String, _ result: Any?) {
        guard isEnabled else { return }
        let status: String
        // beginOutgoingCall hands out negative pending ids by design (0 / -1 = failed).
        if let intResult = result as? Int,
           method == "beginOutgoingCall" ? intResult == 0 || intResult == -1 : intResult < 0 {
            status = "❌"
        } else {
            status = "✓"
        }
        print("\(TAG) [\(component)] ◀ \(method) | \(status) result: \(String(describing: result))")
    }

    /// Log event: ⚡ EVENT: eventName
    static func logEvent(_ component: String, _ eventName: String) {
        guard isEnabled else { return }
        print("\(TAG) [\(component)] ⚡ EVENT: \(eventName)")
    }
}
