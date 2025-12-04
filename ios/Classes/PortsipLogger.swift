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

    /// Log method call: ▶ methodName | args: {...}
    static func logCall(_ component: String, _ method: String, _ args: [String: Any]? = nil) {
        guard isEnabled else { return }
        if let args = args {
            print("\(TAG) [\(component)] ▶ \(method) | args: \(args)")
        } else {
            print("\(TAG) [\(component)] ▶ \(method)")
        }
    }

    /// Log method response: ◀ methodName | ✓/❌ result: value
    static func logResponse(_ component: String, _ method: String, _ result: Any?) {
        guard isEnabled else { return }
        let status: String
        if let intResult = result as? Int, intResult < 0 {
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
