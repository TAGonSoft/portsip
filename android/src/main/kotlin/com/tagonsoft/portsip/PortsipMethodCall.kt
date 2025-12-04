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
    
    /** Unregisters the SIP account from the SIP server */
    UNREGISTER("unRegister"),
    
    /** Initiates an outgoing call to a specified number or SIP URI */
    MAKE_CALL("makeCall"),
    
    /** Terminates an active call session */
    HANG_UP("hangUp"),
    
    /** Puts the current call session on hold */
    HOLD("hold"),
    
    /** Resumes a call session that was previously on hold */
    UNHOLD("unHold"),
    
    /** Mutes or unmutes the audio for the current call session */
    MUTE_SESSION("muteSession"),
    
    /** Enables or disables the loudspeaker for the current call */
    SET_LOUDSPEAKER_STATUS("setLoudspeakerStatus"),

    /** Sends DTMF tones during an active call */
    SEND_DTMF("sendDtmf"),

    /** Sets the PortSIP license key */
    SET_LICENSE_KEY("setLicenseKey"),

    /** Configures audio codecs for the SIP session */
    SET_AUDIO_CODECS("setAudioCodecs"),

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
