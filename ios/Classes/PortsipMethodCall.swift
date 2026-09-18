/// Enum representing all available method calls from Flutter to the native iOS PortSIP SDK.
/// Each case corresponds to a specific PortSIP SDK operation that can be invoked via the method channel.
enum PortsipMethodCall: String {
    /// Initializes the PortSIP SDK with the provided configuration parameters
    case initialize = "initialize"
    
    /// Registers the SIP account with the SIP server
    case register = "register"
    
    /// Registers with the SIP server (should be called after register)
    case registerServer = "registerServer"

    /// Refreshes the registration after a network change (WiFi/cellular handoff)
    case refreshRegistration = "refreshRegistration"

    /// Updates an active call session (re-INVITE) to renegotiate media
    case updateCall = "updateCall"

    /// Enables SIP session timers (RFC 4028) so dead legs are reaped at expiry
    case enableSessionTimer = "enableSessionTimer"

    /// Unregisters the SIP account from the SIP server (SDK stays initialized)
    case unRegister = "unRegister"
    
    /// Initiates an outgoing call to a specified number or SIP URI
    case makeCall = "makeCall"
    
    /// Terminates an active call session
    case hangUp = "hangUp"
    
    /// Puts the current call session on hold
    case hold = "hold"
    
    /// Resumes a call session that was previously on hold
    case unHold = "unHold"

    /// Swaps which of two calls is on hold (atomic CallKit mirror)
    case swapHold = "swapHold"

    /// Ends one leg and resumes another atomically (keeps CallKit's active call)
    case endCallAndResume = "endCallAndResume"

    /// Creates an audio conference bridge
    case createAudioConference = "createAudioConference"

    /// Joins a session into the existing conference
    case joinToConference = "joinToConference"

    /// Removes a session from the existing conference
    case removeFromConference = "removeFromConference"

    /// Destroys the existing conference bridge
    case destroyConference = "destroyConference"

    /// Groups sessions into one native conference call (CXSetGroupCallAction)
    case requestCallGroup = "requestCallGroup"

    /// Collapses a merged conference to a single system call (legacy)
    case reportConferenceMerged = "reportConferenceMerged"

    /// Updates the display name the system call UI shows for a session
    case updateOsCallDisplay = "updateOsCallDisplay"

    /// Mutes or unmutes the audio for the current call session
    case muteSession = "muteSession"
    
    /// Enables or disables the loudspeaker for the current call
    case setLoudspeakerStatus = "setLoudspeakerStatus"

    /// Sends DTMF tones during an active call
    case sendDtmf = "sendDtmf"

    /// Requests RTP media statistics for a session (result via onStatistics event)
    case getStatistics = "getStatistics"

    /// Enables/disables DSCP marking on the audio channel
    case enableAudioQos = "enableAudioQos"

    /// Enables/disables logging of sent and received SIP messages
    case enableCallbackSignaling = "enableCallbackSignaling"

    /// Starts recording the call on a session
    case startRecord = "startRecord"

    /// Stops the recording running on a session
    case stopRecord = "stopRecord"

    /// Plays a file into the stream sent to the remote party
    case startPlayingFileToRemote = "startPlayingFileToRemote"

    /// Stops the file playback running on a session
    case stopPlayingFileToRemote = "stopPlayingFileToRemote"

    /// Plays a file to the local user through the SDK audio engine
    case startPlayingFileLocally = "startPlayingFileLocally"

    /// Stops the local file playback
    case stopPlayingFileLocally = "stopPlayingFileLocally"

    /// Enables/disables early media 
    case enableEarlyMedia = "enableEarlyMedia"

    /// Counts RTP packets on a session (reported as onRtpPacket events)
    case enableRtpCallback = "enableRtpCallback"

    /// Starts a CallKit call for a callee without sending the INVITE
    case beginOutgoingCall = "beginOutgoingCall"

    /// Ends a pending CallKit call that was never dialed
    case cancelOutgoingCall = "cancelOutgoingCall"

    /// Ends the CallKit call held open after a SIP failure
    case endSystemCall = "endSystemCall"

    // MARK: - CallKit Methods
    
    /// Configures CallKit provider with app name and settings
    case configureCallKit = "configureCallKit"
    
    /// Enables or disables CallKit integration at runtime
    case enableCallKit = "enableCallKit"

    /// Sets the PortSIP license key
    case setLicenseKey = "setLicenseKey"

    /// Sets the RFC 5626 instance ID carried in the Contact header
    case setInstanceId = "setInstanceId"

    /// Removes the loaded account, freeing the core's single account slot
    case removeUser = "removeUser"

    /// Sets the SIP keep-alive interval
    case setKeepAliveTime = "setKeepAliveTime"

    /// Sends RTP keep-alive packets on established calls
    case setRtpKeepAlive = "setRtpKeepAlive"

    /// Sets the PRACK (RFC 3262) mode
    case setReliableProvisional = "setReliableProvisional"

    /// Configures audio codecs for the SIP session
    case setAudioCodecs = "setAudioCodecs"

    /// Sets the SDP fmtp parameter line for an audio codec
    case setAudioCodecParameter = "setAudioCodecParameter"

    /// Sets the encoder target bit rate for an audio codec
    case setAudioBitrate = "setAudioBitrate"

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

    /// Tears down the native SDK while keeping the plugin alive (runtime user swap)
    case unInitialize = "unInitialize"

    /// Disposes of all SDK resources and cleans up
    case dispose = "dispose"

    // MARK: - Android ConnectionService Methods (no-op on iOS)

    /// Configures Android ConnectionService (no-op on iOS, use configureCallKit instead)
    case configureConnectionService = "configureConnectionService"

    /// Enables or disables Android ConnectionService (no-op on iOS, use enableCallKit instead)
    case enableConnectionService = "enableConnectionService"
}
