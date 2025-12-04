import Foundation
import CallKit
import PortSIPVoIPSDK

/// Manages CallKit integration for the PortSIP plugin.
/// This singleton class handles all CallKit provider operations, including reporting
/// incoming/outgoing calls, managing call states, and responding to CallKit actions.
///
/// Thread Safety: Access to sessionToUUID dictionary is synchronized using a dedicated
/// dispatch queue to prevent race conditions between CallKit callbacks and method calls.
class PortsipCallKitProvider: NSObject {
    /// Component name for logging
    private static let COMPONENT = "CallKit"

    /// Shared singleton instance
    static let shared = PortsipCallKitProvider()

    /// CallKit provider instance
    private var provider: CXProvider?

    /// CallKit call controller for managing outgoing calls
    private let callController = CXCallController()

    /// Maps PortSIP session IDs to CallKit UUIDs
    private var sessionToUUID: [Int: UUID] = [:]

    /// Serial dispatch queue for synchronizing access to sessionToUUID dictionary
    private let sessionLock = DispatchQueue(label: "com.tagonsoft.portsip.callkit.session")

    /// Whether CallKit is currently enabled
    private(set) var isCallKitEnabled = false

    /// Configuration for the CallKit provider
    private var configuration: CXProviderConfiguration?

    /// Tracks the last known speaker state to prevent duplicate events
    private var lastSpeakerState: Bool?

    /// Prevents recursive audio route change handling
    private var isHandlingRouteChange = false

    /// Private initializer to enforce singleton pattern
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    
    /// Configures the CallKit provider with the specified settings.
    /// - Parameters:
    ///   - appName: The app name to display in CallKit UI
    ///   - canUseCallKit: Whether to enable CallKit integration
    ///   - iconTemplateImageName: Optional icon template image name for CallKit UI
    func configure(appName: String, canUseCallKit: Bool = true, iconTemplateImageName: String? = nil) {
        isCallKitEnabled = canUseCallKit
        
        guard canUseCallKit else {
            provider = nil
            return
        }
        
        // Create provider configuration (iOS 13 compatible)
        let config = CXProviderConfiguration(localizedName: appName)
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic, .phoneNumber, .emailAddress]
        
        // Set icon if provided
        if let iconName = iconTemplateImageName,
           let iconImage = UIImage(named: iconName) {
            config.iconTemplateImageData = iconImage.pngData()
        }
        
        self.configuration = config
        
        // Create provider
        provider = CXProvider(configuration: config)
        provider?.setDelegate(self, queue: nil)
                
        // Observe audio route changes
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    /// Enables or disables CallKit at runtime.
    /// - Parameter enabled: Whether to enable CallKit
    func setEnabled(_ enabled: Bool) {
        isCallKitEnabled = enabled
        
        if !enabled {
            // End all active calls when disabling CallKit
            endAllCalls()
            provider = nil
        } else if provider == nil, let config = configuration {
            // Re-create provider if it was disabled
            provider = CXProvider(configuration: config)
            provider?.setDelegate(self, queue: nil)
        }
    }
    
    /// Updates the speaker state to prevent duplicate events when speaker is controlled programmatically.
    /// - Parameter enabled: Whether the speaker is enabled
    func updateSpeakerState(_ enabled: Bool) {
        sessionLock.sync {
            lastSpeakerState = enabled
        }
    }
    
    // MARK: - Thread-Safe Session Management

    /// Thread-safe setter for session-to-UUID mapping
    private func setUUID(_ uuid: UUID, for sessionId: Int) {
        sessionLock.sync {
            sessionToUUID[sessionId] = uuid
        }
    }

    /// Thread-safe removal of session-to-UUID mapping
    private func removeSession(_ sessionId: Int) {
        sessionLock.sync {
            sessionToUUID.removeValue(forKey: sessionId)
        }
    }

    /// Thread-safe getter for UUID by session ID
    private func getUUIDThreadSafe(for sessionId: Int) -> UUID? {
        return sessionLock.sync {
            return sessionToUUID[sessionId]
        }
    }

