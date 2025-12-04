package com.tagonsoft.portsip

import android.app.Activity
import android.content.Context
import com.portsip.OnPortSIPEvent
import com.portsip.PortSipEnumDefine
import com.portsip.PortSipSdk
import java.lang.ref.WeakReference

/**
 * Controller class that manages the PortSIP SDK integration for the Flutter plugin.
 * This singleton class handles all SIP operations including initialization, registration,
 * call management, and event delegation to the Flutter side.
 *
 * Thread Safety: All SDK operations are synchronized using sdkLock to prevent race conditions
 * between method calls from the main thread and callbacks from SDK internal threads.
 */
class PortsipController private constructor() : OnPortSIPEvent {

    private var portSipSdk: PortSipSdk? = null
    private var context: Context? = null

    /** Weak reference to the current Activity for permission dialogs and UI operations */
    private var activityRef: WeakReference<Activity>? = null

    /// Lock object for synchronizing SDK operations
    private val sdkLock = Any()

    companion object {
        private const val COMPONENT = "Controller"

        /**
         * Shared singleton instance of the PortsipController
         */
        val shared = PortsipController()
    }
    
    /**
     * Sets the Android application context needed for SDK initialization.
     * This must be called before any other SDK operations.
     *
     * @param appContext The application context
     */
    fun setContext(appContext: Context) {
        context = appContext.applicationContext
    }

    /**
     * Sets the current Activity reference for permission dialogs and UI operations.
     * Uses WeakReference to avoid memory leaks.
     *
     * @param activity The current Activity, or null to clear
     */
    fun setActivity(activity: Activity?) {
        activityRef = activity?.let { WeakReference(it) }
    }

    /**
     * Gets the current Activity if available.
     * Returns null if no Activity is attached or if it has been garbage collected.
     *
     * @return The current Activity or null
     */
    fun getActivity(): Activity? {
        return activityRef?.get()
    }
    
    /**
     * Initializes the PortSIP SDK with the provided configuration.
     * @param arguments Map containing initialization parameters:
     *   - transport: Transport protocol (UDP=0, TCP=1, TLS=2)
     *   - localIP: Local IP address to bind (default: "0.0.0.0")
     *   - localSIPPort: Local SIP port (default: 5060)
     *   - logLevel: Logging level (default: 0)
     *   - logFilePath: Path for log files
     *   - maxCallLines: Maximum concurrent call lines (default: 3)
     *   - sipAgent: SIP user agent string
     *   - audioDeviceLayer: Audio device layer (default: 0)
     *   - videoDeviceLayer: Video device layer (default: 0)
     *   - TLSCertificatesRootPath: Root path for TLS certificates
     *   - TLSCipherList: TLS cipher list
     *   - verifyTLSCertificate: Whether to verify TLS certificates (default: false)
     *   - dnsServers: DNS servers to use
     *   - ptime: Audio packet time in ms (default: 20)
     *   - maxPtime: Maximum audio packet time in ms (default: 60)
     * @return 0 on success, error code otherwise
     */
    fun initialize(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val ctx = context ?: return -1

        val transport = (arguments["transport"] as? Int) ?: 0
        val localIP = (arguments["localIP"] as? String) ?: "0.0.0.0"
        val localSIPPort = (arguments["localSIPPort"] as? Int) ?: 5060
        val logLevel = (arguments["logLevel"] as? Int) ?: 0
        val logFilePath = (arguments["logFilePath"] as? String) ?: ""
        val maxCallLines = (arguments["maxCallLines"] as? Int) ?: 3
        val sipAgent = (arguments["sipAgent"] as? String) ?: "PortSIP SDK for Android"
        val audioDeviceLayer = (arguments["audioDeviceLayer"] as? Int) ?: 0
        val videoDeviceLayer = (arguments["videoDeviceLayer"] as? Int) ?: 0
        val tlsCertificatesRootPath = (arguments["tlsCertificatesRootPath"] as? String) ?: ""
        val tlsCipherList = (arguments["tlsCipherList"] as? String) ?: ""
        val verifyTLSCertificate = (arguments["verifyTLSCertificate"] as? Boolean) ?: false
        val dnsServers = (arguments["dnsServers"] as? String) ?: ""
        val ptime = (arguments["ptime"] as? Int) ?: 20
        val maxPtime = (arguments["maxPtime"] as? Int) ?: 60

        // Create SDK instance
        portSipSdk = PortSipSdk(ctx)
        portSipSdk?.setOnPortSIPEvent(this)

        val result = portSipSdk?.initialize(
            transport,
            localIP,
            localSIPPort,
            logLevel,
            logFilePath,
            maxCallLines,
            sipAgent,
            audioDeviceLayer,
            videoDeviceLayer,
            tlsCertificatesRootPath,
            tlsCipherList,
            verifyTLSCertificate,
            dnsServers
        ) ?: -1

        // Configure audio settings after successful initialization
        if (result == 0) {
            // Set audio packet time (ptime) - important for audio quality and compatibility
            portSipSdk?.setAudioSamples(ptime, maxPtime)
            PortsipLogger.d(COMPONENT, "SDK initialized successfully")
        } else {
            PortsipLogger.e(COMPONENT, "SDK initialization failed with error code: $result")
        }

        return result
    }
    
