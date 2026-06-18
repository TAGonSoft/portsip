import AVFoundation
import AudioToolbox
import PortSIPVoIPSDK

/// DTMF (Dual-Tone Multi-Frequency) codes for dial pad tones.
/// These codes map to the standard DTMF keypad digits used in telephony.
enum DTMFCode: Int32, CaseIterable {
    case digit0 = 0
    case digit1 = 1
    case digit2 = 2
    case digit3 = 3
    case digit4 = 4
    case digit5 = 5
    case digit6 = 6
    case digit7 = 7
    case digit8 = 8
    case digit9 = 9
    case star = 10    // * key
    case pound = 11   // # key

    /// Returns the character representation of this DTMF code.
    var character: String {
        switch self {
        case .digit0: return "0"
        case .digit1: return "1"
        case .digit2: return "2"
        case .digit3: return "3"
        case .digit4: return "4"
        case .digit5: return "5"
        case .digit6: return "6"
        case .digit7: return "7"
        case .digit8: return "8"
        case .digit9: return "9"
        case .star: return "*"
        case .pound: return "#"
        }
    }

    /// Creates a DTMFCode from a character.
    /// - Parameter char: The character to convert (0-9, *, #)
    /// - Returns: The corresponding DTMFCode, or nil if invalid
    static func from(character char: Character) -> DTMFCode? {
        switch char {
        case "0": return .digit0
        case "1": return .digit1
        case "2": return .digit2
        case "3": return .digit3
        case "4": return .digit4
        case "5": return .digit5
        case "6": return .digit6
        case "7": return .digit7
        case "8": return .digit8
        case "9": return .digit9
        case "*": return .star
        case "#": return .pound
        default: return nil
        }
    }

    /// Creates a DTMFCode from an Int32 code.
    /// - Parameter code: The numeric code (0-11)
    /// - Returns: The corresponding DTMFCode, or nil if invalid
    static func from(code: Int32) -> DTMFCode? {
        return DTMFCode(rawValue: code)
    }
}

/// Controller class that manages the PortSIP SDK integration for the Flutter plugin.
/// This singleton class handles all SIP operations including initialization, registration,
/// call management, and event delegation to the Flutter side.
///
/// Thread Safety: All SDK operations are synchronized using a serial dispatch queue (sdkQueue)
/// to prevent race conditions between method calls from the main thread and callbacks from
/// SDK internal threads.
class PortsipController: NSObject {
    /// Shared singleton instance of the PortsipController
    static let shared = PortsipController()

    /// The PortSIP SDK instance used for all SIP operations.
    /// This is recreated when needed (e.g., after dispose() is called).
    private var _portSIPSDK: PortSIPSDK?

    /// Accessor for the SDK instance that creates it if needed.
    /// This ensures the SDK is always available and has its delegate set.
    private(set) var portSIPSDK: PortSIPSDK {
        get {
            if _portSIPSDK == nil {
                let sdk = PortSIPSDK()
                sdk.delegate = self
                _portSIPSDK = sdk
            }
            return _portSIPSDK!
        }
        set {
            _portSIPSDK = newValue
        }
    }

    /// Serial dispatch queue for synchronizing all SDK operations
    private let sdkQueue = DispatchQueue(label: "com.tagonsoft.portsip.sdk")