    /// Thread-safe getter for session ID by UUID
    private func getSessionIdThreadSafe(for uuid: UUID) -> Int? {
        return sessionLock.sync {
            return sessionToUUID.first(where: { $0.value == uuid })?.key
        }
    }

    /// Thread-safe getter for all sessions (for iteration)
    private func getAllSessions() -> [Int: UUID] {
        return sessionLock.sync {
            return sessionToUUID
        }
    }

    /// Thread-safe removal of all sessions
    private func removeAllSessions() {
        sessionLock.sync {
            sessionToUUID.removeAll()
        }
    }

    // MARK: - Call Reporting

    /// Reports an incoming call to CallKit.
    /// - Parameters:
    ///   - sessionId: The PortSIP session ID
    ///   - caller: The caller's identifier (phone number or SIP URI)
    ///   - hasVideo: Whether the call has video
    ///   - completion: Completion handler called when the call is reported
    func reportIncomingCall(sessionId: Int, caller: String, hasVideo: Bool, completion: @escaping (Error?) -> Void) {
        guard isCallKitEnabled, let provider = provider else {
            completion(nil)
            return
        }

        let uuid = UUID()
        setUUID(uuid, for: sessionId)

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: caller)
        update.hasVideo = hasVideo
        update.localizedCallerName = caller

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                PortsipLogger.e(PortsipCallKitProvider.COMPONENT, "Failed to report incoming call for session \(sessionId): \(error.localizedDescription)")
                self?.removeSession(sessionId)
            }
            completion(error)
        }
    }

    /// Reports an outgoing call to CallKit.
    /// - Parameters:
    ///   - sessionId: The PortSIP session ID
    ///   - callee: The callee's identifier (phone number or SIP URI)
    ///   - hasVideo: Whether the call has video
    func reportOutgoingCall(sessionId: Int, callee: String, hasVideo: Bool) {
        guard isCallKitEnabled, let provider = provider else {
            return
        }

        let uuid = UUID()
        setUUID(uuid, for: sessionId)

        let handle = CXHandle(type: .generic, value: callee)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = hasVideo

        let transaction = CXTransaction(action: startCallAction)

        callController.request(transaction) { [weak self] error in
            if let error = error {
                PortsipLogger.e(PortsipCallKitProvider.COMPONENT, "Failed to report outgoing call for session \(sessionId): \(error.localizedDescription)")
                self?.removeSession(sessionId)
                // Hang up the SDK call directly, bypassing CallKit to avoid recursion
                // (hangUp() would try to route through CallKit again if enabled)
                PortsipController.shared.performEndCallAction(sessionId: sessionId)
                // Notify Flutter about the failure
                PortsipEventBridge.shared.sendCallKitFailure(sessionId: sessionId, error: error.localizedDescription)
            } else {
                // Report that the outgoing call started connecting
                provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
            }
        }
    }

    /// Reports that an outgoing call started connecting (ringing).
    /// Call this when the remote party starts ringing.
    /// - Parameter sessionId: The PortSIP session ID
    func reportOutgoingCallStartedConnecting(sessionId: Int) {
        guard isCallKitEnabled, let provider = provider, let uuid = getUUIDThreadSafe(for: sessionId) else {
            return
        }

        provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
    }

    /// Reports that a call has connected.
    /// - Parameter sessionId: The PortSIP session ID
    func reportCallConnected(sessionId: Int) {
        guard isCallKitEnabled, let provider = provider, let uuid = getUUIDThreadSafe(for: sessionId) else {
            return
        }

        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
    }

    /// Reports that a call has ended.
    /// - Parameters:
    ///   - sessionId: The PortSIP session ID
    ///   - reason: The reason the call ended
    func reportCallEnded(sessionId: Int, reason: CXCallEndedReason = .remoteEnded) {
        guard isCallKitEnabled, let provider = provider, let uuid = getUUIDThreadSafe(for: sessionId) else {
            return
        }

        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)

        // Clean up mapping
        removeSession(sessionId)
    }

    /// Updates the hold state of a call.
    /// - Parameters:
    ///   - sessionId: The PortSIP session ID
    ///   - onHold: Whether the call is on hold
    func reportCallHeld(sessionId: Int, onHold: Bool) {
        guard isCallKitEnabled, let uuid = getUUIDThreadSafe(for: sessionId) else {
            return
        }

        let action = CXSetHeldCallAction(call: uuid, onHold: onHold)
        let transaction = CXTransaction(action: action)

        callController.request(transaction) { error in
            if let error = error {
                PortsipLogger.e(PortsipCallKitProvider.COMPONENT, "Failed to set hold state for session \(sessionId): \(error.localizedDescription)")
            }
        }
    }

    /// Updates the mute state of a call.
    /// - Parameters:
    ///   - sessionId: The PortSIP session ID
    ///   - muted: Whether the call is muted
    func reportCallMuted(sessionId: Int, muted: Bool, completion: ((Error?) -> Void)? = nil) {
        guard isCallKitEnabled, let uuid = getUUIDThreadSafe(for: sessionId) else {
            completion?(nil)
            return
        }

        let action = CXSetMutedCallAction(call: uuid, muted: muted)
        let transaction = CXTransaction(action: action)

        callController.request(transaction) { error in
            completion?(error)
        }
    }

    /// Reports a DTMF tone to CallKit.
    /// - Parameters:
    ///   - sessionId: The PortSIP session ID
    ///   - digits: The DTMF digits to play
    func reportDTMF(sessionId: Int, digits: String, completion: ((Error?) -> Void)? = nil) {
        guard isCallKitEnabled, let uuid = getUUIDThreadSafe(for: sessionId) else {
            completion?(nil)
            return
        }

        let action = CXPlayDTMFCallAction(call: uuid, digits: digits, type: .singleTone)
        let transaction = CXTransaction(action: action)

        callController.request(transaction) { error in
            completion?(error)
        }
    }

    /// Requests to end a call via CallKit.
    /// This triggers the CXEndCallAction delegate which will call performEndCallAction.
    /// - Parameters:
    ///   - sessionId: The PortSIP session ID
    ///   - completion: Optional completion handler
    func requestEndCall(sessionId: Int, completion: ((Error?) -> Void)? = nil) {
        guard isCallKitEnabled, let uuid = getUUIDThreadSafe(for: sessionId) else {
            completion?(nil)
            return
        }

        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)

        callController.request(transaction) { error in
            completion?(error)
        }
    }

    // MARK: - Helper Methods

    /// Gets the session ID for a given CallKit UUID.
    /// Uses linear search since we have at most 3 active calls.
    /// - Parameter uuid: The CallKit UUID
    /// - Returns: The PortSIP session ID, or nil if not found
    func getSessionId(for uuid: UUID) -> Int? {
        return getSessionIdThreadSafe(for: uuid)
    }

    /// Gets the CallKit UUID for a given session ID.
    /// - Parameter sessionId: The PortSIP session ID
    /// - Returns: The CallKit UUID, or nil if not found
    func getUUID(for sessionId: Int) -> UUID? {
        return getUUIDThreadSafe(for: sessionId)
    }

    /// Ends all active CallKit calls.
    private func endAllCalls() {
        let sessions = getAllSessions()
        for (_, uuid) in sessions {
            provider?.reportCall(with: uuid, endedAt: Date(), reason: .failed)
        }
        removeAllSessions()
    }
}