    /**
     * Registers the SIP account with the server or sets up P2P mode.
     * @param arguments Map containing registration parameters
     * @return 0 on success, error code otherwise
     */
    fun register(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val userName = (arguments["userName"] as? String) ?: ""
        val password = (arguments["password"] as? String) ?: ""
        val sipServer = (arguments["sipServer"] as? String) ?: ""
        val sipServerPort = (arguments["sipServerPort"] as? Int) ?: 5060
        val displayName = (arguments["displayName"] as? String) ?: ""
        val authName = (arguments["authName"] as? String) ?: ""
        val userDomain = (arguments["userDomain"] as? String) ?: ""
        val stunServer = (arguments["stunServer"] as? String) ?: ""
        val stunServerPort = (arguments["stunServerPort"] as? Int) ?: 0
        val outboundServer = (arguments["outboundServer"] as? String) ?: ""
        val outboundServerPort = (arguments["outboundServerPort"] as? Int) ?: 0
        val registerTimeout = (arguments["registerTimeout"] as? Int) ?: 120
        val registerRetryTimes = (arguments["registerRetryTimes"] as? Int) ?: 3
        val videoBitrate = (arguments["videoBitrate"] as? Int) ?: 500
        val videoFrameRate = (arguments["videoFrameRate"] as? Int) ?: 10
        val videoWidth = (arguments["videoWidth"] as? Int) ?: 352
        val videoHeight = (arguments["videoHeight"] as? Int) ?: 288

        val result = portSipSdk?.setUser(
            userName,
            displayName,
            authName,
            password,
            userDomain,
            sipServer,
            sipServerPort,
            stunServer,
            stunServerPort,
            outboundServer,
            outboundServerPort
        ) ?: -1

        if (result != 0) {
            PortsipLogger.e(COMPONENT, "Failed to set user credentials, error code: $result")
            return result
        }

        // Set default video device
        portSipSdk?.setVideoDeviceId(1)

        // Configuration complete
        // Note: Audio manager, SRTP policy, and 3GPP tags can be configured via separate method calls
        // Note: Server registration must be called separately via registerServer()
        return 0
    }
    
    /**
     * Registers with the SIP server.
     * This should be called after register() to complete the server registration.
     * For P2P mode (when sipServer was empty in register()), this method is not needed.
     * @param arguments Map containing registerTimeout and registerRetryTimes
     * @return 0 on success, error code otherwise
     */
    fun registerServer(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val registerTimeout = (arguments["registerTimeout"] as? Int) ?: 120
        val registerRetryTimes = (arguments["registerRetryTimes"] as? Int) ?: 3

        return portSipSdk?.registerServer(registerTimeout, registerRetryTimes) ?: -1
    }