    /// Private initializer to enforce singleton pattern.
    /// Sets up lifecycle observers for background handling.
    private override init() {
        super.init()
        // Trigger SDK initialization (creates SDK instance with delegate)
        _ = portSIPSDK

        // Setup app lifecycle observers for background handling
        setupLifecycleObservers()
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord)
            try session.setMode(AVAudioSession.Mode.voiceChat)
        } catch {
            let errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            
            // Send error event to Flutter
            let eventData: [String: Any] = [
                "error": errorMessage,
                "errorCode": (error as NSError).code,
                "errorDomain": (error as NSError).domain
            ]
            PortsipEventBridge.shared.sendEvent(name: "onAudioSessionError", data: eventData)
        }
    }
    
    /// Sets up notification observers for app lifecycle events.
    /// Monitors when the app enters background or foreground to manage SIP keep-alive functionality.
    private func setupLifecycleObservers() {
        // Observe when app enters background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // Observe when app returns to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Observe app termination so we can hang up + REGISTER:0 natively.
        // Required because during a swipe-kill with an active CallKit call,
        // iOS SIGKILLs the Flutter isolate before any Dart-side cleanup
        // makes it across the platform channel — but the AppDelegate
        // notification path still gets its grace window.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    /// Called by iOS just before the process is terminated (swipe-kill or
    /// system-initiated). Synchronously hangs up every active CallKit call
    /// and unregisters from the SIP server
    @objc private func appWillTerminate() {
        PortsipLogger.d("Controller", "appWillTerminate — flushing active calls + UNREGISTER")
        let sessions = PortsipCallKitProvider.shared.activeSessionIds()

        for sessionId in sessions {
            PortsipCallKitProvider.shared.reportCallEnded(sessionId: sessionId, reason: .remoteEnded)
        }

        for sessionId in sessions {
            portSIPSDK.hangUp(Int(sessionId))
        }

        portSIPSDK.unRegisterServer(1000)
    }
    
    /// Called when the app enters background.
    /// Starts SIP keep-alive to maintain connection and receive calls while in background.
    /// TCP and TLS transports are more battery efficient than UDP for background operation.
    @objc private func appDidEnterBackground() {
        sdkQueue.async { [weak self] in
            // Keep SIP alive in background to receive calls
            // TCP and TLS are more battery efficient than UDP for background
            self?.portSIPSDK.startKeepAwake()
        }
    }

    /// Called when the app returns to foreground.
    /// Stops SIP keep-alive as it's no longer needed when app is active.
    @objc private func appWillEnterForeground() {
        sdkQueue.async { [weak self] in
            // Stop keep alive when returning to foreground
            self?.portSIPSDK.stopKeepAwake()
        }
    }
    
    /// Deinitializer that removes notification observers when the controller is deallocated.
    deinit {
        // Remove observers when controller is deallocated
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Initializes the PortSIP SDK with the provided configuration.
    /// - Parameter arguments: Dictionary containing initialization parameters:
    ///   - transport: Transport protocol (UDP=0, TCP=1, TLS=2)
    ///   - localIP: Local IP address to bind (default: "0.0.0.0")
    ///   - localSIPPort: Local SIP port (default: 5060)
    ///   - logLevel: Logging level (default: 0)
    ///   - logFilePath: Path for log files
    ///   - maxCallLines: Maximum concurrent call lines (default: 3)
    ///   - sipAgent: SIP user agent string
    ///   - audioDeviceLayer: Audio device layer (default: 0)
    ///   - videoDeviceLayer: Video device layer (default: 0)
    ///   - TLSCertificatesRootPath: Root path for TLS certificates
    ///   - TLSCipherList: TLS cipher list
    ///   - verifyTLSCertificate: Whether to verify TLS certificates (default: false)
    ///   - dnsServers: DNS servers to use
    ///   - ptime: Audio packet time in ms (default: 20)
    ///   - maxPtime: Maximum audio packet time in ms (default: 60)
    /// - Returns: 0 on success, error code otherwise
    func initialize(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let transport = Int32(arguments["transport"] as? Int ?? 0)
            let localIP = arguments["localIP"] as? String ?? "0.0.0.0"
            let localSIPPort = Int32(arguments["localSIPPort"] as? Int ?? 5060)
            let logLevel = Int32(arguments["logLevel"] as? Int ?? 0)
            let logFilePath = arguments["logFilePath"] as? String ?? ""
            let maxCallLines = Int32(arguments["maxCallLines"] as? Int ?? 3)
            let sipAgent = arguments["sipAgent"] as? String ?? "PortSIP SDK for iOS"
            let audioDeviceLayer = Int32(arguments["audioDeviceLayer"] as? Int ?? 0)
            let videoDeviceLayer = Int32(arguments["videoDeviceLayer"] as? Int ?? 0)
            let tlsCertificatesRootPath = arguments["tlsCertificatesRootPath"] as? String ?? ""
            let tlsCipherList = arguments["tlsCipherList"] as? String ?? ""
            let verifyTLSCertificate = arguments["verifyTLSCertificate"] as? Bool ?? false
            let dnsServers = arguments["dnsServers"] as? String ?? ""
            let ptime = Int32(arguments["ptime"] as? Int ?? 20)
            let maxPtime = Int32(arguments["maxPtime"] as? Int ?? 60)

            let result = portSIPSDK.initialize(
                TRANSPORT_TYPE(rawValue: transport),
                localIP: localIP,
                localSIPPort: localSIPPort,
                loglevel: PORTSIP_LOG_LEVEL(rawValue: logLevel),
                logPath: logFilePath,
                maxLine: maxCallLines,
                agent: sipAgent,
                audioDeviceLayer: audioDeviceLayer,
                videoDeviceLayer: videoDeviceLayer,
                tlsCertificatesRootPath: tlsCertificatesRootPath,
                tlsCipherList: tlsCipherList,
                verifyTLSCertificate: verifyTLSCertificate,
                dnsServers: dnsServers
            )

            // Configure audio settings after successful initialization
            if result == 0 {
                // Set audio packet time (ptime) - important for audio quality and compatibility
                portSIPSDK.setAudioSamples(ptime, maxPtime: maxPtime)
            }
            return Int(result)
        }
    }

    /// Registers the SIP account with the server or sets up P2P mode.
    /// - Parameter arguments: Dictionary containing registration parameters:
    ///   - userName: SIP username
    ///   - password: SIP password
    ///   - sipServer: SIP server address (empty for P2P mode)
    ///   - sipServerPort: SIP server port (default: 5060)
    ///   - displayName: Display name for the user
    ///   - authName: Authentication name
    ///   - userDomain: User domain
    ///   - stunServer: STUN server address
    ///   - stunServerPort: STUN server port
    ///   - outboundServer: Outbound proxy server
    ///   - outboundServerPort: Outbound proxy port
    ///   - registerTimeout: Registration timeout in seconds (default: 120)
    ///   - registerRetryTimes: Number of retry attempts (default: 3)
    ///   - videoBitrate: Video bitrate in kbps (default: 500)
    ///   - videoFrameRate: Video frame rate (default: 10)
    ///   - videoWidth: Video width in pixels (default: 352)
    ///   - videoHeight: Video height in pixels (default: 288)
    /// - Returns: 0 on success, error code otherwise
    func register(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let userName = arguments["userName"] as? String ?? ""
            let password = arguments["password"] as? String ?? ""
            let sipServer = arguments["sipServer"] as? String ?? ""
            let sipServerPort = Int32(arguments["sipServerPort"] as? Int ?? 5060)
            let displayName = arguments["displayName"] as? String ?? ""
            let authName = arguments["authName"] as? String ?? ""
            let userDomain = arguments["userDomain"] as? String ?? ""
            let stunServer = arguments["stunServer"] as? String ?? ""
            let stunServerPort = Int32(arguments["stunServerPort"] as? Int ?? 0)
            let outboundServer = arguments["outboundServer"] as? String ?? ""
            let outboundServerPort = Int32(arguments["outboundServerPort"] as? Int ?? 0)
            let registerTimeout = Int32(arguments["registerTimeout"] as? Int ?? 120)
            let registerRetryTimes = Int32(arguments["registerRetryTimes"] as? Int ?? 3)
            let videoBitrate = Int32(arguments["videoBitrate"] as? Int ?? 500)
            let videoFrameRate = Int32(arguments["videoFrameRate"] as? Int ?? 10)
            let videoWidth = Int32(arguments["videoWidth"] as? Int ?? 352)
            let videoHeight = Int32(arguments["videoHeight"] as? Int ?? 288)

            let result = portSIPSDK.setUser(
                userName,
                displayName: displayName,
                authName: authName,
                password: password,
                userDomain: userDomain,
                sipServer: sipServer,
                sipServerPort: sipServerPort,
                stunServer: stunServer,
                stunServerPort: stunServerPort,
                outboundServer: outboundServer,
                outboundServerPort: outboundServerPort
            )

            if result != 0 {
                return Int(result)
            }

            // Configuration complete
            // Note: Server registration must be called separately via registerServer()
            return 0
        }
    }

    /// Registers with the SIP server.
    /// This should be called after register() to complete the server registration.
    /// For P2P mode (when sipServer was empty in register()), this method is not needed.
    /// - Parameter arguments: Dictionary containing:
    ///   - registerTimeout: Registration timeout in seconds (default: 120)
    ///   - registerRetryTimes: Number of retry attempts (default: 3)
    /// - Returns: 0 on success, error code otherwise
    func registerServer(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let registerTimeout = Int32(arguments["registerTimeout"] as? Int ?? 120)
            let registerRetryTimes = Int32(arguments["registerRetryTimes"] as? Int ?? 3)

            return Int(portSIPSDK.registerServer(registerTimeout, retryTimes: registerRetryTimes))
        }
    }

    /// Refreshes the registration with the SIP server.
    /// Call this when the device's network changes (e.g. WiFi to cellular
    /// handoff) so the SDK re-registers over the new network interface and
    /// updates any active call session.
    /// - Parameter arguments: Dictionary containing:
    ///   - expires: Registration expiry in seconds; 0 keeps the previously
    ///     negotiated expiry and forces an immediate re-register (default: 0)
    /// - Returns: 0 on success, error code otherwise
    func refreshRegistration(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let expires = Int32(arguments["expires"] as? Int ?? 0)
            return Int(portSIPSDK.refreshRegistration(expires))
        }
    }

    /// Updates an active call session (sends a re-INVITE) to renegotiate the
    /// media streams — e.g. after a network change to re-anchor media to the
    /// new interface.
    /// - Parameter arguments: Dictionary containing:
    ///   - sessionId: The session ID of the call to update
    ///   - enableAudio: true to keep/enable the audio stream (default: true)
    ///   - enableVideo: true to enable the video stream (default: false)
    /// - Returns: 0 on success, error code otherwise
    func updateCall(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let sessionId = arguments["sessionId"] as? Int ?? -1
            let enableAudio = arguments["enableAudio"] as? Bool ?? true
            let enableVideo = arguments["enableVideo"] as? Bool ?? false

            return Int(portSIPSDK.updateCall(Int(sessionId), enableAudio: enableAudio, enableVideo: enableVideo))
        }
    }

    /// Enables SIP session timers (RFC 4028) for subsequent calls so the server
    /// reaps a dead leg at expiry when the client stops refreshing.
    /// - Parameter arguments: Dictionary containing:
    ///   - timerSeconds: Session interval in seconds (minimum 90)
    ///   - refreshMode: 0 = UAC (caller) refreshes (default), 1 = UAS (callee)
    /// - Returns: 0 on success, error code otherwise
    func enableSessionTimer(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let timerSeconds = Int32(arguments["timerSeconds"] as? Int ?? 90)
            let refreshMode: SESSION_REFRESH_MODE =
                (arguments["refreshMode"] as? Int == 1) ? SESSION_REFERESH_UAS : SESSION_REFERESH_UAC
            return Int(portSIPSDK.enableSessionTimer(timerSeconds, refreshMode: refreshMode))
        }
    }

    /// Unregisters the SIP account from the SIP server.
    ///
    /// The SDK remains initialized after this call, so the account can be
    /// re-registered later (via register()/registerServer()) without going
    /// through initialize() again. Use dispose() for a full teardown that
    /// also releases the SDK, removes lifecycle observers, and disposes the
    /// CallKit provider.
    func unRegister() {
        sdkQueue.sync {
            portSIPSDK.unRegisterServer(0)
        }
    }

    /// Sets the PortSIP license key.
    /// - Parameter arguments: Dictionary containing:
    ///   - licenseKey: The PortSIP license key
    /// - Returns: 0 on success, error code otherwise
    func setLicenseKey(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let licenseKey = arguments["licenseKey"] as? String ?? "PORTSIP_TEST_LICENSE"
            portSIPSDK.setLicenseKey(licenseKey)
            return 0
        }
    }

    /// Configures audio codecs for the SIP session.
    /// - Parameter arguments: Dictionary containing:
    ///   - audioCodecs: Array of audio codec values to enable
    /// - Returns: 0 on success, error code otherwise
    func setAudioCodecs(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            if let audioCodecs = arguments["audioCodecs"] as? [Int], !audioCodecs.isEmpty {
                portSIPSDK.clearAudioCodec()
                for codecValue in audioCodecs {
                    portSIPSDK.addAudioCodec(AUDIOCODEC_TYPE(rawValue: Int32(codecValue)))
                }
            }
            return 0
        }
    }

    /// Enables or disables the audio manager.
    /// This is critical for DTMF functionality.
    /// Note: On iOS, this is a no-op as audio management is handled differently
    /// than on Android. The method exists for API compatibility.
    /// - Parameter arguments: Dictionary containing:
    ///   - enable: Whether to enable the audio manager (default: true)
    /// - Returns: 0 on success (always succeeds on iOS)
    func enableAudioManager(arguments: [String: Any]) -> Int {
        // On iOS, audio management is handled via AVAudioSession which is
        // configured in configureAudioSession() during initialization.
        // This method exists for API compatibility with Android.
        // No additional action needed on iOS.
        return 0
    }

    /// Sets the SRTP (Secure Real-time Transport Protocol) policy.
    /// - Parameter arguments: Dictionary containing:
    ///   - policy: SRTP policy value:
    ///     - 0: None (no SRTP)
    ///     - 1: Prefer (prefer SRTP but allow non-SRTP)
    ///     - 2: Force (require SRTP)
    /// - Returns: 0 on success, error code otherwise
    func setSrtpPolicy(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let policy = UInt32(arguments["policy"] as? Int ?? 0)
            portSIPSDK.setSrtpPolicy(SRTP_POLICY(rawValue: policy), enableGcmCryptoSuites: false)
            return 0
        }
    }

    /// Enables or disables 3GPP tags in SIP messages.
    /// - Parameter arguments: Dictionary containing:
    ///   - enable: Whether to enable 3GPP tags (default: false)
    /// - Returns: 0 on success, error code otherwise
    func enable3GppTags(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let enable = arguments["enable"] as? Bool ?? false
            portSIPSDK.enable3GppTags(enable)
            return 0
        }
    }

    /// Enables or disables Comfort Noise Generation (CNG).
    /// CNG generates artificial background noise during silent periods to avoid dead silence.
    /// - Parameter arguments: Dictionary containing:
    ///   - enable: Whether to enable CNG (default: true)
    /// - Returns: 0 on success, error code otherwise
    func enableCNG(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let enable = arguments["enable"] as? Bool ?? true
            portSIPSDK.enableCNG(enable)
            return 0
        }
    }

    /// Enables or disables Voice Activity Detection (VAD).
    /// VAD detects when speech is present and can be used to reduce bandwidth during silence.
    /// - Parameter arguments: Dictionary containing:
    ///   - enable: Whether to enable VAD (default: true)
    /// - Returns: 0 on success, error code otherwise
    func enableVAD(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let enable = arguments["enable"] as? Bool ?? true
            portSIPSDK.enableVAD(enable)
            return 0
        }
    }

    /// Initiates an outgoing call to the specified callee.
    /// - Parameter arguments: Dictionary containing call parameters:
    ///   - callee: The SIP URI or phone number to call
    ///   - sendSdp: Whether to send SDP in INVITE (default: true)
    ///   - videoCall: Whether this is a video call (default: false)
    /// - Returns: Session ID on success, negative error code on failure
    func makeCall(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let callee = arguments["callee"] as? String ?? ""
            let sendSdp = arguments["sendSdp"] as? Bool ?? true
            let videoCall = arguments["videoCall"] as? Bool ?? false
            // Additional conference legs pass false so the whole conference stays
            // a single system call (one CallKit call).
            let reportToConnectionService = arguments["reportToConnectionService"] as? Bool ?? true
            let displayName = arguments["displayName"] as? String

            let sessionId = portSIPSDK.call(callee, sendSdp: sendSdp, videoCall: videoCall)

            // Only start audio and report to CallKit if call succeeded
            if sessionId > 0 {
                portSIPSDK.startAudio(AVAudioSession.sharedInstance())
                if reportToConnectionService {
                    PortsipCallKitProvider.shared.reportOutgoingCall(
                        sessionId: Int(sessionId),
                        callee: callee,
                        hasVideo: videoCall,
                        displayName: displayName
                    )
                }
            }

            return Int(sessionId)
        }
    }

    /// Hangs up an active call.
    /// - Parameter arguments: Dictionary containing:
    ///   - sessionId: The session ID of the call to hang up
    /// - Returns: 0 on success, error code otherwise
    func hangUp(arguments: [String: Any]) -> Int {
        let sessionId = arguments["sessionId"] as? Int ?? -1
        let reportToConnectionService = arguments["reportToConnectionService"] as? Bool ?? true

        // The merged-conference primary's CXCall is transferred to a
        // surviving leg instead of ended — the survivor has no CXCall of its
        // own and would lose the audio session. End just the SIP session.
        // For non-conference sessions this only prunes the tracking.
        if PortsipCallKitProvider.shared.transferSystemCallIfNeeded(endingSessionId: sessionId) != nil {
            return sdkQueue.sync { Int(portSIPSDK.hangUp(sessionId)) }
        }

        // Additional conference legs aren't registered with CallKit and share the
        // conference audio session, so drop them directly without routing through
        // CallKit (would target an unknown call) or stopping audio (would mute the
        // rest of the conference).
        if !reportToConnectionService {
            return sdkQueue.sync { Int(portSIPSDK.hangUp(sessionId)) }
        }

        // Route through CallKit only if this session has a CallKit call;
        // otherwise end directly (which also stops audio).
        if PortsipCallKitProvider.shared.isCallKitEnabled,
           PortsipCallKitProvider.shared.getUUID(for: sessionId) != nil {
            PortsipCallKitProvider.shared.requestEndCall(sessionId: sessionId)
            // CallKit path is asynchronous - return 0 as the request was submitted
            // Actual result will be delivered via onCallKitEndCall event
            return 0
        } else {
            // CallKit disabled, or this session has no CallKit call - perform the
            // action directly and return the actual result.
            return performEndCallAction(sessionId: sessionId)
        }
    }

    /// Creates an audio conference bridge. Sessions joined via [joinToConference]
    /// are mixed together so all participants hear each other.
    /// - Returns: conference id (>= 0) on success, error code otherwise
    func createAudioConference() -> Int {
        return sdkQueue.sync {
            return Int(portSIPSDK.createAudioConference())
        }
    }

    /// Sessions currently joined to the SDK audio-conference bridge. When
    /// CallKit cycles the audio session (deactivate → reactivate), the
    /// restarted audio engine does NOT re-wire conference mixing — re-joining
    /// the members does (see [activateAudioSession]). Guarded by sdkQueue.
    private var conferenceJoinedSessions: Set<Int> = []

    /// Joins a session into the existing conference.
    /// - Parameter arguments: Dictionary containing sessionId
    /// - Returns: 0 on success, error code otherwise
    func joinToConference(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let sessionId = arguments["sessionId"] as? Int ?? -1
            let result = Int(portSIPSDK.join(toConference: Int(sessionId)))
            if result == 0 {
                conferenceJoinedSessions.insert(sessionId)
            }
            return result
        }
    }

    /// Removes a session from the existing conference.
    /// - Parameter arguments: Dictionary containing sessionId
    /// - Returns: 0 on success, error code otherwise
    func removeFromConference(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let sessionId = arguments["sessionId"] as? Int ?? -1
            conferenceJoinedSessions.remove(sessionId)
            return Int(portSIPSDK.remove(fromConference: Int(sessionId)))
        }
    }

    /// Destroys the existing conference bridge. The SDK call returns void, so we
    /// report success (0) once it's been invoked.
    /// - Returns: 0
    func destroyConference() -> Int {
        sdkQueue.sync {
            conferenceJoinedSessions.removeAll()
            portSIPSDK.destroyConference()
        }
        // No bridge → no merged conference; a later session end must not try to
        // transfer the CXCall to a leg that's no longer conferenced.
        PortsipCallKitProvider.shared.clearConferenceTracking()
        return 0
    }

    /// Puts a call on hold.
    /// - Parameter arguments: Dictionary containing:
    ///   - sessionId: The session ID of the call to hold
    /// - Returns: 0 on success, error code otherwise
    func hold(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let sessionId = arguments["sessionId"] as? Int ?? -1

            let result = portSIPSDK.hold(Int(sessionId))
            // Mirror the hold to CallKit so the system UI shows the call as held
            // (and offers Swap when there's another call). No-ops for legs that
            // aren't registered with CallKit.
            if result == 0 {
                PortsipCallKitProvider.shared.noteHoldState(sessionId: sessionId, onHold: true)
                PortsipCallKitProvider.shared.reportCallHeld(sessionId: sessionId, onHold: true)
            }
            return Int(result)
        }
    }

    /// Resumes a call that was on hold.
    /// - Parameter arguments: Dictionary containing:
    ///   - sessionId: The session ID of the call to unhold
    /// - Returns: 0 on success, error code otherwise
    func unHold(arguments: [String: Any]) -> Int {
        return sdkQueue.sync {
            let sessionId = arguments["sessionId"] as? Int ?? -1

            let result = portSIPSDK.unHold(Int(sessionId))
            // Mirror the resume to CallKit (see hold()).
            if result == 0 {
                PortsipCallKitProvider.shared.noteHoldState(sessionId: sessionId, onHold: false)
                PortsipCallKitProvider.shared.reportCallHeld(sessionId: sessionId, onHold: false)
            }
            return Int(result)
        }
    }

    /// Swaps which of two calls is on hold: SDK-holds one leg, SDK-resumes the
    /// other, then mirrors BOTH to CallKit in one atomic CXTransaction (see
    /// PortsipCallKitProvider.reportCallsSwapped — two separate transactions
    /// make CallKit end one of the calls).
    /// - Parameter arguments: Dictionary containing:
    ///   - holdSessionId: The active leg to put on hold
    ///   - unholdSessionId: The held leg to resume
    /// - Returns: 0 on success, first failing SDK error code otherwise
    func swapHold(arguments: [String: Any]) -> Int {
        let holdSessionId = arguments["holdSessionId"] as? Int ?? -1
        let unholdSessionId = arguments["unholdSessionId"] as? Int ?? -1
        PortsipLogger.d("Controller", "swapHold BEGIN hold=\(holdSessionId) unhold=\(unholdSessionId)")
        let result: Int32 = sdkQueue.sync {
            let unholdResult = portSIPSDK.unHold(unholdSessionId)
            let holdResult = portSIPSDK.hold(holdSessionId)
            return unholdResult != 0 ? unholdResult : holdResult
        }
        PortsipLogger.d("Controller", "swapHold END result=\(result)")
        if result == 0 {
            PortsipCallKitProvider.shared.noteHoldState(sessionId: holdSessionId, onHold: true)
            PortsipCallKitProvider.shared.noteHoldState(sessionId: unholdSessionId, onHold: false)
            PortsipCallKitProvider.shared.reportCallsSwapped(
                holdSessionId: holdSessionId,
                unholdSessionId: unholdSessionId
            )
        }
        return Int(result)
    }

    /// Ends one leg and resumes another atomically (see
    /// PortsipCallKitProvider.endCallAndResume). With CallKit the delegates drive
    /// the SDK; without it, drive the SDK directly.
    /// - Parameter arguments: Dictionary containing:
    ///   - endSessionId: The leg to hang up
    ///   - resumeSessionId: The held leg to resume
    /// - Returns: 0
    func endCallAndResume(arguments: [String: Any]) -> Int {
        let endSessionId = arguments["endSessionId"] as? Int ?? -1
        let resumeSessionId = arguments["resumeSessionId"] as? Int ?? -1
        if PortsipCallKitProvider.shared.isCallKitEnabled {
            PortsipCallKitProvider.shared.endCallAndResume(
                endSessionId: endSessionId,
                resumeSessionId: resumeSessionId
            )
        } else {
            sdkQueue.sync {
                _ = portSIPSDK.hangUp(endSessionId)
                _ = portSIPSDK.unHold(resumeSessionId)
            }
        }
        return 0
    }

    /// Groups sessions into one native conference call via CallKit (see
    /// PortsipCallKitProvider.requestCallGroup). No call is ended.
    /// - Parameter arguments: Dictionary containing:
    ///   - sessionIds: The sessions to group into one conference call
    /// - Returns: 0 on submit, -1 on failure
    func requestCallGroup(arguments: [String: Any]) -> Int {
        let sessionIds = (arguments["sessionIds"] as? [Any] ?? [])
            .compactMap { ($0 as? NSNumber)?.intValue ?? ($0 as? Int) }
        return PortsipCallKitProvider.shared.requestCallGroup(sessionIds: sessionIds)
    }

    /// Collapses a merged conference to a single system call (legacy; see
    /// PortsipCallKitProvider.reportConferenceMerged). Superseded by
    /// requestCallGroup — kept for API compatibility.
    /// - Parameter arguments: Dictionary containing:
    ///   - primarySessionId: The leg whose CallKit call represents the conference
    ///   - mergedAwaySessionIds: The other legs whose CallKit calls to end
    /// - Returns: 0
    func reportConferenceMerged(arguments: [String: Any]) -> Int {
        let primarySessionId = arguments["primarySessionId"] as? Int ?? -1
        let mergedAway = (arguments["mergedAwaySessionIds"] as? [Any] ?? [])
            .compactMap { ($0 as? NSNumber)?.intValue ?? ($0 as? Int) }
        PortsipCallKitProvider.shared.reportConferenceMerged(
            primarySessionId: primarySessionId,
            mergedAwaySessionIds: mergedAway
        )
        return 0
    }

    /// Updates the display name the system call UI shows for a session
    /// (e.g. a conference title after a merge).
    /// - Parameter arguments: Dictionary containing:
    ///   - sessionId: The session whose system call to relabel
    ///   - displayName: The name to show
    /// - Returns: 0
    func updateOsCallDisplay(arguments: [String: Any]) -> Int {
        let sessionId = arguments["sessionId"] as? Int ?? -1
        let displayName = arguments["displayName"] as? String ?? ""
        PortsipCallKitProvider.shared.updateCallDisplay(
            sessionId: sessionId,
            displayName: displayName
        )
        return 0
    }

    /// Mutes or unmutes audio/video streams for a call session.
    /// - Parameter arguments: Dictionary containing:
    ///   - sessionId: The session ID of the call
    ///   - muteIncomingAudio: Whether to mute incoming audio (default: false)
    ///   - muteOutgoingAudio: Whether to mute outgoing audio (default: false)
    ///   - muteIncomingVideo: Whether to mute incoming video (default: false)
    ///   - muteOutgoingVideo: Whether to mute outgoing video (default: false)
    /// - Returns: 0 on success, error code otherwise
    func muteSession(arguments: [String: Any]) -> Int {
        let sessionId = arguments["sessionId"] as? Int ?? -1
        let muteOutgoingAudio = arguments["muteOutgoingAudio"] as? Bool ?? false

        // If CallKit is enabled, route through CallKit delegate
        if PortsipCallKitProvider.shared.isCallKitEnabled {
            PortsipCallKitProvider.shared.reportCallMuted(sessionId: sessionId, muted: muteOutgoingAudio)
        } else {
            // CallKit disabled - perform action directly
            performMuteAction(sessionId: sessionId, muted: muteOutgoingAudio)
        }

        return 0
    }

    /// Enables or disables the loudspeaker (speakerphone).
    /// - Parameter arguments: Dictionary containing:
    ///   - enable: Whether to enable the loudspeaker (default: false)
    ///   - sessionId: The session ID of the call (optional, used when CallKit is disabled)
    func setLoudspeakerStatus(arguments: [String: Any]) {
        let enable = arguments["enable"] as? Bool ?? false
        let sessionId = arguments["sessionId"] as? Int ?? -1

        sdkQueue.sync {
            // Always call SDK to change audio route
            portSIPSDK.setLoudspeakerStatus(enable)
        }

        // Remember the intent so it survives a CallKit session reactivation
        // (hold/swap/merge resets the route to the receiver).
        PortsipCallKitProvider.shared.setDesiredSpeaker(enable)

        // If CallKit is disabled, perform action directly
        // When CallKit is enabled, the audio route change notification handles this
        if !PortsipCallKitProvider.shared.isCallKitEnabled {
            performSpeakerAction(sessionId: sessionId, enableSpeaker: enable)
        }
    }

    /// Re-applies the loudspeaker through the SDK after a hold/swap resume drops
    /// the output to the receiver. Uses the SDK path (not an AVAudioSession
    /// override) so it sticks the same way the initial speaker-on does.
    func reassertLoudspeaker() {
        sdkQueue.sync {
            portSIPSDK.setLoudspeakerStatus(true)
        }
    }

    /// Sends a DTMF (Dual-Tone Multi-Frequency) tone during a call.
    /// - Parameter arguments: Dictionary containing:
    ///   - sessionId: The session ID of the call
    ///   - dtmf: The DTMF digit to send (0-9, *, #)
    ///   - playDtmfTone: Whether to play the tone locally (default: true)
    ///   - dtmfMethod: DTMF method (0=RFC2833, 1=INFO, 2=INBAND, default: 0)
    ///   - dtmfDuration: Duration of the tone in ms (default: 160)
    /// - Returns: 0 on success, error code otherwise
    func sendDtmf(arguments: [String: Any]) -> Int {
        let sessionId = Int(arguments["sessionId"] as? Int ?? -1)
        let dtmf = Int32(arguments["dtmf"] as? Int ?? 0)
        let digits = getDTMFChar(code: dtmf) ?? String(dtmf)

        // If CallKit is enabled, route through CallKit delegate
        if PortsipCallKitProvider.shared.isCallKitEnabled {
            PortsipCallKitProvider.shared.reportDTMF(sessionId: sessionId, digits: digits)
        } else {
            // CallKit disabled - perform action directly
            performDTMFAction(sessionId: sessionId, digits: digits)
        }

        return 0
    }

    /// Converts a DTMF code to character string
    /// - Parameter code: The DTMF code (0-9, 10=*, 11=#)
    /// - Returns: The character string, or nil if invalid
    private func getDTMFChar(code: Int32) -> String? {
        return DTMFCode.from(code: code)?.character
    }

    // MARK: - CallKit Integration Methods

    /// Performs end call action and sends event to Flutter.
    /// Called from CallKit delegate or directly when CallKit is disabled.
    /// - Parameter sessionId: The session ID of the call to end
    /// - Returns: 0 on success, error code otherwise
    @discardableResult
    func performEndCallAction(sessionId: Int) -> Int {
        let result = sdkQueue.sync {
            return portSIPSDK.hangUp(sessionId)
        }

        if result == 0 {
            // Only tear down the audio engine when this was the last call. When
            // another call survives (e.g. ending the active leg with a held leg
            // taking over), stopping here silences the survivor — it keeps using
            // the session. sessionCount still includes this leg (removed by the
            // CXEndCallAction handler after we return).
            if PortsipCallKitProvider.shared.sessionCount <= 1 {
                sdkQueue.sync {
                    portSIPSDK.stopAudio(AVAudioSession.sharedInstance())
                }
            }
            // Send event to Flutter
            let eventData: [String: Any] = [
                PortsipConstants.EventKeys.sessionId: sessionId
            ]
            PortsipEventBridge.shared.sendEvent(name: "onCallKitEndCall", data: eventData)
        }

        return Int(result)
    }

    /// Handles holding/unholding a call from CallKit.
    /// Called when the user holds or unholds a call via the CallKit UI.
    /// - Parameters:
    ///   - sessionId: The session ID of the call
    ///   - onHold: Whether to hold or unhold the call
    /// Sends the onCallKitHold event to Flutter. Called by the CXSetHeldCall
    /// delegate before the SDK work so the two actions of one Swap reach
    /// Flutter back-to-back.
    func notifyCallKitHold(sessionId: Int, onHold: Bool) {
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.onHold: onHold
        ]
        PortsipEventBridge.shared.sendEvent(name: "onCallKitHold", data: eventData)
    }

    /// Drives the SDK for a system-initiated hold. Flutter was already
    /// notified optimistically by the delegate (see [notifyCallKitHold]); on
    /// SDK failure the tracked state is reverted and a corrective event keeps
    /// Flutter in sync.
    func handleCallKitHold(sessionId: Int, onHold: Bool) {
        let result = sdkQueue.sync {
            return onHold ? portSIPSDK.hold(sessionId) : portSIPSDK.unHold(sessionId)
        }
        if result != 0 {
            PortsipLogger.e("Controller", "handleCallKitHold(\(sessionId), \(onHold)) SDK error \(result)")
            PortsipCallKitProvider.shared.noteHoldState(sessionId: sessionId, onHold: !onHold)
            notifyCallKitHold(sessionId: sessionId, onHold: !onHold)
        }
    }

    /// Called when CallKit ACTIVATES the shared audio session. CallKit owns
    /// session activation around hold / unhold / swap (the held call's session
    /// is deactivated and reactivated), so the SDK audio engine must (re)start
    /// here — otherwise the call goes silent after a hold/swap/merge even though
    /// the SIP media is fine. Idempotent: starting already-running audio is a
    /// no-op.
    func activateAudioSession() {
        sdkQueue.sync {
            portSIPSDK.startAudio(AVAudioSession.sharedInstance())
            // A conference bridge doesn't survive an audio-engine restart, and
            // re-joining sessions into the old bridge attaches them to a dead
            // mixer (joins return 0 but audio stays silent). Rebuild the
            // bridge from scratch and re-join the members — the same sequence
            // as a fresh merge.
            if !conferenceJoinedSessions.isEmpty {
                portSIPSDK.destroyConference()
                let confResult = portSIPSDK.createAudioConference()
                PortsipLogger.d("Controller", "audio reactivated: conference rebuilt → \(confResult)")
                for sessionId in conferenceJoinedSessions {
                    let rc = portSIPSDK.join(toConference: sessionId)
                    PortsipLogger.d("Controller", "audio reactivated: re-join \(sessionId) → \(rc)")
                }
            }
        }
    }

    /// Called when CallKit DEACTIVATES the shared audio session (call held or
    /// ended). Mirrors [activateAudioSession].
    func deactivateAudioSession() {
        sdkQueue.sync {
            portSIPSDK.stopAudio(AVAudioSession.sharedInstance())
        }
    }

    /// Performs mute/unmute action and sends event to Flutter.
    /// Called from CallKit delegate or directly when CallKit is disabled.
    /// - Parameters:
    ///   - sessionId: The session ID of the call
    ///   - muted: Whether to mute or unmute the call
    func performMuteAction(sessionId: Int, muted: Bool) {
        let result = sdkQueue.sync {
            return portSIPSDK.muteSession(
                sessionId,
                muteIncomingAudio: false,
                muteOutgoingAudio: muted,
                muteIncomingVideo: false,
                muteOutgoingVideo: muted
            )
        }

        if result == 0 {
            // Send event to Flutter
            let eventData: [String: Any] = [
                PortsipConstants.EventKeys.sessionId: sessionId,
                PortsipConstants.EventKeys.muted: muted
            ]
            PortsipEventBridge.shared.sendEvent(name: "onCallKitMute", data: eventData)
        }
    }

    /// Sends speaker state change event to Flutter.
    /// Called from CallKit audio route change or directly when CallKit is disabled.
    /// - Parameters:
    ///   - sessionId: The session ID of the call
    ///   - enableSpeaker: Whether the speaker is enabled
    func performSpeakerAction(sessionId: Int, enableSpeaker: Bool) {
        // NOTE: Do NOT call portSIPSDK.setLoudspeakerStatus(enableSpeaker) here.
        // This method is called in response to an AVAudioSession route change (e.g. user tapped CallKit button).
        // The route is ALREADY changed. Calling setLoudspeakerStatus() again may trigger another route change
        // or reset the audio session, causing the speaker to toggle off (the "deselect" bug).
        // We only need to notify Flutter so the UI stays in sync.

        // Send event to Flutter
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.enableSpeaker: enableSpeaker
        ]
        PortsipEventBridge.shared.sendEvent(name: "onCallKitSpeaker", data: eventData)
    }

    /// Performs DTMF tone send action and sends event to Flutter.
    /// Called from CallKit delegate or directly when CallKit is disabled.
    /// - Parameters:
    ///   - sessionId: The session ID of the call
    ///   - digits: The DTMF digits to send
    func performDTMFAction(sessionId: Int, digits: String) {
        sdkQueue.sync {
            // Send each digit
            for char in digits {
                if let digit = getDTMFCode(for: char) {
                    // Local keypad feedback: play the system DTMF tone (sound IDs
                    // 1200–1211), which follows the active output route including
                    // the loudspeaker override. The SDK's own playDtmfTone is left
                    // OFF — it only reaches the speaker after an audio-engine
                    // restart (e.g. a merge), so it's silent on speaker in a plain
                    // call and would double up once a conference exists.
                    AudioServicesPlaySystemSound(SystemSoundID(1200 + Int(digit)))
                    _ = portSIPSDK.sendDtmf(
                        sessionId,
                        dtmfMethod: DTMF_RFC2833,
                        code: digit,
                        dtmfDration: 160,
                        playDtmfTone: false
                    )
                }
            }
        }

        // Send event to Flutter
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.digits: digits
        ]
        PortsipEventBridge.shared.sendEvent(name: "onCallKitDTMF", data: eventData)
    }
    
    /// Converts a character to DTMF code
    /// - Parameter char: The character to convert (0-9, *, #)
    /// - Returns: The DTMF code, or nil if invalid
    private func getDTMFCode(for char: Character) -> Int32? {
        return DTMFCode.from(character: char)?.rawValue
    }

    // MARK: - Cleanup Methods

    /// Tears down the native PortSIP SDK so a different SIP user can be
    /// loaded via initialize() + register() again, without shutting the
    /// plugin down. Used for runtime user swap (e.g. switching phone number).
    ///
    /// Unlike dispose(), this does NOT remove lifecycle observers or tear
    /// down CallKit — those are app-lifetime concerns.
    func unInitialize() {
        sdkQueue.sync {
            conferenceJoinedSessions.removeAll()
            if let sdk = _portSIPSDK {
                sdk.unRegisterServer(0)
                sdk.unInitialize()
                sdk.delegate = nil
            }
            _portSIPSDK = nil
        }
    }

    /// Disposes of all SDK resources and removes observers.
    /// This should be called when the plugin is being detached or when the app
    /// needs to completely release all PortSIP resources.
    ///
    /// This method:
    /// - Removes all NotificationCenter observers
    /// - Unregisters from the SIP server
    /// - Uninitializes the SDK
    /// - Disposes of CallKit provider
    func dispose() {
        sdkQueue.sync {
            // Remove lifecycle observers
            NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)

            // Unregister and uninitialize SDK
            if let sdk = _portSIPSDK {
                sdk.unRegisterServer(0)
                sdk.unInitialize()
                sdk.delegate = nil
            }

            // Clear the SDK instance so a new one will be created on next access
            _portSIPSDK = nil
        }

        // Dispose CallKit provider
        PortsipCallKitProvider.shared.dispose()
    }

}

