package com.tagonsoft.portsip

/**
 * Enum representing all available method calls from Flutter to the native Android PortSIP SDK.
 * Each case corresponds to a specific PortSIP SDK operation that can be invoked via the method channel.
 */
enum class PortsipMethodCall(val methodName: String) {
    /** Initializes the PortSIP SDK with the provided configuration parameters */
    INITIALIZE("initialize"),
    
    /** Registers the SIP account with the SIP server */
    REGISTER("register"),
    
    /** Registers with the SIP server (should be called after register) */
    REGISTER_SERVER("registerServer"),

    /** Refreshes the registration after a network change (WiFi/cellular handoff) */
    REFRESH_REGISTRATION("refreshRegistration"),

    /** Updates an active call session (re-INVITE) to renegotiate media */
    UPDATE_CALL("updateCall"),

    /** Enables SIP session timers (RFC 4028) so dead legs are reaped at expiry */
    ENABLE_SESSION_TIMER("enableSessionTimer"),

    /** Unregisters the SIP account from the SIP server (SDK stays initialized) */
    UNREGISTER("unRegister"),
    
    /** Initiates an outgoing call to a specified number or SIP URI */
    MAKE_CALL("makeCall"),
    
    /** Terminates an active call session */
    HANG_UP("hangUp"),
    
    /** Puts the current call session on hold */
    HOLD("hold"),
    
    /** Resumes a call session that was previously on hold */
    UNHOLD("unHold"),

    /** Swaps which of two calls is on hold */
    SWAP_HOLD("swapHold"),

    /** Ends one leg and resumes another atomically */
    END_CALL_AND_RESUME("endCallAndResume"),

    /** Groups sessions into one native conference call */
    REQUEST_CALL_GROUP("requestCallGroup"),

    /** Creates an audio conference bridge */
    CREATE_AUDIO_CONFERENCE("createAudioConference"),

    /** Joins a session into the existing conference */
    JOIN_TO_CONFERENCE("joinToConference"),

    /** Removes a session from the existing conference */
    REMOVE_FROM_CONFERENCE("removeFromConference"),

    /** Destroys the existing conference bridge */
    DESTROY_CONFERENCE("destroyConference"),

    /** Collapses a merged conference to a single system call */
    REPORT_CONFERENCE_MERGED("reportConferenceMerged"),

    /** Updates the display name the system call UI shows for a session */
    UPDATE_OS_CALL_DISPLAY("updateOsCallDisplay"),

    /** Mutes or unmutes the audio for the current call session */
    MUTE_SESSION("muteSession"),
    
    /** Enables or disables the loudspeaker for the current call */
    SET_LOUDSPEAKER_STATUS("setLoudspeakerStatus"),

    /** Routes the current call's audio to a specific output (Telecom-owned) */
    SET_AUDIO_ROUTE("setAudioRoute"),

    /** Sends DTMF tones during an active call */
    SEND_DTMF("sendDtmf"),

    /** Requests RTP media statistics for a session (result via onStatistics event) */
    GET_STATISTICS("getStatistics"),
    ENABLE_AUDIO_QOS("enableAudioQos"),

    /** Enables/disables logging of sent and received SIP messages */
    ENABLE_CALLBACK_SIGNALING("enableCallbackSignaling"),

    /** Starts recording the call on a session */
    START_RECORD("startRecord"),

    /** Stops the recording running on a session */
    STOP_RECORD("stopRecord"),

    /** Starts writing a session's raw audio stream to a WAVE file */
    START_PCM_RECORD("startPcmRecord"),

    /** Stops the raw-audio recording on a session and finalises its file */
    STOP_PCM_RECORD("stopPcmRecord"),

    /** Plays a file into the stream sent to the remote party */
    START_PLAYING_FILE_TO_REMOTE("startPlayingFileToRemote"),

    /** Stops the file playback running on a session */
    STOP_PLAYING_FILE_TO_REMOTE("stopPlayingFileToRemote"),