    /**
     * Unregisters from the SIP server and uninitializes the SDK.
     */
    fun unRegister() = synchronized(sdkLock) {
        portSipSdk?.unRegisterServer(0)
        portSipSdk?.unInitialize()
    }

    /**
     * Sets the PortSIP license key.
     * @param arguments Map containing licenseKey
     * @return 0 on success, error code otherwise
     */
    fun setLicenseKey(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val licenseKey = (arguments["licenseKey"] as? String) ?: "PORTSIP_TEST_LICENSE"
        portSipSdk?.setLicenseKey(licenseKey)
        return 0
    }

    /**
     * Configures audio codecs for the SIP session.
     * @param arguments Map containing audioCodecs array
     * @return 0 on success, error code otherwise
     */
    fun setAudioCodecs(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        portSipSdk?.clearAudioCodec()
        val audioCodecs = arguments["audioCodecs"] as? List<*>
        if (audioCodecs != null && audioCodecs.isNotEmpty()) {
            for (codec in audioCodecs) {
                if (codec is Int) {
                    portSipSdk?.addAudioCodec(codec)
                }
            }
        }
        return 0
    }

    /**
     * Enables or disables the audio manager.
     * This is critical for DTMF functionality.
     * @param arguments Map containing enable flag
     * @return 0 on success, error code otherwise
     */
    fun enableAudioManager(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val enable = (arguments["enable"] as? Boolean) ?: true
        portSipSdk?.enableAudioManager(enable)
        PortsipLogger.d(COMPONENT, "Audio manager ${if (enable) "enabled" else "disabled"}")
        return 0
    }

    /**
     * Sets the SRTP (Secure Real-time Transport Protocol) policy.
     * @param arguments Map containing policy value:
     *   - 0: None (no SRTP)
     *   - 1: Prefer (prefer SRTP but allow non-SRTP)
     *   - 2: Force (require SRTP)
     * @return 0 on success, error code otherwise
     */
    fun setSrtpPolicy(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val policy = (arguments["policy"] as? Int) ?: 0
        portSipSdk?.setSrtpPolicy(policy)
        PortsipLogger.d(COMPONENT, "SRTP policy set to $policy")
        return 0
    }

    /**
     * Enables or disables 3GPP tags in SIP messages.
     * @param arguments Map containing enable flag
     * @return 0 on success, error code otherwise
     */
    fun enable3GppTags(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val enable = (arguments["enable"] as? Boolean) ?: false
        portSipSdk?.enable3GppTags(enable)
        PortsipLogger.d(COMPONENT, "3GPP tags ${if (enable) "enabled" else "disabled"}")
        return 0
    }

    /**
     * Enables or disables Acoustic Echo Cancellation (AEC).
     * AEC removes echo from the audio signal caused by speaker-to-microphone feedback.
     * @param arguments Map containing enable flag
     * @return 0 on success, error code otherwise
     */
    fun enableAEC(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val enable = (arguments["enable"] as? Boolean) ?: true
        portSipSdk?.enableAEC(enable)
        PortsipLogger.d(COMPONENT, "AEC ${if (enable) "enabled" else "disabled"}")
        return 0
    }

    /**
     * Enables or disables Automatic Gain Control (AGC).
     * AGC automatically adjusts the microphone volume to maintain consistent audio levels.
     * @param arguments Map containing enable flag
     * @return 0 on success, error code otherwise
     */
    fun enableAGC(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val enable = (arguments["enable"] as? Boolean) ?: true
        portSipSdk?.enableAGC(enable)
        PortsipLogger.d(COMPONENT, "AGC ${if (enable) "enabled" else "disabled"}")
        return 0
    }