// MARK: - PortSIPEventDelegate Methods
extension PortsipController: PortSIPEventDelegate {

    // MARK: - Registration Events (Used)

    func onRegisterSuccess(_ statusText: String!, statusCode: Int32, sipMessage: String!) {
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.statusText: statusText ?? "",
            PortsipConstants.EventKeys.statusCode: Int(statusCode),
            PortsipConstants.EventKeys.sipMessage: sipMessage ?? ""
        ]
        PortsipEventBridge.shared.sendEvent(name: "onRegisterSuccess", data: eventData)
    }

    func onRegisterFailure(_ statusText: String!, statusCode: Int32, sipMessage: String!) {
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.statusText: statusText ?? "",
            PortsipConstants.EventKeys.statusCode: Int(statusCode),
            PortsipConstants.EventKeys.sipMessage: sipMessage ?? ""
        ]
        PortsipEventBridge.shared.sendEvent(name: "onRegisterFailure", data: eventData)
    }

    // MARK: - Call Events (Used)

    // Note: This plugin is designed for outgoing calls only.
    // Incoming call events are not forwarded to Flutter.
    func onInviteIncoming(_ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!, callee: String!, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool, existsVideo: Bool, sipMessage: String!) {
        // Not implemented - this plugin supports outgoing calls only
    }

    func onInviteTrying(_ sessionId: Int) {
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId
        ]
        PortsipEventBridge.shared.sendEvent(name: "onInviteTrying", data: eventData)
    }

    func onInviteRinging(_ sessionId: Int, statusText: String!, statusCode: Int32, sipMessage: String!) {
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.statusText: statusText ?? "",
            PortsipConstants.EventKeys.statusCode: Int(statusCode),
            PortsipConstants.EventKeys.sipMessage: sipMessage ?? ""
        ]
        PortsipEventBridge.shared.sendEvent(name: "onInviteRinging", data: eventData)
    }

    func onInviteAnswered(_ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!, callee: String!, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool, existsVideo: Bool, sipMessage: String!) {
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.callerDisplayName: callerDisplayName ?? "",
            PortsipConstants.EventKeys.caller: caller ?? "",
            PortsipConstants.EventKeys.calleeDisplayName: calleeDisplayName ?? "",
            PortsipConstants.EventKeys.callee: callee ?? "",
            PortsipConstants.EventKeys.audioCodecs: audioCodecs ?? "",
            PortsipConstants.EventKeys.videoCodecs: videoCodecs ?? "",
            PortsipConstants.EventKeys.existsAudio: existsAudio,
            PortsipConstants.EventKeys.existsVideo: existsVideo,
            PortsipConstants.EventKeys.sipMessage: sipMessage ?? ""
        ]
        PortsipEventBridge.shared.sendEvent(name: "onInviteAnswered", data: eventData)
    }

    func onInviteFailure(_ sessionId: Int, callerDisplayName: String!, caller: String!, calleeDisplayName: String!, callee: String!, reason: String!, code: Int32, sipMessage: String!) {
        // A merged-conference primary's CXCall is transferred to a surviving
        // leg instead of ended (see transferSystemCallIfNeeded).
        if PortsipCallKitProvider.shared.transferSystemCallIfNeeded(endingSessionId: sessionId) == nil {
            PortsipCallKitProvider.shared.reportCallEnded(sessionId: sessionId, reason: .failed)
        }

        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.callerDisplayName: callerDisplayName ?? "",
            PortsipConstants.EventKeys.caller: caller ?? "",
            PortsipConstants.EventKeys.calleeDisplayName: calleeDisplayName ?? "",
            PortsipConstants.EventKeys.callee: callee ?? "",
            PortsipConstants.EventKeys.reason: reason ?? "",
            PortsipConstants.EventKeys.code: Int(code),
            PortsipConstants.EventKeys.sipMessage: sipMessage ?? ""
        ]
        PortsipEventBridge.shared.sendEvent(name: "onInviteFailure", data: eventData)
    }

    func onInviteConnected(_ sessionId: Int) {
        // Report call connected to CallKit (for outgoing calls)
        PortsipCallKitProvider.shared.reportCallConnected(sessionId: sessionId)

        // A newly connected leg negotiates media and the SDK drops the route to
        // the receiver — open the window so the loudspeaker is re-asserted (adding
        // a call rings longer than the swap window, so this is its own trigger).
        PortsipCallKitProvider.shared.beginAudioReconfiguration()

        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId
        ]
        PortsipEventBridge.shared.sendEvent(name: "onInviteConnected", data: eventData)
    }

    func onInviteClosed(_ sessionId: Int, sipMessage: String!) {
        // A merged-conference primary's CXCall is transferred to a surviving
        // leg instead of ended (see transferSystemCallIfNeeded).
        if PortsipCallKitProvider.shared.transferSystemCallIfNeeded(endingSessionId: sessionId) == nil {
            PortsipCallKitProvider.shared.reportCallEnded(sessionId: sessionId, reason: .remoteEnded)
        }

        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.sipMessage: sipMessage ?? ""
        ]
        PortsipEventBridge.shared.sendEvent(name: "onInviteClosed", data: eventData)
    }

    // MARK: - Remote Hold Events (Used)

    func onRemoteHold(_ sessionId: Int) {
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId
        ]
        PortsipEventBridge.shared.sendEvent(name: "onRemoteHold", data: eventData)
    }

    func onRemoteUnHold(_ sessionId: Int, audioCodecs: String!, videoCodecs: String!, existsAudio: Bool, existsVideo: Bool) {
        let eventData: [String: Any] = [
            PortsipConstants.EventKeys.sessionId: sessionId,
            PortsipConstants.EventKeys.audioCodecs: audioCodecs ?? "",
            PortsipConstants.EventKeys.videoCodecs: videoCodecs ?? "",
            PortsipConstants.EventKeys.existsAudio: existsAudio,
            PortsipConstants.EventKeys.existsVideo: existsVideo
        ]
        PortsipEventBridge.shared.sendEvent(name: "onRemoteUnHold", data: eventData)
    }

    // MARK: - Unused Delegate Methods (Required by Protocol - Empty Implementations)

    func onInviteSessionProgress(_ sessionId: Int, audioCodecs: String!, videoCodecs: String!, existsEarlyMedia: Bool, existsAudio: Bool, existsVideo: Bool, sipMessage: String!) {}
    func onInviteUpdated(_ sessionId: Int, audioCodecs: String!, videoCodecs: String!, screenCodecs: String!, existsAudio: Bool, existsVideo: Bool, existsScreen: Bool, sipMessage: String!) {}
    func onInviteBeginingForward(_ forwardTo: String!) {}
    func onDialogStateUpdated(_ BLFMonitoredUri: String!, blfDialogState BLFDialogState: String!, blfDialogId BLFDialogId: String!, blfDialogDirection BLFDialogDirection: String!) {}
    func onReceivedRefer(_ sessionId: Int, referId: Int, to: String!, from: String!, referSipMessage: String!) {}
    func onReferAccepted(_ sessionId: Int) {}
    func onReferRejected(_ sessionId: Int, reason: String!, code: Int32) {}
    func onTransferTrying(_ sessionId: Int) {}
    func onTransferRinging(_ sessionId: Int) {}
    func onACTVTransferSuccess(_ sessionId: Int) {}
    func onACTVTransferFailure(_ sessionId: Int, reason: String!, code: Int32) {}
    func onReceivedSignaling(_ sessionId: Int, message: String!) {}
    func onSendingSignaling(_ sessionId: Int, message: String!) {}
    func onWaitingVoiceMessage(_ messageAccount: String!, urgentNewMessageCount: Int32, urgentOldMessageCount: Int32, newMessageCount: Int32, oldMessageCount: Int32) {}
    func onWaitingFaxMessage(_ messageAccount: String!, urgentNewMessageCount: Int32, urgentOldMessageCount: Int32, newMessageCount: Int32, oldMessageCount: Int32) {}
    func onRecvDtmfTone(_ sessionId: Int, tone: Int32) {}
    func onRecvOptions(_ optionsMessage: String!) {}
    func onRecvInfo(_ infoMessage: String!) {}
    func onRecvNotifyOfSubscription(_ subscribeId: Int, notifyMessage: String!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32) {}
    func onPresenceRecvSubscribe(_ subscribeId: Int, fromDisplayName: String!, from: String!, subject: String!) {}
    func onPresenceOnline(_ fromDisplayName: String!, from: String!, stateText: String!) {}
    func onPresenceOffline(_ fromDisplayName: String!, from: String!) {}
    func onRecvMessage(_ sessionId: Int, mimeType: String!, subMimeType: String!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32) {}
    func onRecvOutOfDialogMessage(_ fromDisplayName: String!, from: String!, toDisplayName: String!, to: String!, mimeType: String!, subMimeType: String!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32, sipMessage: String!) {}
    func onSendMessageSuccess(_ sessionId: Int, messageId: Int, sipMessage: String!) {}
    func onSendMessageFailure(_ sessionId: Int, messageId: Int, reason: String!, code: Int32, sipMessage: String!) {}
    func onSendOutOfDialogMessageSuccess(_ messageId: Int, fromDisplayName: String!, from: String!, toDisplayName: String!, to: String!, sipMessage: String!) {}
    func onSendOutOfDialogMessageFailure(_ messageId: Int, fromDisplayName: String!, from: String!, toDisplayName: String!, to: String!, reason: String!, code: Int32, sipMessage: String!) {}
    func onSubscriptionFailure(_ subscribeId: Int, statusCode: Int32) {}
    func onSubscriptionTerminated(_ subscribeId: Int) {}
    func onPlayFileFinished(_ sessionId: Int, fileName: String!) {}
    func onStatistics(_ sessionId: Int, stat: String!) {}
    func onRTPPacketCallback(_ sessionId: Int, mediaType: Int32, direction: DIRECTION_MODE, rtpPacket: UnsafeMutablePointer<UInt8>!, packetSize: Int32) {}
    func onAudioRawCallback(_ sessionId: Int, audioCallbackMode: Int32, data: UnsafeMutablePointer<UInt8>!, dataLength: Int32, samplingFreqHz: Int32) {}
    func onVideoRawCallback(_ sessionId: Int, videoCallbackMode: Int32, width: Int32, height: Int32, data: UnsafeMutablePointer<UInt8>!, dataLength: Int32) -> Int32 { return 0 }
}
