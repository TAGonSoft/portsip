import Flutter
import UIKit
import PortSIPVoIPSDK

/// Flutter plugin for PortSIP VoIP SDK integration
///
/// This class serves as the main entry point for the PortSIP Flutter plugin on iOS.
/// It handles method calls from Flutter and routes them to the PortsipController,
/// which manages the actual PortSIP SDK operations. The plugin supports SIP registration,
/// outgoing call management (make, hang up), and call controls (hold, mute, DTMF).
public class PortsipPlugin: NSObject, FlutterPlugin {
  /// Component name for logging
  private static let COMPONENT = "Plugin"

  /// Registers the plugin with the Flutter engine
  ///
  /// This method is called by Flutter during plugin registration. It sets up the method channel
  /// for bidirectional communication between Flutter and native iOS code.
  ///
  /// - Parameter registrar: The Flutter plugin registrar that manages plugin registration
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "portsip", binaryMessenger: registrar.messenger())
    let instance = PortsipPlugin()
    
    PortsipEventBridge.shared.setChannel(flutterMethodChanel: channel)
    
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

    /// Handles incoming method calls from Flutter
    ///
    /// This method receives all method calls from the Flutter side and routes them to the
    /// appropriate PortsipController methods based on the method name. It extracts arguments
    /// from the call and passes them to the controller, then returns the result back to Flutter.
    ///
    /// - Parameters:
    ///   - call: The Flutter method call containing the method name and arguments
    ///   - result: A callback to return the result back to Flutter
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let method = PortsipMethodCall(rawValue: call.method) else {
            result(FlutterMethodNotImplemented)
            return
        }
        
        switch method {
        case .initialize:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "initialize", arguments)
            let resultValue = PortsipController.shared.initialize(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "initialize", resultValue)
            result(resultValue)
        case .register:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "register", arguments)
            let resultValue = PortsipController.shared.register(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "register", resultValue)
            result(resultValue)
        case .registerServer:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "registerServer", arguments)
            let resultValue = PortsipController.shared.registerServer(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "registerServer", resultValue)
            result(resultValue)
        case .unRegister:
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "unRegister")
            PortsipController.shared.unRegister()
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "unRegister", "done")
            result(nil)
        case .makeCall:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "makeCall", arguments)
            let resultValue = PortsipController.shared.makeCall(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "makeCall", resultValue)
            result(resultValue)
        case .hangUp:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "hangUp", arguments)
            let resultValue = PortsipController.shared.hangUp(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "hangUp", resultValue)
            result(resultValue)
        case .hold:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "hold", arguments)
            let resultValue = PortsipController.shared.hold(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "hold", resultValue)
            result(resultValue)
        case .unHold:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "unHold", arguments)
            let resultValue = PortsipController.shared.unHold(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "unHold", resultValue)
            result(resultValue)
        case .muteSession:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "muteSession", arguments)
            let resultValue = PortsipController.shared.muteSession(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "muteSession", resultValue)
            result(resultValue)
        case .setLoudspeakerStatus:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "setLoudspeakerStatus", arguments)
            PortsipController.shared.setLoudspeakerStatus(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "setLoudspeakerStatus", "done")
            result(nil)
        case .sendDtmf:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "sendDtmf", arguments)
            let resultValue = PortsipController.shared.sendDtmf(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "sendDtmf", resultValue)
            result(resultValue)
        case .configureCallKit:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "configureCallKit", arguments)
            let appName = arguments["appName"] as? String ?? "VoIP App"
            let canUseCallKit = arguments["canUseCallKit"] as? Bool ?? true
            let iconTemplateImageName = arguments["iconTemplateImageName"] as? String

            PortsipCallKitProvider.shared.configure(
                appName: appName,
                canUseCallKit: canUseCallKit,
                iconTemplateImageName: iconTemplateImageName
            )
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "configureCallKit", "done")
            result(nil)
        case .enableCallKit:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "enableCallKit", arguments)
            let enabled = arguments["enabled"] as? Bool ?? true

            PortsipCallKitProvider.shared.setEnabled(enabled)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "enableCallKit", "done")
            result(nil)
        case .setLicenseKey:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "setLicenseKey", arguments)
            let resultValue = PortsipController.shared.setLicenseKey(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "setLicenseKey", resultValue)
            result(resultValue)
        case .setAudioCodecs:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "setAudioCodecs", arguments)
            let resultValue = PortsipController.shared.setAudioCodecs(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "setAudioCodecs", resultValue)
            result(resultValue)
        case .enableAudioManager:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "enableAudioManager", arguments)
            let resultValue = PortsipController.shared.enableAudioManager(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "enableAudioManager", resultValue)
            result(resultValue)
        case .setSrtpPolicy:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "setSrtpPolicy", arguments)
            let resultValue = PortsipController.shared.setSrtpPolicy(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "setSrtpPolicy", resultValue)
            result(resultValue)
        case .enable3GppTags:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "enable3GppTags", arguments)
            let resultValue = PortsipController.shared.enable3GppTags(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "enable3GppTags", resultValue)
            result(resultValue)
        case .setLogsEnabled:
            let arguments = call.arguments as? [String: Any] ?? [:]
            let enabled = arguments["enabled"] as? Bool ?? false
            PortsipLogger.isEnabled = enabled
            result(nil)
        case .enableCNG:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "enableCNG", arguments)
            let resultValue = PortsipController.shared.enableCNG(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "enableCNG", resultValue)
            result(resultValue)
        case .enableVAD:
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "enableVAD", arguments)
            let resultValue = PortsipController.shared.enableVAD(arguments: arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "enableVAD", resultValue)
            result(resultValue)
        case .dispose:
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "dispose")
            PortsipController.shared.dispose()
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "dispose", "done")
            result(nil)

        // MARK: - Android ConnectionService Methods (no-op on iOS)

        case .configureConnectionService:
            // No-op on iOS - ConnectionService is Android-specific
            // Use configureCallKit for iOS native call UI
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "configureConnectionService (no-op on iOS)", arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "configureConnectionService", 0)
            result(0) // Return success to indicate graceful handling

        case .enableConnectionService:
            // No-op on iOS - ConnectionService is Android-specific
            // Use enableCallKit for iOS native call UI
            let arguments = call.arguments as? [String: Any] ?? [:]
            PortsipLogger.logCall(PortsipPlugin.COMPONENT, "enableConnectionService (no-op on iOS)", arguments)
            PortsipLogger.logResponse(PortsipPlugin.COMPONENT, "enableConnectionService", 0)
            result(0) // Return success to indicate graceful handling
        }
    }
}