    /**
     * Enables or disables Comfort Noise Generation (CNG).
     * CNG generates artificial background noise during silent periods to avoid dead silence.
     * @param arguments Map containing enable flag
     * @return 0 on success, error code otherwise
     */
    fun enableCNG(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val enable = (arguments["enable"] as? Boolean) ?: true
        portSipSdk?.enableCNG(enable)
        PortsipLogger.d(COMPONENT, "CNG ${if (enable) "enabled" else "disabled"}")
        return 0
    }

    /**
     * Enables or disables Voice Activity Detection (VAD).
     * VAD detects when speech is present and can be used to reduce bandwidth during silence.
     * @param arguments Map containing enable flag
     * @return 0 on success, error code otherwise
     */
    fun enableVAD(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val enable = (arguments["enable"] as? Boolean) ?: true
        portSipSdk?.enableVAD(enable)
        PortsipLogger.d(COMPONENT, "VAD ${if (enable) "enabled" else "disabled"}")
        return 0
    }

    /**
     * Enables or disables Automatic Noise Suppression (ANS).
     * ANS reduces background noise in the audio signal.
     * @param arguments Map containing enable flag
     * @return 0 on success, error code otherwise
     */
    fun enableANS(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val enable = (arguments["enable"] as? Boolean) ?: false
        portSipSdk?.enableANS(enable)
        PortsipLogger.d(COMPONENT, "ANS ${if (enable) "enabled" else "disabled"}")
        return 0
    }

    /**
     * Initiates an outgoing call to the specified callee.
     * @param arguments Map containing call parameters
     * @return Session ID on success, negative error code on failure.
     *         Returns Int for cross-platform consistency with iOS and Dart.
     *         Note: The underlying SDK returns Long, but session IDs fit within Int range.
     */
    fun makeCall(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val callee = (arguments["callee"] as? String) ?: ""
        val sendSdp = (arguments["sendSdp"] as? Boolean) ?: true
        val videoCall = (arguments["videoCall"] as? Boolean) ?: false

        val sessionId = portSipSdk?.call(callee, sendSdp, videoCall) ?: -1L

        // Report outgoing call to ConnectionService (Android's CallKit equivalent)
        if (sessionId > 0 && context != null) {
            PortsipConnectionService.reportOutgoingCall(
                context!!,
                sessionId,
                callee,
                videoCall
            )
        }

        // Convert to Int for cross-platform consistency
        // Session IDs from PortSIP SDK fit within 32-bit signed integer range
        return sessionId.toInt()
    }

    /**
     * Hangs up an active call.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun hangUp(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        return portSipSdk?.hangUp(sessionId) ?: -1
    }

    /**
     * Puts a call on hold.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun hold(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        return portSipSdk?.hold(sessionId) ?: -1
    }

    /**
     * Resumes a call that was on hold.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun unHold(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        return portSipSdk?.unHold(sessionId) ?: -1
    }

    /**
     * Mutes or unmutes audio/video streams for a call session.
     * @param arguments Map containing mute parameters
     * @return 0 on success, error code otherwise
     */
    fun muteSession(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val muteIncomingAudio = (arguments["muteIncomingAudio"] as? Boolean) ?: false
        val muteOutgoingAudio = (arguments["muteOutgoingAudio"] as? Boolean) ?: false
        val muteIncomingVideo = (arguments["muteIncomingVideo"] as? Boolean) ?: false
        val muteOutgoingVideo = (arguments["muteOutgoingVideo"] as? Boolean) ?: false

        return portSipSdk?.muteSession(
            sessionId,
            muteIncomingAudio,
            muteOutgoingAudio,
            muteIncomingVideo,
            muteOutgoingVideo
        ) ?: -1
    }

    /**
     * Enables or disables the loudspeaker (speakerphone).
     * @param arguments Map containing enable flag
     */
    fun setLoudspeakerStatus(arguments: Map<String, Any?>) = synchronized(sdkLock) {
        val enable = (arguments["enable"] as? Boolean) ?: false
        val audioDevice = if (enable) {
            PortSipEnumDefine.AudioDevice.SPEAKER_PHONE
        } else {
            PortSipEnumDefine.AudioDevice.EARPIECE
        }
        portSipSdk?.setAudioDevice(audioDevice)
        PortsipLogger.d(COMPONENT, "Loudspeaker ${if (enable) "enabled" else "disabled"}")
    }

