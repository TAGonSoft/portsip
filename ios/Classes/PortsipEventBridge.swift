import Flutter

/// Bridge class that handles communication between the PortSIP SDK and Flutter.
/// This class acts as an event dispatcher, forwarding PortSIP SDK events to the Flutter side
/// through a Flutter method channel. It follows the singleton pattern to ensure a single
/// point of communication throughout the application lifecycle.
class PortsipEventBridge {
    private static let COMPONENT = "EventBridge"

    static let shared: PortsipEventBridge = PortsipEventBridge()
    var channel: FlutterMethodChannel?

    /// Private initializer to enforce singleton pattern
    private init() { }
    
    /// Sets the Flutter method channel for communication with the Flutter side.
    /// This method must be called during plugin initialization to establish the bridge
    /// between native iOS code and Flutter.
    ///
    /// - Parameter flutterMethodChanel: The Flutter method channel instance used to invoke
    ///   methods on the Flutter side and send events from the PortSIP SDK
    func setChannel(flutterMethodChanel: FlutterMethodChannel) {
        channel = flutterMethodChanel
    }
    
    /// Sends a PortSIP SDK event to the Flutter side through the method channel.
    /// This method is called by the PortSIP SDK delegate methods to forward events
    /// such as registration status, incoming calls, call state changes, etc.
    ///
    /// - Parameters:
    ///   - name: The name of the event to send (e.g., "onRegisterSuccess", "onInviteIncoming")
    ///   - data: Optional dictionary containing event-specific data such as session IDs,
    ///     caller information, status codes, and other relevant parameters
    func sendEvent(name: String, data: [String: Any]?) {
        PortsipLogger.logEvent(PortsipEventBridge.COMPONENT, name)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let channel = self.channel else {
                PortsipLogger.w(PortsipEventBridge.COMPONENT, "Event '\(name)' dropped: Flutter channel is nil. Ensure setChannel() is called during plugin initialization.")
                return
            }
            channel.invokeMethod(name, arguments: data)
        }
    }

    /// Sends a CallKit failure event to the Flutter side.
    /// This is called when CallKit fails to report an outgoing call.
    ///
    /// - Parameters:
    ///   - sessionId: The PortSIP session ID of the failed call
    ///   - error: The error description
    func sendCallKitFailure(sessionId: Int, error: String) {
        sendEvent(name: "onCallKitFailure", data: [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.error: error
        ])
    }
}