    /** Plays a file to the local user through the SDK audio engine */
    START_PLAYING_FILE_LOCALLY("startPlayingFileLocally"),

    /** Stops the local file playback */
    STOP_PLAYING_FILE_LOCALLY("stopPlayingFileLocally"),

    /** Enables/disables early media */
    ENABLE_EARLY_MEDIA("enableEarlyMedia"),

    /** Counts RTP packets on a session (reported as onRtpPacket events) */
    ENABLE_RTP_CALLBACK("enableRtpCallback"),

    /** Starts a Telecom call for a callee without sending the INVITE */
    BEGIN_OUTGOING_CALL("beginOutgoingCall"),

    /** Ends a pending Telecom call that was never dialed */
    CANCEL_OUTGOING_CALL("cancelOutgoingCall"),

    /** Ends the Telecom call held open after a SIP failure */
    END_SYSTEM_CALL("endSystemCall"),

    /** Sets the PortSIP license key */
    SET_LICENSE_KEY("setLicenseKey"),

    /** Sets the RFC 5626 instance ID carried in the Contact header */
    SET_INSTANCE_ID("setInstanceId"),

    /** Removes the loaded account, freeing the core's single account slot */
    REMOVE_USER("removeUser"),

    /** Sets the SIP keep-alive interval */
    SET_KEEP_ALIVE_TIME("setKeepAliveTime"),

    /** Sends RTP keep-alive packets on established calls */
    SET_RTP_KEEP_ALIVE("setRtpKeepAlive"),

    /** Sets the PRACK (RFC 3262) mode */
    SET_RELIABLE_PROVISIONAL("setReliableProvisional"),

    /** Configures audio codecs for the SIP session */
    SET_AUDIO_CODECS("setAudioCodecs"),

    /** Sets the SDP fmtp parameter line for an audio codec */
    SET_AUDIO_CODEC_PARAMETER("setAudioCodecParameter"),

    /** Sets the encoder target bit rate for an audio codec */
    SET_AUDIO_BITRATE("setAudioBitrate"),

    /** Enables or disables the audio manager (critical for DTMF) */
    ENABLE_AUDIO_MANAGER("enableAudioManager"),

    /** Sets the SRTP policy (0=None, 1=Prefer, 2=Force) */
    SET_SRTP_POLICY("setSrtpPolicy"),

    /** Enables or disables 3GPP tags in SIP messages */
    ENABLE_3GPP_TAGS("enable3GppTags"),

    /** Enables or disables plugin debug logging */
    SET_LOGS_ENABLED("setLogsEnabled"),

    /** Enables or disables Acoustic Echo Cancellation (AEC) */
    ENABLE_AEC("enableAEC"),

    /** Enables or disables Automatic Gain Control (AGC) */
    ENABLE_AGC("enableAGC"),

    /** Enables or disables Comfort Noise Generation (CNG) */
    ENABLE_CNG("enableCNG"),

    /** Enables or disables Voice Activity Detection (VAD) */
    ENABLE_VAD("enableVAD"),

    /** Enables or disables Automatic Noise Suppression (ANS) */
    ENABLE_ANS("enableANS"),

    /** Tears down the native SDK while keeping the plugin alive (runtime user swap) */
    UN_INITIALIZE("unInitialize"),

    /** Disposes of all SDK resources and cleans up */
    DISPOSE("dispose"),

    // ConnectionService methods (Android equivalent to iOS CallKit)

    /** Configures ConnectionService with app name and settings */
    CONFIGURE_CONNECTION_SERVICE("configureConnectionService"),

    /** Enables or disables ConnectionService at runtime */
    ENABLE_CONNECTION_SERVICE("enableConnectionService");

    companion object {
        /**
         * Finds a PortsipMethodCall by its method name string.
         * @param methodName The method name to look up
         * @return The matching PortsipMethodCall or null if not found
         */
        fun fromMethodName(methodName: String): PortsipMethodCall? {
            return values().find { it.methodName == methodName }
        }
    }
}