    /**
     * Sends a DTMF (Dual-Tone Multi-Frequency) tone during a call.
     * @param arguments Map containing DTMF parameters
     * @return 0 on success, error code otherwise
     */
    fun sendDtmf(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val dtmf = (arguments["dtmf"] as? Int) ?: 0
        val playDtmfTone = (arguments["playDtmfTone"] as? Boolean) ?: true

        // Map integer to SDK constant
        val dtmfMethod = (arguments["dtmfMethod"] as? Int) ?: 0
        val dtmfDuration = (arguments["dtmfDuration"] as? Int) ?: 160  // Default to 160ms

        val result = portSipSdk?.sendDtmf(
            sessionId,
            dtmfMethod,
            dtmf,
            dtmfDuration,
            playDtmfTone
        ) ?: -1

        return result
    }

    // MARK: - ConnectionService Methods (Android equivalent to iOS CallKit)

    /**
     * Configures ConnectionService with the specified settings.
     * @param arguments Map containing appName and canUseConnectionService
     * @return 0 on success
     */
    fun configureConnectionService(arguments: Map<String, Any?>): Int {
        val ctx = context ?: return -1
        val appName = (arguments["appName"] as? String) ?: "PortSIP"
        val canUseConnectionService = (arguments["canUseConnectionService"] as? Boolean) ?: true

        PortsipConnectionService.configure(ctx, appName, canUseConnectionService)
        PortsipLogger.d(COMPONENT, "ConnectionService configured: appName=$appName, enabled=$canUseConnectionService")
        return 0
    }

    /**
     * Enables or disables ConnectionService at runtime.
     * @param arguments Map containing enabled flag
     * @return 0 on success
     */
    fun enableConnectionService(arguments: Map<String, Any?>): Int {
        val ctx = context ?: return -1
        val enabled = (arguments["enabled"] as? Boolean) ?: true

        PortsipConnectionService.setEnabled(ctx, enabled)
        PortsipLogger.d(COMPONENT, "ConnectionService ${if (enabled) "enabled" else "disabled"}")
        return 0
    }

    // MARK: - ConnectionService Callback Handlers (called from PortsipConnection)

    /**
     * Called when the user ends a call from the system UI.
     * @param sessionId The session ID of the call to end
     */
    fun handleConnectionServiceEndCall(sessionId: Long) = synchronized(sdkLock) {
        PortsipLogger.d(COMPONENT, "ConnectionService end call for session $sessionId")
        portSipSdk?.hangUp(sessionId)
    }

    /**
     * Called when the user toggles hold from the system UI.
     * @param sessionId The session ID of the call
     * @param onHold Whether to put the call on hold
     */
    fun handleConnectionServiceHold(sessionId: Long, onHold: Boolean) = synchronized(sdkLock) {
        PortsipLogger.d(COMPONENT, "ConnectionService hold for session $sessionId: $onHold")
        if (onHold) {
            portSipSdk?.hold(sessionId)
        } else {
            portSipSdk?.unHold(sessionId)
        }
    }

    /**
     * Called when the user toggles speaker from the system UI.
     * @param sessionId The session ID
     * @param enableSpeaker Whether to enable the speaker
     */
    fun performSpeakerAction(sessionId: Long, enableSpeaker: Boolean) = synchronized(sdkLock) {
        PortsipLogger.d(COMPONENT, "ConnectionService speaker for session $sessionId: $enableSpeaker")
        val audioDevice = if (enableSpeaker) {
            PortSipEnumDefine.AudioDevice.SPEAKER_PHONE
        } else {
            PortSipEnumDefine.AudioDevice.EARPIECE
        }
        portSipSdk?.setAudioDevice(audioDevice)
        PortsipConnectionService.updateSpeakerState(enableSpeaker)
    }

