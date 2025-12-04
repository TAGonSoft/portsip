/// Enum representing all available method calls from Flutter to the native iOS PortSIP SDK.
/// Each case corresponds to a specific PortSIP SDK operation that can be invoked via the method channel.
enum PortsipMethodCall: String {
    /// Initializes the PortSIP SDK with the provided configuration parameters
    case initialize = "initialize"
    
    /// Registers the SIP account with the SIP server
    case register = "register"
    
    /// Registers with the SIP server (should be called after register)
    case registerServer = "registerServer"
    
    /// Unregisters the SIP account from the SIP server
    case unRegister = "unRegister"
    
    /// Initiates an outgoing call to a specified number or SIP URI
    case makeCall = "makeCall"
    
    /// Terminates an active call session
    case hangUp = "hangUp"
    
    /// Puts the current call session on hold
    case hold = "hold"
    
    /// Resumes a call session that was previously on hold
    case unHold = "unHold"
    
    /// Mutes or unmutes the audio for the current call session
    case muteSession = "muteSession"
    
    /// Enables or disables the loudspeaker for the current call
    case setLoudspeakerStatus = "setLoudspeakerStatus"

    /// Sends DTMF tones during an active call
    case sendDtmf = "sendDtmf"
    
    // MARK: - CallKit Methods
    
    /// Configures CallKit provider with app name and settings
    case configureCallKit = "configureCallKit"
    
    /// Enables or disables CallKit integration at runtime
    case enableCallKit = "enableCallKit"

    /// Sets the PortSIP license key
    case setLicenseKey = "setLicenseKey"

    /// Configures audio codecs for the SIP session
    case setAudioCodecs = "setAudioCodecs"

    /// Enables or disables the audio manager (critical for DTMF)
    case enableAudioManager = "enableAudioManager"

    /// Sets the SRTP policy (0=None, 1=Prefer, 2=Force)
    case setSrtpPolicy = "setSrtpPolicy"

    /// Enables or disables 3GPP tags in SIP messages
    case enable3GppTags = "enable3GppTags"

    /// Enables or disables plugin debug logging
    case setLogsEnabled = "setLogsEnabled"

    /// Enables or disables Comfort Noise Generation (CNG)
    case enableCNG = "enableCNG"

    /// Enables or disables Voice Activity Detection (VAD)
    case enableVAD = "enableVAD"

    /// Disposes of all SDK resources and cleans up
    case dispose = "dispose"

    // MARK: - Android ConnectionService Methods (no-op on iOS)

    /// Configures Android ConnectionService (no-op on iOS, use configureCallKit instead)
    case configureConnectionService = "configureConnectionService"

    /// Enables or disables Android ConnectionService (no-op on iOS, use enableCallKit instead)
    case enableConnectionService = "enableConnectionService"
}
