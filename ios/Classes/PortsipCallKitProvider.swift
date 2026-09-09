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

    /// Pending app-initiated hold mirrors per session, counted. The
    /// CXSetHeldCallAction delegate consumes one per action so our own
    /// requests aren't echoed back into the SDK. Counted rather than a set
    /// because one session can have several mirrors in flight at once.
    private var programmaticHoldCounts: [Int: Int] = [:]

    /// Merged-conference tracking (set by [reportConferenceMerged], cleared
    /// by [clearConferenceTracking]). After a merge only the primary leg has
    /// a CXCall; if its session ends while another leg survives, the CXCall
    /// is transferred to the survivor — ending the last CXCall would
    /// deactivate the audio session and silence the surviving call.
    private var conferencePrimarySession: Int?
    private var conferenceMergedAwaySessions: Set<Int> = []

    /// Last hold state applied to the SDK per session. Makes
    /// CXSetHeldCallActions idempotent: iOS can deliver actions matching what
    /// the SDK already did, and re-driving those sends redundant re-INVITEs
    /// and duplicate events.
    private var sessionHoldStates: [Int: Bool] = [:]

    /// Display names to attach when the CXStartCallAction is performed —
    /// the only point where an outgoing call's caller name reliably sticks.
    private var pendingDisplayNames: [Int: String] = [:]

    /// Serial dispatch queue for synchronizing access to sessionToUUID dictionary
    private let sessionLock = DispatchQueue(label: "com.tagonsoft.portsip.callkit.session")

    /// Serial queue that drives the SDK for system-initiated hold actions
    /// off CallKit's callback thread — blocking the callback can time the
    /// action out, making CallKit revert its call state. Serial so the two
    /// actions of one Swap keep their order.
    private let holdActionQueue = DispatchQueue(label: "com.tagonsoft.portsip.callkit.holdaction")

    /// Whether CallKit is currently enabled
    private(set) var isCallKitEnabled = false

    /// Configuration for the CallKit provider
    private var configuration: CXProviderConfiguration?

    /// Tracks the last known speaker state to prevent duplicate events
    private var lastSpeakerState: Bool?

    /// One-shot: a Bluetooth revive bounce is in flight (see performBluetoothRevive).
    private var bluetoothRevivePending = false

    /// Category options at the previous route event. User route actions never
    /// rewrite the options; the engine's reconfigurations do — that fingerprint
    /// tells them apart when both land on the receiver.
    private var lastCategoryOpts: UInt = 0

    /// One-shot: right after answer/activation the engine performs a session
    /// config that clears an active override with no observable fingerprint.
    /// Armed at onInviteAnswered/didActivate, consumed by the next route event.
    private var answerResetPending = false

    /// The user's speaker choice — the restore machinery's only basis. Written
    /// solely by user signals (loudspeaker API, .override route events,
    /// fingerprint-less receiver landings), never by the engine's route flips,
    /// so a restore can't re-assert something the user turned off.
    private var userWantsSpeaker = false

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
        // Two so a second (conference) call can be reported alongside the first;
        // this is what lets iOS show the held call + a "Swap" affordance in the
        // Dynamic Island / call UI.
        config.maximumCallGroups = 2
        config.maximumCallsPerCallGroup = 2
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
            // First leg of a new call group — drop any stale speaker memory.
            if sessionToUUID.isEmpty {
                lastSpeakerState = nil
                answerResetPending = false
                userWantsSpeaker = false
            }
            sessionToUUID[sessionId] = uuid
        }
    }

    /// Thread-safe removal of session-to-UUID mapping
    private func removeSession(_ sessionId: Int) {
        sessionLock.sync {
            sessionToUUID.removeValue(forKey: sessionId)
            programmaticHoldCounts.removeValue(forKey: sessionId)
            sessionHoldStates.removeValue(forKey: sessionId)
            pendingDisplayNames.removeValue(forKey: sessionId)
            // Last call gone — the speaker memory dies with the call group so
            // it can't leak a restore into the next call.
            if sessionToUUID.isEmpty {
                lastSpeakerState = nil
                answerResetPending = false
                userWantsSpeaker = false
                bluetoothRevivePending = false
            }
        }
    }

    /// Registers one pending programmatic hold mirror for [sessionId].
    private func markProgrammaticHold(_ sessionId: Int) {
        sessionLock.sync {
            programmaticHoldCounts[sessionId, default: 0] += 1
        }
    }

    /// Consumes one pending programmatic hold for [sessionId]. Returns false
    /// when none is pending (the action is user/system-initiated). Also used
    /// to roll a mark back when a transaction request fails (the delegate
    /// won't fire for it).
    private func consumeProgrammaticHold(_ sessionId: Int) -> Bool {
        return sessionLock.sync {
            guard let count = programmaticHoldCounts[sessionId], count > 0 else {
                return false
            }
            if count == 1 {
                programmaticHoldCounts.removeValue(forKey: sessionId)
            } else {
                programmaticHoldCounts[sessionId] = count - 1
            }
            return true
        }
    }

    /// Arms the one-shot answer-reset expectation (see answerResetPending).
    func expectAnswerReset() {
        sessionLock.sync { answerResetPending = true }
    }

    /// Records the user's speaker choice made through the plugin's loudspeaker
    /// API (see userWantsSpeaker).
    func noteUserSpeakerChoice(_ on: Bool) {
        sessionLock.sync { userWantsSpeaker = on }
    }

    /// Revives a Bluetooth call whose SCO voice link died while the route
    /// still reads BluetoothHFP: iOS renegotiates SCO only on a real route
    /// change, so bounce the input via the built-in mic and back (return
    /// half in handleAudioRouteChange).
    func performBluetoothRevive() {
        let session = AVAudioSession.sharedInstance()
        guard session.currentRoute.outputs.first?.portType == .bluetoothHFP,
              let mic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
            return
        }
        PortsipLogger.d(PortsipCallKitProvider.COMPONENT, "BT revive: bouncing route via receiver")
        sessionLock.sync { bluetoothRevivePending = true }
        try? session.setPreferredInput(mic)
    }

    /// Records the hold state just applied to the SDK for [sessionId]. Called
    /// by every path that successfully drives the SDK hold/unhold.
    func noteHoldState(sessionId: Int, onHold: Bool) {
        sessionLock.sync {
            sessionHoldStates[sessionId] = onHold
        }
    }

    /// The last hold state applied to the SDK for [sessionId], or nil if its
    /// hold was never touched.
    func holdState(for sessionId: Int) -> Bool? {
        return sessionLock.sync {
            return sessionHoldStates[sessionId]
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

    /// Thread-safe accessor for currently active session IDs.
    /// Used by the willTerminate path so we can BYE every live call before
    /// REGISTER:0 — keeps the server from holding the dialog open after
    /// swipe-kill.
    func activeSessionIds() -> [Int] {
        return sessionLock.sync {
            return Array(sessionToUUID.keys)
        }
    }

    /// Thread-safe getter for all sessions (for iteration)
    private func getAllSessions() -> [Int: UUID] {
        return sessionLock.sync {
            return sessionToUUID
        }
    }

    /// Number of calls currently tracked by CallKit.
    var sessionCount: Int {
        return sessionLock.sync { sessionToUUID.count }
    }

    /// Thread-safe removal of all sessions
    private func removeAllSessions() {
        sessionLock.sync {
            sessionToUUID.removeAll()
            programmaticHoldCounts.removeAll()
            sessionHoldStates.removeAll()
            pendingDisplayNames.removeAll()
            bluetoothRevivePending = false
            // The speaker memory dies with the call group so it can't leak a
            // restore into the next call.
            lastSpeakerState = nil
            answerResetPending = false
            userWantsSpeaker = false
            conferencePrimarySession = nil
            conferenceMergedAwaySessions.removeAll()
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
    ///   - displayName: Name the system call UI shows; must be supplied at
    ///     call time — outgoing calls don't reliably honor later updates.
    ///   - displayNumber: Number the call UI shows and the OS call history
    ///     stores. Defaults to callee.
    func reportOutgoingCall(sessionId: Int, callee: String, hasVideo: Bool, displayName: String? = nil, displayNumber: String? = nil) {
        guard isCallKitEnabled, let provider = provider else {
            return
        }

        let uuid = UUID()
        setUUID(uuid, for: sessionId)
        if let displayName = displayName {
            sessionLock.sync { pendingDisplayNames[sessionId] = displayName }
        }

        // CXHandle is what the OS formats and stores in Recents, so it takes
        // the display number rather than the SIP destination.
        let handle = CXHandle(type: .phoneNumber, value: displayNumber ?? callee)
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

        // Mark this as self-requested so the CXSetHeldCallAction delegate skips
        // the redundant SDK hold + event echo (see programmaticHoldCounts).
        markProgrammaticHold(sessionId)
        PortsipLogger.d(
            PortsipCallKitProvider.COMPONENT,
            "reportCallHeld requesting session=\(sessionId) onHold=\(onHold)"
        )

        let action = CXSetHeldCallAction(call: uuid, onHold: onHold)
        let transaction = CXTransaction(action: action)

        callController.request(transaction) { [weak self] error in
            if let error = error {
                // The delegate won't fire on failure — roll the mark back so a
                // later genuine system hold isn't swallowed.
                _ = self?.consumeProgrammaticHold(sessionId)
                PortsipLogger.e(PortsipCallKitProvider.COMPONENT, "Failed to set hold state for session \(sessionId): \(error.localizedDescription)")
            }
        }
    }

    /// Mirrors an app-initiated swap to CallKit as ONE atomic CXTransaction.
    /// Two separate transactions let CallKit observe two active calls in
    /// between, and it enforces its one-active-call rule by ending one of
    /// them. Both actions are flagged programmatic.
    func reportCallsSwapped(holdSessionId: Int, unholdSessionId: Int) {
        guard isCallKitEnabled,
              let holdUUID = getUUIDThreadSafe(for: holdSessionId),
              let unholdUUID = getUUIDThreadSafe(for: unholdSessionId) else { return }

        markProgrammaticHold(holdSessionId)
        markProgrammaticHold(unholdSessionId)
        PortsipLogger.d(
            PortsipCallKitProvider.COMPONENT,
            "reportCallsSwapped requesting hold=\(holdSessionId) unhold=\(unholdSessionId) (atomic)"
        )

        let transaction = CXTransaction(actions: [
            CXSetHeldCallAction(call: holdUUID, onHold: true),
            CXSetHeldCallAction(call: unholdUUID, onHold: false),
        ])

        callController.request(transaction) { [weak self] error in
            if let error = error {
                // The delegate won't fire on failure — roll the marks back so a
                // later genuine system hold isn't swallowed.
                _ = self?.consumeProgrammaticHold(holdSessionId)
                _ = self?.consumeProgrammaticHold(unholdSessionId)
                PortsipLogger.e(
                    PortsipCallKitProvider.COMPONENT,
                    "Failed to mirror swap (hold \(holdSessionId) / unhold \(unholdSessionId)): \(error.localizedDescription)"
                )
            }
        }
    }

    /// Ends [endSessionId] and resumes [resumeSessionId] in ONE atomic
    /// CXTransaction. Ending the active leg and resuming the held leg as two
    /// separate steps leaves CallKit with zero active calls in between — it tears
    /// down the audio session and the survivor comes back silent. Bundling both
    /// keeps exactly one active call throughout. The CXAction delegates drive the
    /// SDK hangUp/unHold, so callers must NOT also invoke them directly.
    func endCallAndResume(endSessionId: Int, resumeSessionId: Int) {
        guard isCallKitEnabled,
              let endUUID = getUUIDThreadSafe(for: endSessionId),
              let resumeUUID = getUUIDThreadSafe(for: resumeSessionId) else { return }

        PortsipLogger.d(
            PortsipCallKitProvider.COMPONENT,
            "endCallAndResume end=\(endSessionId) resume=\(resumeSessionId) (atomic)"
        )

        let transaction = CXTransaction(actions: [
            CXEndCallAction(call: endUUID),
            CXSetHeldCallAction(call: resumeUUID, onHold: false),
        ])

        callController.request(transaction) { error in
            if let error = error {
                PortsipLogger.e(
                    PortsipCallKitProvider.COMPONENT,
                    "endCallAndResume failed (end \(endSessionId) / resume \(resumeSessionId)): \(error.localizedDescription)"
                )
            }
        }
    }

    /// Groups [sessionIds] into one native CallKit conference call via a single
    /// CXSetGroupCallAction transaction (the first session is the anchor; every
    /// other is grouped onto it). No call is ended, so CallKit keeps the audio
    /// session active — the delegate confirms it and notifies Flutter via
    /// onCallKitMerge, which is also where the system Merge button lands.
    func requestCallGroup(sessionIds: [Int]) -> Int {
        guard isCallKitEnabled, sessionIds.count >= 2 else { return -1 }
        let uuids = sessionIds.compactMap { getUUIDThreadSafe(for: $0) }
        guard uuids.count == sessionIds.count, let anchor = uuids.first else {
            PortsipLogger.e(
                PortsipCallKitProvider.COMPONENT,
                "requestCallGroup: missing CXCall UUID for one of \(sessionIds)"
            )
            return -1
        }
        let actions = uuids.dropFirst().map {
            CXSetGroupCallAction(call: $0, callUUIDToGroupWith: anchor)
        }
        PortsipLogger.d(
            PortsipCallKitProvider.COMPONENT,
            "requestCallGroup grouping \(sessionIds) onto anchor=\(sessionIds.first ?? -1)"
        )
        callController.request(CXTransaction(actions: Array(actions))) { error in
            if let error = error {
                PortsipLogger.e(
                    PortsipCallKitProvider.COMPONENT,
                    "requestCallGroup failed: \(error.localizedDescription)"
                )
            }
        }
        return 0
    }

    /// Collapses a now-merged conference to a single system call: ends the
    /// CallKit calls for the merged-away legs (their SIP sessions stay live in
    /// the SDK conference bridge) so the OS shows one call, not several.
    /// - Parameters:
    ///   - primarySessionId: The leg whose CallKit call represents the conference.
    ///   - mergedAwaySessionIds: The other legs whose CallKit calls to end.
    func reportConferenceMerged(primarySessionId: Int, mergedAwaySessionIds: [Int]) {
        guard isCallKitEnabled, let provider = provider else { return }
        sessionLock.sync {
            conferencePrimarySession = primarySessionId
            conferenceMergedAwaySessions = Set(mergedAwaySessionIds)
        }

        let endMergedAway = { [weak self] in
            guard let self = self else { return }
            for sessionId in mergedAwaySessionIds {
                guard let uuid = self.getUUIDThreadSafe(for: sessionId) else { continue }
                provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
                self.removeSession(sessionId)
            }
        }

        // Resume the primary FIRST and end the merged-away calls only after
        // the unhold has been applied (the request completion fires after the
        // delegate fulfilled it). Ending them while the primary is still held
        // leaves CallKit with no active call, and it deactivates the audio
        // session mid-merge.
        guard let primaryUUID = getUUIDThreadSafe(for: primarySessionId) else {
            endMergedAway()
            return
        }
        markProgrammaticHold(primarySessionId)
        let action = CXSetHeldCallAction(call: primaryUUID, onHold: false)
        callController.request(CXTransaction(action: action)) { [weak self] error in
            if let error = error {
                _ = self?.consumeProgrammaticHold(primarySessionId)
                PortsipLogger.e(
                    PortsipCallKitProvider.COMPONENT,
                    "Conference-merge unhold of \(primarySessionId) failed: \(error.localizedDescription)"
                )
            }
            endMergedAway()
        }
    }

    /// A SIP session is ending. If it's the merged-conference primary and a
    /// merged-away leg survives, the CXCall is re-mapped to the survivor (the
    /// new primary) and its session id is returned — the caller must then NOT
    /// end the CXCall or stop the audio engine. Returns nil when no transfer
    /// applies, after pruning [endingSessionId] from the tracking.
    func transferSystemCallIfNeeded(endingSessionId: Int) -> Int? {
        return sessionLock.sync {
            if conferencePrimarySession != endingSessionId {
                conferenceMergedAwaySessions.remove(endingSessionId)
                return nil
            }
            guard let survivor = conferenceMergedAwaySessions.first,
                  let uuid = sessionToUUID.removeValue(forKey: endingSessionId) else {
                conferencePrimarySession = nil
                conferenceMergedAwaySessions.removeAll()
                return nil
            }
            sessionToUUID[survivor] = uuid
            programmaticHoldCounts.removeValue(forKey: endingSessionId)
            conferenceMergedAwaySessions.remove(survivor)
            conferencePrimarySession = survivor
            return survivor
        }
    }

    /// The conference is over (bridge destroyed) — stop tracking it. Existing
    /// session→UUID mappings are untouched.
    func clearConferenceTracking() {
        sessionLock.sync {
            conferencePrimarySession = nil
            conferenceMergedAwaySessions.removeAll()
        }
    }

    /// Updates the name the system call UI shows for a call — used after a
    /// merge (conference title) or a transferred CXCall (see
    /// [transferSystemCallIfNeeded]) so it stops displaying a single/ended leg.
    func updateCallDisplay(sessionId: Int, displayName: String) {
        guard isCallKitEnabled, let provider = provider,
              let uuid = getUUIDThreadSafe(for: sessionId) else {
            PortsipLogger.e(
                PortsipCallKitProvider.COMPONENT,
                "updateCallDisplay: no CXCall for session \(sessionId)"
            )
            return
        }
        let update = CXCallUpdate()
        update.localizedCallerName = displayName
        // For OUTGOING calls iOS derives the on-screen identity from the
        // call's HANDLE (with its own contact resolution) and ignores a bare
        // localizedCallerName update. Re-handle the call with a generic
        // handle carrying the display string so the system UI shows it.
        update.remoteHandle = CXHandle(type: .generic, value: displayName)
        provider.reportCall(with: uuid, updated: update)
        PortsipLogger.d(
            PortsipCallKitProvider.COMPONENT,
            "updateCallDisplay session=\(sessionId) → \"\(displayName)\""
        )
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
    
    /// Called when CallKit activates the shared audio session. CallKit owns
    /// activation around hold/unhold/swap, so the SDK audio engine must follow
    /// it here or the call goes silent after a hold/swap/merge.
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        PortsipLogger.d(PortsipCallKitProvider.COMPONENT, "audio session ACTIVATED → startAudio")
        // The engine's first post-activation config can clear an active
        // override without a fingerprint — arm the one-shot restore.
        expectAnswerReset()
        PortsipController.shared.activateAudioSession()
    }

    /// Called when CallKit deactivates the shared audio session (held / ended).
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        PortsipLogger.d(PortsipCallKitProvider.COMPONENT, "audio session DEACTIVATED → stopAudio")
        PortsipController.shared.deactivateAudioSession()
    }
    
    /// Called when the user answers an incoming call.
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // SDK CallKit contract: prepare the audio session here; the engine
        // starts in didActivate.
        PortsipController.shared.prepareCallAudioSession()
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

        // Programmatic actions (our own reportCallHeld mirrors) and actions
        // matching the SDK's current hold state are only confirmed — driving
        // the SDK again would echo redundant re-INVITEs and events.
        let isProgrammatic = consumeProgrammaticHold(sessionId)
        PortsipLogger.d(
            PortsipCallKitProvider.COMPONENT,
            "CXSetHeldCallAction session=\(sessionId) onHold=\(action.isOnHold) " +
            "programmatic=\(isProgrammatic) tracked=\(String(describing: holdState(for: sessionId)))"
        )
        if !isProgrammatic && holdState(for: sessionId) != action.isOnHold {
            // Record the target state and notify Flutter up front so the two
            // actions of one Swap reach the app together; the SDK work runs
            // behind on holdActionQueue and the action is fulfilled first.
            noteHoldState(sessionId: sessionId, onHold: action.isOnHold)
            PortsipController.shared.notifyCallKitHold(sessionId: sessionId, onHold: action.isOnHold)
            holdActionQueue.async {
                PortsipController.shared.handleCallKitHold(sessionId: sessionId, onHold: action.isOnHold)
            }
        }

        action.fulfill()
    }
    
    /// Called when the user taps Merge in the system call UI: CallKit groups
    /// one call with another. The SDK-side conference bridge is owned by the
    /// Dart layer (it also drives the in-app merge), so just notify Flutter
    /// and confirm the action. Without this handler the action fails and the
    /// system Merge button does nothing.
    func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
        guard let sessionId = getSessionId(for: action.callUUID) else {
            action.fail()
            return
        }
        PortsipLogger.d(
            PortsipCallKitProvider.COMPONENT,
            "CXSetGroupCallAction session=\(sessionId) groupWith=\(String(describing: action.callUUIDToGroupWith))"
        )
        if let otherUUID = action.callUUIDToGroupWith,
           let otherSessionId = getSessionId(for: otherUUID) {
            let eventData: [String: Any] = [
                "sessionId": sessionId,
                "otherSessionId": otherSessionId
            ]
            PortsipEventBridge.shared.sendEvent(name: "onCallKitMerge", data: eventData)
        }
        // Ungrouping (callUUIDToGroupWith == nil) isn't offered by our UI;
        // fulfill it as a no-op rather than failing the transaction.
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
        // SDK CallKit contract: prepare the audio session here; the engine
        // starts in didActivate.
        PortsipController.shared.prepareCallAudioSession()

        // The call was already initiated by PortsipController. Attach the
        // caller name now — outgoing calls don't reliably honor later updates.
        if let sessionId = getSessionId(for: action.callUUID),
           let name = sessionLock.sync(execute: { pendingDisplayNames.removeValue(forKey: sessionId) }) {
            let update = CXCallUpdate()
            update.localizedCallerName = name
            provider.reportCall(with: action.callUUID, updated: update)
        }
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
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Get current route info
        let currentRoute = AVAudioSession.sharedInstance().currentRoute

        // Check speaker state for ANY route change (not just override/categoryChange)
        // This ensures we catch all speaker button taps
        let isSpeakerActive = currentRoute.outputs.first?.portType == .builtInSpeaker
        let hasExternalOutput = currentRoute.outputs.contains {
            $0.portType != .builtInReceiver && $0.portType != .builtInSpeaker
        }

        let currentOpts = AVAudioSession.sharedInstance().categoryOptions.rawValue
        let hasActiveCalls = sessionCount > 0
        let (optsChanged, wantsSpeaker, engineBusy, answerReset) = sessionLock.sync { () -> (Bool, Bool, Bool, Bool) in
            let changed = currentOpts != lastCategoryOpts
            lastCategoryOpts = currentOpts
            let answer = answerResetPending
            answerResetPending = false
            return (
                changed,
                userWantsSpeaker,
                sessionHoldStates.values.contains(true) || conferencePrimarySession != nil,
                answer
            )
        }

        PortsipLogger.d(
            PortsipCallKitProvider.COMPONENT,
            "routeChange reason=\(getRouteChangeReasonName(reason)) " +
            "output=\(currentRoute.outputs.first?.portType.rawValue ?? "none") " +
            "isSpeaker=\(isSpeakerActive) external=\(hasExternalOutput) " +
            "optsChanged=\(optsChanged) busy=\(engineBusy) opts=\(currentOpts)"
        )

        // Return half of the Bluetooth revive: consumed by the FIRST event
        // after the bounce (a stale flag would hijack a later user pick);
        // re-select the BT input only if the bounce landed on the receiver.
        let revive = sessionLock.sync { () -> Bool in
            guard bluetoothRevivePending else { return false }
            bluetoothRevivePending = false
            return true
        }
        if revive && currentRoute.outputs.first?.portType == .builtInReceiver {
            PortsipLogger.d(PortsipCallKitProvider.COMPONENT, "BT revive: back from receiver to Bluetooth")
            let session = AVAudioSession.sharedInstance()
            if let bt = session.availableInputs?.first(where: { $0.portType == .bluetoothHFP }) {
                try? session.setPreferredInput(bt)
            }
            return
        }

        // The SDK's async reconfigurations after startAudio strip the Bluetooth
        // category options the system in-call UI requires — re-ensure them
        // (no-op once in place, so no notification ping-pong).
        if hasActiveCalls {
            PortsipController.ensureCallSessionConfiguration()
        }

        // Restore the speaker when an engine/session reconfiguration steals the
        // route across answer/hold/swap/merge. Engine steals carry a fingerprint
        // user actions never produce: a category-options rewrite, options still
        // in the engine's stripped state, or the armed answer-reset. Any other
        // receiver-landing is honored as a user action.
        let sessionConfigured = AVAudioSession.CategoryOptions(rawValue: currentOpts)
            .contains([.allowBluetooth, .allowBluetoothA2DP])
        let engineSteal = optsChanged || !sessionConfigured || answerReset
        if hasActiveCalls && engineSteal && wantsSpeaker && !isSpeakerActive && !hasExternalOutput {
            PortsipLogger.d(
                PortsipCallKitProvider.COMPONENT,
                "restoring speaker after engine config rewrite"
            )
            try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            // Keep the choice intact so a follow-up rewrite is also restored;
            // don't notify Flutter about a state we just corrected.
            return
        }

        // Record the user's choice from user signals only: .override events are
        // explicit picks; a fingerprint-less receiver-landing is the system
        // button's OFF. Engine flips match neither. Only while a call exists,
        // so a teardown event can't leak the choice into the next call.
        if hasActiveCalls {
            if !hasExternalOutput {
                if reason == .override {
                    sessionLock.sync { userWantsSpeaker = isSpeakerActive }
                } else if !isSpeakerActive && !engineSteal {
                    sessionLock.sync { userWantsSpeaker = false }
                }
            } else {
                // An external device (BT/headphones/car) supersedes the choice;
                // on disconnect the route falls back to the receiver.
                sessionLock.sync { userWantsSpeaker = false }
            }
        }

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