    /**
     * Called when the user sends DTMF from the system UI.
     * @param sessionId The session ID
     * @param digits The DTMF digits to send
     */
    fun performDTMFAction(sessionId: Long, digits: String) = synchronized(sdkLock) {
        PortsipLogger.d(COMPONENT, "ConnectionService DTMF for session $sessionId: $digits")
        for (digit in digits) {
            val dtmfCode = when (digit) {
                '0' -> 0
                '1' -> 1
                '2' -> 2
                '3' -> 3
                '4' -> 4
                '5' -> 5
                '6' -> 6
                '7' -> 7
                '8' -> 8
                '9' -> 9
                '*' -> 10
                '#' -> 11
                else -> continue
            }
            portSipSdk?.sendDtmf(sessionId, 0, dtmfCode, 160, true)
        }
    }

    // MARK: - OnPortSIPEvent Implementation

    // MARK: - Registration Events (Used)

    override fun onRegisterSuccess(statusText: String?, statusCode: Int, sipMessage: String?) {
        val eventData = mapOf(
            "statusText" to (statusText ?: ""),
            "statusCode" to statusCode,
            "sipMessage" to (sipMessage ?: "")
        )
        PortsipEventBridge.shared.sendEvent("onRegisterSuccess", eventData)
    }

    override fun onRegisterFailure(statusText: String?, statusCode: Int, sipMessage: String?) {
        val eventData = mapOf(
            "statusText" to (statusText ?: ""),
            "statusCode" to statusCode,
            "sipMessage" to (sipMessage ?: "")
        )
        PortsipEventBridge.shared.sendEvent("onRegisterFailure", eventData)
    }

    // MARK: - Call Events (Used)

    // Note: This plugin is designed for outgoing calls only.
    // Incoming call events are not forwarded to Flutter.
    override fun onInviteIncoming(
        sessionId: Long,
        callerDisplayName: String?,
        caller: String?,
        calleeDisplayName: String?,
        callee: String?,
        audioCodecNames: String?,
        videoCodecNames: String?,
        existsAudio: Boolean,
        existsVideo: Boolean,
        sipMessage: String?
    ) {
        // Not implemented - this plugin supports outgoing calls only
    }

    override fun onInviteTrying(sessionId: Long) {
        val eventData = mapOf("sessionId" to sessionId)
        PortsipEventBridge.shared.sendEvent("onInviteTrying", eventData)
    }

    override fun onInviteRinging(sessionId: Long, statusText: String?, statusCode: Int, sipMessage: String?) {
        val eventData = mapOf(
            "sessionId" to sessionId,
            "statusText" to (statusText ?: ""),
            "statusCode" to statusCode,
            "sipMessage" to (sipMessage ?: "")
        )
        PortsipEventBridge.shared.sendEvent("onInviteRinging", eventData)
    }

    override fun onInviteAnswered(
        sessionId: Long,
        callerDisplayName: String?,
        caller: String?,
        calleeDisplayName: String?,
        callee: String?,
        audioCodecNames: String?,
        videoCodecNames: String?,
        existsAudio: Boolean,
        existsVideo: Boolean,
        sipMessage: String?
    ) {
        val eventData = mapOf(
            "sessionId" to sessionId,
            "callerDisplayName" to (callerDisplayName ?: ""),
            "caller" to (caller ?: ""),
            "calleeDisplayName" to (calleeDisplayName ?: ""),
            "callee" to (callee ?: ""),
            "audioCodecs" to (audioCodecNames ?: ""),
            "videoCodecs" to (videoCodecNames ?: ""),
            "existsAudio" to existsAudio,
            "existsVideo" to existsVideo,
            "sipMessage" to (sipMessage ?: "")
        )
        PortsipEventBridge.shared.sendEvent("onInviteAnswered", eventData)
    }

