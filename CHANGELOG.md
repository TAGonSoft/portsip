## 0.0.1

* Initial release of the PortSIP Flutter plugin
* **SIP Registration**: Configure and register SIP accounts with server
* **Outgoing Calls**: Make voice calls with session management
* **Call Controls**: Hold, unhold, mute, and hang up calls
* **DTMF Support**: Send DTMF tones via RFC2833, INFO, or INBAND methods
* **Audio Management**:
  - Loudspeaker toggle
  - Audio codec configuration
  - AEC, AGC, ANS, CNG, and VAD controls
* **iOS CallKit Integration**: Native call UI support for iOS
* **Android ConnectionService**: Native call UI support for Android
* **Security**: SRTP policy configuration and TLS certificate support
* **Event System**: Broadcast stream for SDK events with typed event classes
* **Lifecycle Management**: Proper SDK state management with initialize/dispose
* **Logging**: Configurable debug logging across Dart, iOS, and Android layers
* **3GPP Support**: Optional 3GPP tags for carrier compatibility
