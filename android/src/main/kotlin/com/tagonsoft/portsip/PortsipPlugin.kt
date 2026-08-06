package com.tagonsoft.portsip

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin for PortSIP VoIP SDK integration on Android.
 *
 * This class serves as the main entry point for the PortSIP Flutter plugin on Android.
 * It handles method calls from Flutter and routes them to the PortsipController,
 * which manages the actual PortSIP SDK operations. The plugin supports SIP registration,
 * outgoing call management (make, hang up), and call controls (hold, mute, DTMF).
 *
 * Implements ActivityAware to properly handle activity lifecycle and permission dialogs.
 */
class PortsipPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel

    /**
     * Returns a result produced off the platform thread back onto it. Built on
     * first use: constructing the plugin must not reach for a Looper, which a
     * JVM unit test has no way to provide.
     */
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    companion object {
        private const val COMPONENT = "Plugin"
    }
    
    /**
     * Called when the plugin is attached to the Flutter engine.
     * Sets up the method channel for bidirectional communication between Flutter and native Android code.
     */
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "portsip")
        channel.setMethodCallHandler(this)
        
        // Set up event bridge and controller
        PortsipEventBridge.shared.setChannel(channel)
        PortsipController.shared.setContext(flutterPluginBinding.applicationContext)

        PortsipLogger.d(COMPONENT, "📱 Plugin attached to engine")
    }
    
    /**
     * Handles incoming method calls from Flutter.
     * Routes method calls to the appropriate PortsipController methods based on the method name.
     */
    override fun onMethodCall(call: MethodCall, result: Result) {
        val method = PortsipMethodCall.fromMethodName(call.method)
        
        if (method == null) {
            result.notImplemented()
            return
        }
        
        try {
            when (method) {
                PortsipMethodCall.INITIALIZE -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "initialize", arguments)
                    val resultValue = PortsipController.shared.initialize(arguments)
                    PortsipLogger.logResponse(COMPONENT, "initialize", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.REGISTER -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "register", arguments)
                    val resultValue = PortsipController.shared.register(arguments)
                    PortsipLogger.logResponse(COMPONENT, "register", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.REGISTER_SERVER -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "registerServer", arguments)
                    val resultValue = PortsipController.shared.registerServer(arguments)
                    PortsipLogger.logResponse(COMPONENT, "registerServer", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.REFRESH_REGISTRATION -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "refreshRegistration", arguments)
                    val resultValue = PortsipController.shared.refreshRegistration(arguments)
                    PortsipLogger.logResponse(COMPONENT, "refreshRegistration", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.UPDATE_CALL -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "updateCall", arguments)
                    val resultValue = PortsipController.shared.updateCall(arguments)
                    PortsipLogger.logResponse(COMPONENT, "updateCall", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.ENABLE_SESSION_TIMER -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enableSessionTimer", arguments)
                    val resultValue = PortsipController.shared.enableSessionTimer(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enableSessionTimer", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.UNREGISTER -> {
                    PortsipLogger.logCall(COMPONENT, "unRegister")
                    PortsipController.shared.unRegister()
                    PortsipLogger.logResponse(COMPONENT, "unRegister", "done")
                    result.success(null)
                }

                PortsipMethodCall.MAKE_CALL -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "makeCall", arguments)
                    val sessionId = PortsipController.shared.makeCall(arguments)
                    PortsipLogger.logResponse(COMPONENT, "makeCall", sessionId)
                    result.success(sessionId)
                }

                PortsipMethodCall.HANG_UP -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "hangUp", arguments)
                    val resultValue = PortsipController.shared.hangUp(arguments)
                    PortsipLogger.logResponse(COMPONENT, "hangUp", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.HOLD -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "hold", arguments)
                    val resultValue = PortsipController.shared.hold(arguments)
                    PortsipLogger.logResponse(COMPONENT, "hold", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.UNHOLD -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "unHold", arguments)
                    val resultValue = PortsipController.shared.unHold(arguments)
                    PortsipLogger.logResponse(COMPONENT, "unHold", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.SWAP_HOLD -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "swapHold", arguments)
                    val resultValue = PortsipController.shared.swapHold(arguments)
                    PortsipLogger.logResponse(COMPONENT, "swapHold", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.END_CALL_AND_RESUME -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "endCallAndResume", arguments)
                    val resultValue = PortsipController.shared.endCallAndResume(arguments)
                    PortsipLogger.logResponse(COMPONENT, "endCallAndResume", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.REQUEST_CALL_GROUP -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "requestCallGroup", arguments)
                    val resultValue = PortsipController.shared.requestCallGroup(arguments)
                    PortsipLogger.logResponse(COMPONENT, "requestCallGroup", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.CREATE_AUDIO_CONFERENCE -> {
                    PortsipLogger.logCall(COMPONENT, "createAudioConference")
                    val resultValue = PortsipController.shared.createAudioConference()
                    PortsipLogger.logResponse(COMPONENT, "createAudioConference", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.JOIN_TO_CONFERENCE -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "joinToConference", arguments)
                    val resultValue = PortsipController.shared.joinToConference(arguments)
                    PortsipLogger.logResponse(COMPONENT, "joinToConference", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.REMOVE_FROM_CONFERENCE -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "removeFromConference", arguments)
                    val resultValue = PortsipController.shared.removeFromConference(arguments)
                    PortsipLogger.logResponse(COMPONENT, "removeFromConference", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.DESTROY_CONFERENCE -> {
                    PortsipLogger.logCall(COMPONENT, "destroyConference")
                    val resultValue = PortsipController.shared.destroyConference()
                    PortsipLogger.logResponse(COMPONENT, "destroyConference", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.REPORT_CONFERENCE_MERGED -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "reportConferenceMerged", arguments)
                    val resultValue = PortsipController.shared.reportConferenceMerged(arguments)
                    PortsipLogger.logResponse(COMPONENT, "reportConferenceMerged", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.UPDATE_OS_CALL_DISPLAY -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "updateOsCallDisplay", arguments)
                    val resultValue = PortsipController.shared.updateOsCallDisplay(arguments)
                    PortsipLogger.logResponse(COMPONENT, "updateOsCallDisplay", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.MUTE_SESSION -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "muteSession", arguments)
                    val resultValue = PortsipController.shared.muteSession(arguments)
                    PortsipLogger.logResponse(COMPONENT, "muteSession", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.SET_LOUDSPEAKER_STATUS -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "setLoudspeakerStatus", arguments)
                    PortsipController.shared.setLoudspeakerStatus(arguments)
                    PortsipLogger.logResponse(COMPONENT, "setLoudspeakerStatus", "done")
                    result.success(null)
                }

                PortsipMethodCall.SET_AUDIO_ROUTE -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "setAudioRoute", arguments)
                    PortsipController.shared.setAudioRoute(arguments)
                    PortsipLogger.logResponse(COMPONENT, "setAudioRoute", "done")
                    result.success(null)
                }

                PortsipMethodCall.SEND_DTMF -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "sendDtmf", arguments)
                    val resultValue = PortsipController.shared.sendDtmf(arguments)
                    PortsipLogger.logResponse(COMPONENT, "sendDtmf", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.GET_STATISTICS -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "getStatistics", arguments)
                    val resultValue = PortsipController.shared.getStatistics(arguments)
                    PortsipLogger.logResponse(COMPONENT, "getStatistics", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.START_RECORD -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "startRecord", arguments)
                    val resultValue = PortsipController.shared.startRecord(arguments)
                    PortsipLogger.logResponse(COMPONENT, "startRecord", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.STOP_RECORD -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "stopRecord", arguments)
                    val resultValue = PortsipController.shared.stopRecord(arguments)
                    PortsipLogger.logResponse(COMPONENT, "stopRecord", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.START_PCM_RECORD -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "startPcmRecord", arguments)
                    val resultValue = PortsipController.shared.startPcmRecord(arguments)
                    PortsipLogger.logResponse(COMPONENT, "startPcmRecord", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.STOP_PCM_RECORD -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "stopPcmRecord", arguments)
                    // Merging the per-direction parts rewrites the whole
                    // recording, so it finishes on the recorder's thread and
                    // answers from there. A MethodChannel.Result must be
                    // completed on the platform thread.
                    PortsipController.shared.stopPcmRecord(arguments) { path ->
                        mainHandler.post {
                            PortsipLogger.logResponse(COMPONENT, "stopPcmRecord", path)
                            result.success(path)
                        }
                    }
                }

                PortsipMethodCall.START_PLAYING_FILE_TO_REMOTE -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "startPlayingFileToRemote", arguments)
                    val resultValue = PortsipController.shared.startPlayingFileToRemote(arguments)
                    PortsipLogger.logResponse(COMPONENT, "startPlayingFileToRemote", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.STOP_PLAYING_FILE_TO_REMOTE -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "stopPlayingFileToRemote", arguments)
                    val resultValue = PortsipController.shared.stopPlayingFileToRemote(arguments)
                    PortsipLogger.logResponse(COMPONENT, "stopPlayingFileToRemote", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.SET_LICENSE_KEY -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "setLicenseKey", arguments)
                    val resultValue = PortsipController.shared.setLicenseKey(arguments)
                    PortsipLogger.logResponse(COMPONENT, "setLicenseKey", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.SET_AUDIO_CODECS -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "setAudioCodecs", arguments)
                    val resultValue = PortsipController.shared.setAudioCodecs(arguments)
                    PortsipLogger.logResponse(COMPONENT, "setAudioCodecs", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.ENABLE_AUDIO_MANAGER -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enableAudioManager", arguments)
                    val resultValue = PortsipController.shared.enableAudioManager(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enableAudioManager", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.SET_SRTP_POLICY -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "setSrtpPolicy", arguments)
                    val resultValue = PortsipController.shared.setSrtpPolicy(arguments)
                    PortsipLogger.logResponse(COMPONENT, "setSrtpPolicy", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.ENABLE_3GPP_TAGS -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enable3GppTags", arguments)
                    val resultValue = PortsipController.shared.enable3GppTags(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enable3GppTags", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.SET_LOGS_ENABLED -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    val enabled = arguments["enabled"] as? Boolean ?: false
                    PortsipLogger.isEnabled = enabled
                    result.success(null)
                }

                PortsipMethodCall.ENABLE_AEC -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enableAEC", arguments)
                    val resultValue = PortsipController.shared.enableAEC(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enableAEC", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.ENABLE_AGC -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enableAGC", arguments)
                    val resultValue = PortsipController.shared.enableAGC(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enableAGC", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.ENABLE_CNG -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enableCNG", arguments)
                    val resultValue = PortsipController.shared.enableCNG(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enableCNG", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.ENABLE_VAD -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enableVAD", arguments)
                    val resultValue = PortsipController.shared.enableVAD(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enableVAD", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.ENABLE_ANS -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enableANS", arguments)
                    val resultValue = PortsipController.shared.enableANS(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enableANS", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.UN_INITIALIZE -> {
                    PortsipLogger.logCall(COMPONENT, "unInitialize")
                    PortsipController.shared.unInitialize()
                    PortsipLogger.logResponse(COMPONENT, "unInitialize", "done")
                    result.success(null)
                }

                PortsipMethodCall.DISPOSE -> {
                    PortsipLogger.logCall(COMPONENT, "dispose")
                    PortsipController.shared.dispose()
                    PortsipLogger.logResponse(COMPONENT, "dispose", "done")
                    result.success(null)
                }

                // ConnectionService methods (Android equivalent to iOS CallKit)

                PortsipMethodCall.CONFIGURE_CONNECTION_SERVICE -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "configureConnectionService", arguments)
                    val resultValue = PortsipController.shared.configureConnectionService(arguments)
                    PortsipLogger.logResponse(COMPONENT, "configureConnectionService", resultValue)
                    result.success(resultValue)
                }

                PortsipMethodCall.ENABLE_CONNECTION_SERVICE -> {
                    val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()
                    PortsipLogger.logCall(COMPONENT, "enableConnectionService", arguments)
                    val resultValue = PortsipController.shared.enableConnectionService(arguments)
                    PortsipLogger.logResponse(COMPONENT, "enableConnectionService", resultValue)
                    result.success(resultValue)
                }
            }
        } catch (e: Exception) {
            PortsipLogger.e(COMPONENT, "❌ Error in ${call.method}: ${e.message}", e)
            result.error("PORTSIP_ERROR", e.message, null)
        }
    }
    
    /**
     * Called when the plugin is detached from the Flutter engine.
     * Cleans up the method channel handler and disposes SDK resources.
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Dispose SDK resources
        PortsipController.shared.dispose()

        // Dispose event bridge (clears pending handler messages)
        PortsipEventBridge.shared.dispose()

        // Clear method channel handler
        channel.setMethodCallHandler(null)
        PortsipLogger.d(COMPONENT, "📱 Plugin detached from engine")
    }

    // MARK: - ActivityAware Implementation

    /**
     * Called when the plugin is attached to an Activity.
     * Provides access to the Activity for permission dialogs and lifecycle management.
     */
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        PortsipController.shared.setActivity(binding.activity)
        PortsipLogger.d(COMPONENT, "📱 Plugin attached to activity")
    }

    /**
     * Called when the Activity is being recreated due to configuration changes.
     * The Activity reference should be cleared temporarily.
     */
    override fun onDetachedFromActivityForConfigChanges() {
        PortsipController.shared.setActivity(null)
        PortsipLogger.d(COMPONENT, "📱 Plugin detached from activity for config changes")
    }

    /**
     * Called when the Activity is reattached after configuration changes.
     */
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        PortsipController.shared.setActivity(binding.activity)
        PortsipLogger.d(COMPONENT, "📱 Plugin reattached to activity after config changes")
    }

    /**
     * Called when the plugin is detached from the Activity.
     * The Activity reference should be cleared.
     */
    override fun onDetachedFromActivity() {
        PortsipController.shared.setActivity(null)
        PortsipLogger.d(COMPONENT, "📱 Plugin detached from activity")
    }
}