// MARK: - CXProviderDelegate
extension PortsipCallKitProvider: CXProviderDelegate {
    /// Called when the provider begins.
    func providerDidBegin(_ provider: CXProvider) {
    }
    
    /// Called when the provider resets.
    func providerDidReset(_ provider: CXProvider) {
        // Clean up all calls
        removeAllSessions()
    }
    
    /// Called when the audio session is activated - handle speaker routing here.
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // Audio route monitoring is set up in configure() method
    }
    
    /// Called when the audio session is deactivated.
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    }
    
    /// Called when the user answers an incoming call.
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    }

    /// Called when the user ends a call.
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let sessionId = getSessionId(for: action.callUUID) else {
            action.fail()
            return
        }

        // Perform end call action via PortsipController
        PortsipController.shared.performEndCallAction(sessionId: sessionId)

        // Clean up mapping
        removeSession(sessionId)

        action.fulfill()
    }
    
    /// Called when the user puts a call on hold or takes it off hold.
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let sessionId = getSessionId(for: action.callUUID) else {
            action.fail()
            return
        }
                
        // Notify PortsipController to hold/unhold the call
        PortsipController.shared.handleCallKitHold(sessionId: sessionId, onHold: action.isOnHold)
        
        action.fulfill()
    }
    
    /// Called when the user mutes or unmutes a call.
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let sessionId = getSessionId(for: action.callUUID) else {
            action.fail()
            return
        }
                
        // Perform mute action via PortsipController
        PortsipController.shared.performMuteAction(sessionId: sessionId, muted: action.isMuted)
        
        action.fulfill()
    }
    
    /// Called when an outgoing call starts connecting.
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        
        // The call was already initiated by PortsipController, just fulfill the action
        action.fulfill()
    }
    
    /// Called when the user plays DTMF tones via CallKit UI.
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        guard let sessionId = getSessionId(for: action.callUUID) else {
            action.fail()
            return
        }
                
        // Perform DTMF action via PortsipController
        PortsipController.shared.performDTMFAction(sessionId: sessionId, digits: action.digits)
        
        action.fulfill()
    }
    
    /// Handles audio route changes to detect speaker/earpiece switching.
    @objc private func handleAudioRouteChange(notification: Notification) {
        // Thread-safe check and set of isHandlingRouteChange to prevent recursive calls
        let shouldHandle = sessionLock.sync { () -> Bool in
            guard !isHandlingRouteChange else {
                return false
            }
            isHandlingRouteChange = true
            return true
        }

        guard shouldHandle else {
            return
        }

        defer {
            sessionLock.sync {
                isHandlingRouteChange = false
            }
        }

        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let _ = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Get current route info
        let currentRoute = AVAudioSession.sharedInstance().currentRoute

        // Check speaker state for ANY route change (not just override/categoryChange)
        // This ensures we catch all speaker button taps
        let isSpeakerActive = currentRoute.outputs.first?.portType == .builtInSpeaker

        // Thread-safe check and update of lastSpeakerState to prevent duplicate events / loops
        let shouldNotify = sessionLock.sync { () -> Bool in
            if isSpeakerActive == lastSpeakerState {
                return false
            }
            lastSpeakerState = isSpeakerActive
            return true
        }

        guard shouldNotify else {
            return
        }

        // Perform speaker action for all active sessions
        let sessions = getAllSessions()
        for (sessionId, _) in sessions {
            PortsipController.shared.performSpeakerAction(
                sessionId: sessionId,
                enableSpeaker: isSpeakerActive
            )
        }
    }
    
    /// Helper to get human-readable route change reason name
    private func getRouteChangeReasonName(_ reason: AVAudioSession.RouteChangeReason) -> String {
        switch reason {
        case .unknown: return "unknown"
        case .newDeviceAvailable: return "newDeviceAvailable"
        case .oldDeviceUnavailable: return "oldDeviceUnavailable"
        case .categoryChange: return "categoryChange"
        case .override: return "override"
        case .wakeFromSleep: return "wakeFromSleep"
        case .noSuitableRouteForCategory: return "noSuitableRouteForCategory"
        case .routeConfigurationChange: return "routeConfigurationChange"
        @unknown default: return "unknown(\(reason.rawValue))"
        }
    }

    // MARK: - Cleanup Methods

    /// Disposes of the CallKit provider and removes all observers.
    /// This should be called when the plugin is being detached or when
    /// CallKit integration is no longer needed.
    ///
    /// This method:
    /// - Removes audio route change observer
    /// - Ends all active CallKit calls
    /// - Invalidates and releases the CXProvider
    /// - Clears all session mappings
    func dispose() {
        // Remove audio route change observer
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)

        // End all active calls
        endAllCalls()

        // Invalidate the provider
        provider?.invalidate()
        provider = nil

        // Clear configuration
        configuration = nil
        isCallKitEnabled = false
        sessionLock.sync {
            lastSpeakerState = nil
            isHandlingRouteChange = false
        }
    }
}