    override fun onInviteFailure(
        sessionId: Long,
        callerDisplayName: String?,
        caller: String?,
        calleeDisplayName: String?,
        callee: String?,
        reason: String?,
        code: Int,
        sipMessage: String?
    ) {
        // Report call ended to ConnectionService with failure reason
        PortsipConnectionService.reportCallEnded(sessionId, android.telecom.DisconnectCause.ERROR)

        val eventData = mapOf(
            "sessionId" to sessionId,
            "callerDisplayName" to (callerDisplayName ?: ""),
            "caller" to (caller ?: ""),
            "calleeDisplayName" to (calleeDisplayName ?: ""),
            "callee" to (callee ?: ""),
            "reason" to (reason ?: ""),
            "code" to code,
            "sipMessage" to (sipMessage ?: "")
        )
        PortsipEventBridge.shared.sendEvent("onInviteFailure", eventData)
    }

    override fun onInviteConnected(sessionId: Long) {
        // Report call connected to ConnectionService
        PortsipConnectionService.reportCallConnected(sessionId)

        val eventData = mapOf("sessionId" to sessionId)
        PortsipEventBridge.shared.sendEvent("onInviteConnected", eventData)
    }

    override fun onInviteClosed(sessionId: Long, sipMessage: String?) {
        // Report call ended to ConnectionService
        PortsipConnectionService.reportCallEnded(sessionId)

        val eventData = mapOf(
            "sessionId" to sessionId,
            "sipMessage" to (sipMessage ?: "")
        )
        PortsipEventBridge.shared.sendEvent("onInviteClosed", eventData)
    }

    // MARK: - Remote Hold Events (Used)

    override fun onRemoteHold(sessionId: Long) {
        val eventData = mapOf("sessionId" to sessionId)
        PortsipEventBridge.shared.sendEvent("onRemoteHold", eventData)
    }

    override fun onRemoteUnHold(
        sessionId: Long,
        audioCodecNames: String?,
        videoCodecNames: String?,
        existsAudio: Boolean,
        existsVideo: Boolean
    ) {
        val eventData = mapOf(
            "sessionId" to sessionId,
            "audioCodecs" to (audioCodecNames ?: ""),
            "videoCodecs" to (videoCodecNames ?: ""),
            "existsAudio" to existsAudio,
            "existsVideo" to existsVideo
        )
        PortsipEventBridge.shared.sendEvent("onRemoteUnHold", eventData)
    }

    // MARK: - Unused Delegate Methods (Required by Interface - Empty Implementations)

