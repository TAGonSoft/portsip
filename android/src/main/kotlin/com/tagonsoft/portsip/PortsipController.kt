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

    /** Writes the raw audio stream to disk — see startPcmRecord. */
    private val pcmRecorder = PortsipPcmRecorder()

    /** True while the SDK audio-conference bridge exists (createAudioConference →
     *  destroyConference). Telecom's one-active-call juggling must not reach the
     *  SDK then: SDK-holding a joined leg stops its media and starves the mixer. */
    @Volatile
    private var audioConferenceActive = false

    /** Weak reference to the current Activity for permission dialogs and UI operations */
    private var activityRef: WeakReference<Activity>? = null

    /// Lock object for synchronizing SDK operations
    private val sdkLock = Any()

    companion object {
        private const val COMPONENT = "Controller"

        /** Digest credential in an Authorization header, masked before logging. */
        private val credentialRegex = Regex("response=\"[^\"]*\"", RegexOption.IGNORE_CASE)

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
     * Refreshes the registration with the SIP server.
     * Call this when the device's network changes (e.g. WiFi to cellular
     * handoff) so the SDK re-registers over the new network interface and
     * updates any active call session.
     * @param arguments Map containing expires (0 keeps the previously
     * negotiated expiry and forces an immediate re-register)
     * @return 0 on success, error code otherwise
     */
    fun refreshRegistration(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val expires = (arguments["expires"] as? Int) ?: 0
        return portSipSdk?.refreshRegistration(expires) ?: -1
    }

    /**
     * Updates an active call session (sends a re-INVITE) to renegotiate the
     * media streams — e.g. after a network change to re-anchor media to the
     * new interface.
     * @param arguments Map containing sessionId, enableAudio (default true)
     * and enableVideo (default false)
     * @return 0 on success, error code otherwise
     */
    fun updateCall(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val enableAudio = (arguments["enableAudio"] as? Boolean) ?: true
        val enableVideo = (arguments["enableVideo"] as? Boolean) ?: false
        return portSipSdk?.updateCall(sessionId, enableAudio, enableVideo) ?: -1
    }

    /**
     * Enables SIP session timers (RFC 4028) for subsequent calls so the server
     * reaps a dead leg at expiry when the client stops refreshing.
     * @param arguments Map containing timerSeconds (minimum 90) and refreshMode
     * (0 = UAC/caller refreshes, 1 = UAS/callee)
     * @return 0 on success, error code otherwise
     */
    fun enableSessionTimer(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val timerSeconds = (arguments["timerSeconds"] as? Int) ?: 90
        val refreshMode = (arguments["refreshMode"] as? Int) ?: 0
        return portSipSdk?.enableSessionTimer(timerSeconds, refreshMode) ?: -1
    }

    /**
     * Unregisters the SIP account from the SIP server.
     *
     * The SDK remains initialized after this call, so the account can be
     * re-registered later (via register()/registerServer()) without going
     * through initialize() again. Use dispose() for a full teardown that
     * also releases the SDK and cleans up ConnectionService and references.
     */
    fun unRegister() = synchronized(sdkLock) {
        portSipSdk?.unRegisterServer(0)
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
        portSipSdk?.setSrtpPolicy(policy, false)
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
        // Additional conference legs pass false so the whole conference stays a
        // single system call (one ConnectionService connection).
        val reportToConnectionService =
            (arguments["reportToConnectionService"] as? Boolean) ?: true
        val displayName = arguments["displayName"] as? String
        // The number the system call UI shows; the SIP destination may be
        // formatted differently (see makeCall docs).
        val displayNumber = arguments["displayNumber"] as? String

        val sessionId = portSipSdk?.call(callee, sendSdp, videoCall) ?: -1L

        // Report outgoing call to ConnectionService (Android's CallKit equivalent)
        if (sessionId > 0 && reportToConnectionService && context != null) {
            PortsipConnectionService.reportOutgoingCall(
                context!!,
                sessionId,
                callee,
                videoCall,
                displayName,
                displayNumber
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
        // Additional conference legs pass false: they were never reported to the
        // ConnectionService (the whole conference is one system call), so don't
        // try to end a connection that isn't there.
        val reportToConnectionService =
            (arguments["reportToConnectionService"] as? Boolean) ?: true
        val result = portSipSdk?.hangUp(sessionId) ?: -1
        // The merged-conference primary's Connection is transferred to a
        // surviving leg instead of destroyed — the survivor has no Connection
        // of its own and would lose the call audio route. For non-conference
        // sessions this only prunes the tracking.
        val adoptedBy = PortsipConnectionService.transferSystemCallIfNeeded(sessionId)
        if (sessionId >= 0L && reportToConnectionService && adoptedBy == null) {
            PortsipConnectionService.reportCallEnded(
                sessionId, android.telecom.DisconnectCause.LOCAL
            )
        }
        return result
    }

    /**
     * Puts a call on hold.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun hold(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val result = portSipSdk?.hold(sessionId) ?: -1
        // Mirror the hold to ConnectionService so the system UI shows it as held
        // (and offers Swap when there's another call). No-ops for legs not
        // registered with the ConnectionService. setOnHold() does NOT re-enter
        // Connection.onHold(), so there's no echo to guard against here.
        if (result == 0) {
            PortsipConnectionService.reportCallHeld(sessionId, true)
            PortsipConnectionService.beginAudioReconfiguration()
        }
        return result
    }

    /**
     * Requests RTP statistics for a session. The SDK delivers the result
     * asynchronously via the onStatistics callback, which forwards it to Flutter.
     */
    fun getStatistics(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        return portSipSdk?.getStatistics(sessionId) ?: -1
    }

    /** Enables/disables QoS DSCP marking on the audio channel (46 when on, 0 when off). */
    fun enableAudioQos(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val enable = arguments["enable"] as? Boolean ?: false
        return portSipSdk?.enableAudioQos(enable) ?: -1
    }

    /**
     * Enables or disables the SDK's SIP message callbacks, which mirror sent
     * and received SIP messages into the plugin logs.
     * @param arguments Map containing sending and received flags
     * @return 0 on success, error code otherwise
     */
    fun enableCallbackSignaling(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sending = (arguments["sending"] as? Boolean) ?: false
        val received = (arguments["received"] as? Boolean) ?: false
        portSipSdk?.enableCallbackSignaling(sending, received)
        PortsipLogger.d(COMPONENT, "Signaling callbacks: sending=$sending received=$received")
        return 0
    }

    /**
     * Starts recording a session to a file.
     *
     * Recording is per session: the SDK has no conference-level recorder, so a
     * conference is recorded by starting one recording per leg.
     *
     * @param arguments Map containing sessionId, recordFilePath, recordFileName,
     * appendTimeStamp, audioChannels, fileFormat, audioRecordMode, videoRecordMode
     * @return 0 on success, error code otherwise
     */
    fun startRecord(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val recordFilePath = arguments["recordFilePath"] as? String ?: return -1
        val recordFileName = arguments["recordFileName"] as? String ?: return -1
        val appendTimeStamp = arguments["appendTimeStamp"] as? Boolean ?: false
        val audioChannels = (arguments["audioChannels"] as? Number)?.toInt() ?: 1
        val fileFormat = (arguments["fileFormat"] as? Number)?.toInt() ?: 1
        val audioRecordMode = (arguments["audioRecordMode"] as? Number)?.toInt() ?: 3
        val videoRecordMode = (arguments["videoRecordMode"] as? Number)?.toInt() ?: 0
        return portSipSdk?.startRecord(
            sessionId,
            recordFilePath,
            recordFileName,
            appendTimeStamp,
            audioChannels,
            fileFormat,
            audioRecordMode,
            videoRecordMode
        ) ?: -1
    }

    /**
     * Stops the recording running on a session.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun stopRecord(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        return portSipSdk?.stopRecord(sessionId) ?: -1
    }

    /**
     * Starts writing a session's raw audio stream to WAVE files — one per
     * callback type the stream reports.
     *
     * Independent of [startRecord]: this takes the PCM the SDK hands to the
     * audio stream callback and writes it verbatim, so the file holds the
     * stream as delivered rather than as the SDK's own recorder re-encodes it.
     *
     * @param arguments Map containing sessionId, recordFilePath, recordFileName
     * @return 0 on success, error code otherwise
     */
    fun startPcmRecord(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: return -1
        val recordFilePath = arguments["recordFilePath"] as? String ?: return -1
        val recordFileName = arguments["recordFileName"] as? String ?: return -1
        // Before the recorder starts: bailing out afterwards would leave a
        // session the next startPcmRecord takes for one already running.
        val sdk = portSipSdk ?: return -1
        if (!pcmRecorder.start(sessionId, recordFilePath, recordFileName)) return -1
        // Returns void — the SDK reports nothing here, not even for an unknown
        // session, so 0 only means the recorder is ready and the request went
        // in. Whether audio arrived is answered by stopPcmRecord's null.
        sdk.enableAudioStreamCallback(
            sessionId,
            true,
            PortSipEnumDefine.ENUM_DIRECTION_SEND_RECV
        )
        return 0
    }

    /**
     * Stops the raw-audio recording and finalises its files, handing the
     * finished recording's path to [completion] — or null if nothing was
     * captured.
     *
     * [completion] runs on the recorder's own thread once the merge is done:
     * combining a long call rewrites every byte it holds, which must not run on
     * the platform thread or under [sdkLock]. With nothing to merge it runs
     * inline instead, so it must not assume either thread.
     *
     * @param arguments Map containing sessionId
     */
    fun stopPcmRecord(arguments: Map<String, Any?>, completion: (String?) -> Unit) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong()
        if (sessionId == null) {
            completion(null)
            return
        }
        synchronized(sdkLock) {
            portSipSdk?.enableAudioStreamCallback(
                sessionId,
                false,
                PortSipEnumDefine.ENUM_DIRECTION_NONE
            )
        }
        pcmRecorder.stop(sessionId, completion)
    }

    /**
     * Plays a file into the stream sent to the remote party.
     *
     * @param arguments Map containing sessionId, fileUrl, loop, playAudio
     * (0 = don't play file audio, 1 = file audio only, 2 = file audio mixed
     * with the microphone)
     * @return 0 on success, error code otherwise
     */
    fun startPlayingFileToRemote(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val fileUrl = arguments["fileUrl"] as? String ?: return -1
        val loop = arguments["loop"] as? Boolean ?: false
        val playAudio = (arguments["playAudio"] as? Number)?.toInt() ?: 2
        return portSipSdk?.startPlayingFileToRemote(
            sessionId,
            fileUrl,
            loop,
            playAudio
        ) ?: -1
    }

    /**
     * Stops the file playback running on a session.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun stopPlayingFileToRemote(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        return portSipSdk?.stopPlayingFileToRemote(sessionId) ?: -1
    }

    /**
     * Resumes a call that was on hold.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun unHold(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val result = portSipSdk?.unHold(sessionId) ?: -1
        // Mirror the resume to ConnectionService (see hold()).
        if (result == 0) {
            PortsipConnectionService.reportCallHeld(sessionId, false)
            PortsipConnectionService.beginAudioReconfiguration()
        }
        return result
    }

    /**
     * Swaps which of two calls is on hold: SDK-holds one leg, SDK-resumes the
     * other, and mirrors both to the ConnectionService. One channel call for
     * cross-platform parity with iOS, where the CallKit mirror must be a
     * single atomic transaction.
     * @param arguments Map containing holdSessionId and unholdSessionId
     * @return 0 on success, first failing SDK error code otherwise
     */
    fun swapHold(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val holdSessionId = (arguments["holdSessionId"] as? Number)?.toLong() ?: -1L
        val unholdSessionId = (arguments["unholdSessionId"] as? Number)?.toLong() ?: -1L
        val sdk = portSipSdk ?: return -1
        val unholdResult = sdk.unHold(unholdSessionId)
        val holdResult = sdk.hold(holdSessionId)
        val result = if (unholdResult != 0) unholdResult else holdResult
        if (result == 0) {
            PortsipConnectionService.reportCallHeld(holdSessionId, true)
            PortsipConnectionService.reportCallHeld(unholdSessionId, false)
            PortsipConnectionService.beginAudioReconfiguration()
        }
        return result
    }

    /**
     * Ends one leg and resumes another. The ended leg's Connection is destroyed
     * — left alive it's a phantom call whose dead Connection can swallow
     * audio-route changes. The reconfiguration window preserves the user's
     * route across the resume (see beginAudioReconfiguration).
     */
    fun endCallAndResume(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val endSessionId = (arguments["endSessionId"] as? Number)?.toLong() ?: -1L
        val resumeSessionId = (arguments["resumeSessionId"] as? Number)?.toLong() ?: -1L
        val sdk = portSipSdk ?: return -1
        sdk.hangUp(endSessionId)
        val adoptedBy = PortsipConnectionService.transferSystemCallIfNeeded(endSessionId)
        if (adoptedBy == null) {
            PortsipConnectionService.reportCallEnded(
                endSessionId, android.telecom.DisconnectCause.LOCAL
            )
        }
        val unholdResult = sdk.unHold(resumeSessionId)
        if (unholdResult == 0) {
            PortsipConnectionService.reportCallHeld(resumeSessionId, false)
        }
        PortsipConnectionService.beginAudioReconfiguration()
        return 0
    }

    /**
     * Groups sessions into one conference. Telecom has no CXSetGroupCallAction
     * equivalent, so this re-emits onCallKitMerge (sessionId, otherSessionId) and
     * lets the Dart layer build the SDK audio conference — the same convergence
     * point used on iOS, keeping the cross-platform flow identical.
     * @param arguments Map containing sessionIds
     * @return 0 on submit, -1 if fewer than two sessions
     */
    fun requestCallGroup(arguments: Map<String, Any?>): Int {
        val ids = (arguments["sessionIds"] as? List<*>)
            ?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList()
        if (ids.size < 2) return -1
        PortsipEventBridge.shared.sendEvent(
            "onCallKitMerge",
            mapOf(
                PortsipConstants.EventKeys.SESSION_ID to ids[1],
                "otherSessionId" to ids[0],
            )
        )
        return 0
    }

    /**
     * Collapses a merged conference to a single system call by ending the
     * ConnectionService connections for the merged-away legs (their SIP sessions
     * stay live in the SDK conference bridge). Legacy — superseded by
     * requestCallGroup; kept for API compatibility.
     * @param arguments Map containing primarySessionId and mergedAwaySessionIds
     * @return 0
     */
    fun reportConferenceMerged(arguments: Map<String, Any?>): Int {
        val mergedAway = (arguments["mergedAwaySessionIds"] as? List<*>)
            ?.mapNotNull { (it as? Number)?.toLong() } ?: emptyList()
        val primary = (arguments["primarySessionId"] as? Number)?.toLong() ?: -1L
        PortsipConnectionService.reportConferenceMerged(primary, mergedAway)
        return 0
    }

    /**
     * Updates the display name the system call UI shows for a session — used
     * after a merged conference collapses and the surviving leg adopted the
     * system call (see PortsipConnectionService.transferSystemCallIfNeeded).
     * @param arguments Map containing sessionId and displayName
     * @return 0
     */
    fun updateOsCallDisplay(arguments: Map<String, Any?>): Int {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val displayName = (arguments["displayName"] as? String) ?: ""
        PortsipConnectionService.updateCallDisplay(sessionId, displayName)
        return 0
    }

    /**
     * Creates an audio conference bridge. Sessions joined via [joinToConference]
     * are mixed together so all participants hear each other.
     * @return conference id (>= 0) on success, error code otherwise
     */
    fun createAudioConference(): Int = synchronized(sdkLock) {
        val rc = portSipSdk?.createAudioConference() ?: -1
        if (rc >= 0) audioConferenceActive = true
        return rc
    }

    /**
     * Joins a session into the existing conference.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun joinToConference(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        val result = portSipSdk?.joinToConference(sessionId) ?: -1
        // Building the conference renegotiates audio and drops the route to the
        // earpiece — open the window so the loudspeaker is re-asserted, not lost.
        if (result == 0) PortsipConnectionService.beginAudioReconfiguration()
        return result
    }

    /**
     * Removes a session from the existing conference.
     * @param arguments Map containing sessionId
     * @return 0 on success, error code otherwise
     */
    fun removeFromConference(arguments: Map<String, Any?>): Int = synchronized(sdkLock) {
        val sessionId = (arguments["sessionId"] as? Number)?.toLong() ?: -1L
        return portSipSdk?.removeFromConference(sessionId) ?: -1
    }

    /**
     * Destroys the existing conference bridge. The SDK call returns void, so we
     * report success (0) once it's been invoked, or -1 if the SDK is gone.
     * @return 0 on success, -1 if the SDK is not initialized
     */
    fun destroyConference(): Int = synchronized(sdkLock) {
        audioConferenceActive = false
        val sdk = portSipSdk ?: return -1
        sdk.destroyConference()
        // No bridge → no merged conference; a later session end must not try to
        // transfer the Connection to a leg that's no longer conferenced.
        PortsipConnectionService.clearConferenceTracking()
        return 0
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
    fun setLoudspeakerStatus(arguments: Map<String, Any?>) {
        val enable = (arguments["enable"] as? Boolean) ?: false
        val route = if (enable) {
            PortsipConnectionService.ROUTE_SPEAKER
        } else {
            PortsipConnectionService.ROUTE_EARPIECE
        }
        // Telecom owns the route — drive it there (single owner). Only fall back to
        // the SDK device switch when there's no system call to route through; still
        // record the intent so the route is asserted once a Connection appears.
        if (!PortsipConnectionService.applyAudioRoute(route)) {
            PortsipConnectionService.setDesiredRoute(route)
            synchronized(sdkLock) {
                portSipSdk?.setAudioDevice(
                    if (enable) PortSipEnumDefine.AudioDevice.SPEAKER_PHONE
                    else PortSipEnumDefine.AudioDevice.EARPIECE
                )
            }
        }
        PortsipLogger.d(COMPONENT, "Loudspeaker ${if (enable) "enabled" else "disabled"}")
    }

    /**
     * Routes the active call's audio to a specific output through Telecom.
     * @param arguments Map containing kind: builtInReceiver | builtInSpeaker |
     *   bluetooth | headphones
     */
    fun setAudioRoute(arguments: Map<String, Any?>) {
        val kind = (arguments["kind"] as? String) ?: "builtInReceiver"
        val route = when (kind) {
            "builtInSpeaker" -> PortsipConnectionService.ROUTE_SPEAKER
            "bluetooth" -> PortsipConnectionService.ROUTE_BLUETOOTH
            "headphones", "carAudio" -> PortsipConnectionService.ROUTE_WIRED_HEADSET
            else -> PortsipConnectionService.ROUTE_EARPIECE
        }
        // Telecom owns the route; without a system call to route through, fall
        // back to the SDK device switch (mirrors setLoudspeakerStatus) and keep
        // the intent so the route is asserted once a Connection appears.
        if (!PortsipConnectionService.applyAudioRoute(route)) {
            PortsipConnectionService.setDesiredRoute(route)
            synchronized(sdkLock) {
                portSipSdk?.setAudioDevice(
                    when (route) {
                        PortsipConnectionService.ROUTE_SPEAKER ->
                            PortSipEnumDefine.AudioDevice.SPEAKER_PHONE
                        PortsipConnectionService.ROUTE_BLUETOOTH ->
                            PortSipEnumDefine.AudioDevice.BLUETOOTH
                        PortsipConnectionService.ROUTE_WIRED_HEADSET ->
                            PortSipEnumDefine.AudioDevice.WIRED_HEADSET
                        else -> PortSipEnumDefine.AudioDevice.EARPIECE
                    }
                )
            }
        }
        PortsipLogger.d(COMPONENT, "setAudioRoute($kind -> $route)")
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
    fun handleConnectionServiceHold(sessionId: Long, onHold: Boolean) {
        synchronized(sdkLock) {
            PortsipLogger.d(COMPONENT, "ConnectionService hold for session $sessionId: $onHold")
            // While the conference is up, Telecom's one-active-call juggling must
            // stay Connection-state only: an SDK hold turns a joined leg sendonly
            // and starves the mixer.
            if (audioConferenceActive) {
                PortsipLogger.d(COMPONENT, "conference active — not forwarding hold to SDK")
                return
            }
            if (onHold) {
                portSipSdk?.hold(sessionId)
            } else {
                portSipSdk?.unHold(sessionId)
            }
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
        // A call that never connected can still have been recording (see
        // onInviteClosed).
        pcmRecorder.finish(sessionId)

        // A merged-conference primary's Connection is transferred to a
        // surviving leg instead of ended (see transferSystemCallIfNeeded).
        if (PortsipConnectionService.transferSystemCallIfNeeded(sessionId) == null) {
            PortsipConnectionService.reportCallEnded(sessionId, android.telecom.DisconnectCause.ERROR)
        }

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
        // A newly connected leg negotiates media and the SDK drops the route to
        // the earpiece — open the window so the loudspeaker is re-asserted (adding
        // a call rings longer than a swap, so this is its own trigger).
        PortsipConnectionService.beginAudioReconfiguration()

        val eventData = mapOf("sessionId" to sessionId)
        PortsipEventBridge.shared.sendEvent("onInviteConnected", eventData)
    }

    override fun onInviteClosed(sessionId: Long, sipMessage: String?) {
        // Releases the part-file handles an app that never calls stopPcmRecord
        // would otherwise hold for the life of the process. The recording stays
        // collectable: an app stopping from its own call-ended handler gets
        // here first.
        pcmRecorder.finish(sessionId)

        // A merged-conference primary's Connection is transferred to a
        // surviving leg instead of ended (see transferSystemCallIfNeeded).
        if (PortsipConnectionService.transferSystemCallIfNeeded(sessionId) == null) {
            PortsipConnectionService.reportCallEnded(sessionId)
        }

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

    // MARK: - SIP Signaling

    // Off unless the host calls enableCallbackSignaling. The SDK hands over a
    // copy of the message, so these callbacks cannot affect what is on the wire.

    override fun onReceivedSignaling(sessionId: Long, message: String?) {
        PortsipLogger.d("Signaling", "◀ RECV (session $sessionId)\n${redactCredentials(message)}")
    }

    override fun onSendingSignaling(sessionId: Long, message: String?) {
        PortsipLogger.d("Signaling", "▶ SEND (session $sessionId)\n${redactCredentials(message)}")
    }

    /**
     * Masks the digest `response="..."` in Authorization headers. The hash is
     * replayable until the nonce expires, and the rest of the header (realm,
     * nonce, username, algorithm) is what makes auth failures diagnosable.
     */
    private fun redactCredentials(message: String?): String =
        message?.replace(credentialRegex, "response=\"<redacted>\"") ?: ""

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
    override fun onStatistics(sessionId: Long, stat: String?) {
        val eventData = mapOf(
            "sessionId" to sessionId,
            "stat" to (stat ?: "")
        )
        PortsipEventBridge.shared.sendEvent("onStatistics", eventData)
    }
    override fun onAudioDeviceChanged(audioDevice: PortSipEnumDefine.AudioDevice?, deviceSet: MutableSet<PortSipEnumDefine.AudioDevice>?) {}
    override fun onAudioFocusChange(focusState: Int) {}
    override fun onRTPPacketCallback(sessionId: Long, mediaType: Int, direction: Int, rtpPacket: ByteArray?, packetSize: Int) {}
    override fun onAudioRawCallback(sessionId: Long, callbackType: Int, data: ByteArray?, dataLength: Int, samplingFreqHz: Int) {
        if (data == null) return
        pcmRecorder.write(sessionId, callbackType, data, dataLength, samplingFreqHz)
    }
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
        audioConferenceActive = false
        // This controller is a singleton and outlives the engine, so an
        // unclosed part-file handle would too.
        pcmRecorder.clear()

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

    /**
     * Tears down the native PortSIP SDK so a different SIP user can be
     * loaded via initialize() + register() again, without shutting the
     * plugin down. Used for runtime user swap (e.g. switching phone number).
     *
     * Unlike dispose(), this does NOT tear down ConnectionService or release
     * the context/activity references — those are app-lifetime concerns.
     */
    fun unInitialize() = synchronized(sdkLock) {
        audioConferenceActive = false
        // The sessions any open parts belong to are going away with the SDK.
        pcmRecorder.clear()
        portSipSdk?.unRegisterServer(0)
        portSipSdk?.unInitialize()
        portSipSdk?.setOnPortSIPEvent(null)
        portSipSdk = null

        PortsipLogger.d(COMPONENT, "PortsipController unInitialized")
    }
}