    override fun onInviteSessionProgress(sessionId: Long, audioCodecNames: String?, videoCodecNames: String?, existsEarlyMedia: Boolean, existsAudio: Boolean, existsVideo: Boolean, sipMessage: String?) {}
    override fun onInviteUpdated(sessionId: Long, audioCodecs: String?, videoCodecs: String?, screenCodecs: String?, existsAudio: Boolean, existsVideo: Boolean, existsScreen: Boolean, sipMessage: String?) {}
    override fun onInviteBeginingForward(forwardTo: String?) {}
    override fun onDialogStateUpdated(BLFMonitoredUri: String?, BLFDialogState: String?, BLFDialogId: String?, BLFDialogDirection: String?) {}
    override fun onReceivedRefer(sessionId: Long, referId: Long, to: String?, from: String?, referSipMessage: String?) {}
    override fun onReferAccepted(sessionId: Long) {}
    override fun onReferRejected(sessionId: Long, reason: String?, code: Int) {}
    override fun onTransferTrying(sessionId: Long) {}
    override fun onTransferRinging(sessionId: Long) {}
    override fun onACTVTransferSuccess(sessionId: Long) {}
    override fun onACTVTransferFailure(sessionId: Long, reason: String?, code: Int) {}
    override fun onReceivedSignaling(sessionId: Long, message: String?) {}
    override fun onSendingSignaling(sessionId: Long, message: String?) {}
    override fun onWaitingVoiceMessage(messageAccount: String?, urgentNewMessageCount: Int, urgentOldMessageCount: Int, newMessageCount: Int, oldMessageCount: Int) {}
    override fun onWaitingFaxMessage(messageAccount: String?, urgentNewMessageCount: Int, urgentOldMessageCount: Int, newMessageCount: Int, oldMessageCount: Int) {}
    override fun onRecvDtmfTone(sessionId: Long, tone: Int) {}
    override fun onRecvOptions(optionsMessage: String?) {}
    override fun onRecvInfo(infoMessage: String?) {}
    override fun onRecvNotifyOfSubscription(subscribeId: Long, notifyMessage: String?, messageData: ByteArray?, messageDataLength: Int) {}
    override fun onPresenceRecvSubscribe(subscribeId: Long, fromDisplayName: String?, from: String?, subject: String?) {}
    override fun onPresenceOnline(fromDisplayName: String?, from: String?, stateText: String?) {}
    override fun onPresenceOffline(fromDisplayName: String?, from: String?) {}
    override fun onRecvMessage(sessionId: Long, mimeType: String?, subMimeType: String?, messageData: ByteArray?, messageDataLength: Int) {}
    override fun onRecvOutOfDialogMessage(fromDisplayName: String?, from: String?, toDisplayName: String?, to: String?, mimeType: String?, subMimeType: String?, messageData: ByteArray?, messageDataLength: Int, sipMessage: String?) {}
    override fun onSendMessageSuccess(sessionId: Long, messageId: Long, sipMessage: String?) {}
    override fun onSendMessageFailure(sessionId: Long, messageId: Long, reason: String?, code: Int, sipMessage: String?) {}
    override fun onSendOutOfDialogMessageSuccess(messageId: Long, fromDisplayName: String?, from: String?, toDisplayName: String?, to: String?, sipMessage: String?) {}
    override fun onSendOutOfDialogMessageFailure(messageId: Long, fromDisplayName: String?, from: String?, toDisplayName: String?, to: String?, reason: String?, code: Int, sipMessage: String?) {}
    override fun onSubscriptionFailure(subscribeId: Long, statusCode: Int) {}
    override fun onSubscriptionTerminated(subscribeId: Long) {}
    override fun onPlayFileFinished(sessionId: Long, fileName: String?) {}
    override fun onStatistics(sessionId: Long, stat: String?) {}
    override fun onAudioDeviceChanged(audioDevice: PortSipEnumDefine.AudioDevice?, deviceSet: MutableSet<PortSipEnumDefine.AudioDevice>?) {}
    override fun onAudioFocusChange(focusState: Int) {}
    override fun onRTPPacketCallback(sessionId: Long, mediaType: Int, direction: Int, rtpPacket: ByteArray?, packetSize: Int) {}
    override fun onAudioRawCallback(sessionId: Long, callbackType: Int, data: ByteArray?, dataLength: Int, samplingFreqHz: Int) {}
    override fun onVideoRawCallback(sessionId: Long, callbackType: Int, width: Int, height: Int, data: ByteArray?, dataLength: Int) {}

    // MARK: - Cleanup Methods

    /**
     * Disposes of all SDK resources.
     * This should be called when the plugin is being detached or when the app
     * needs to completely release all PortSIP resources.
     *
     * This method:
     * - Disposes ConnectionService
     * - Unregisters from the SIP server
     * - Uninitializes the SDK
     * - Clears the event listener
     * - Releases SDK instance and context references
     */
    fun dispose() = synchronized(sdkLock) {
        // Dispose ConnectionService
        context?.let { ctx ->
            PortsipConnectionService.dispose(ctx)
        }

        // Unregister and uninitialize SDK
        portSipSdk?.unRegisterServer(0)
        portSipSdk?.unInitialize()

        // Clear event listener
        portSipSdk?.setOnPortSIPEvent(null)

        // Release SDK instance
        portSipSdk = null

        // Clear context and activity references
        context = null
        activityRef = null

        PortsipLogger.d(COMPONENT, "PortsipController disposed")
    }
}
