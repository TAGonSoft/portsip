import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portsip/models/audio_codec.dart';
import 'package:portsip/models/portsip_events.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/sip_account.dart';
import 'package:portsip/portsip_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelPortsip platform;
  const MethodChannel channel = MethodChannel('portsip');

  // Track method calls for verification
  late List<MethodCall> methodCalls;

  setUp(() {
    platform = MethodChannelPortsip();
    methodCalls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'initialize':
              return 0; // Success
            case 'register':
              return 0; // Success
            case 'unRegister':
              return null;
            case 'makeCall':
              return 12345; // Session ID
            case 'hangUp':
              return 0; // Success
            case 'hold':
              return 0; // Success
            case 'unHold':
              return 0; // Success
            case 'muteSession':
              return 0; // Success
            case 'setLoudspeakerStatus':
              return null;
            case 'sendDtmf':
              return 0; // Success
            case 'configureCallKit':
              return null;
            case 'enableCallKit':
              return null;
            case 'setLicenseKey':
              return 0; // Success
            case 'setAudioCodecs':
              return 0; // Success
            case 'registerServer':
              return 0; // Success
            case 'configureConnectionService':
              return 0; // Success
            case 'enableConnectionService':
              return 0; // Success
            case 'enable3GppTags':
              return 0; // Success
            case 'setSrtpPolicy':
              return 0; // Success
            case 'enableAudioManager':
              return 0; // Success
            case 'enableCNG':
              return 0; // Success
            case 'enableVAD':
              return 0; // Success
            case 'setLogsEnabled':
              return null; // void method
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('initialize', () {
    test('calls method channel with correct method name', () async {
      await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '/tmp/log',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'initialize');
    });

    test('passes all required arguments correctly', () async {
      await platform.initialize(
        transport: TransportType.tls,
        localIP: '192.168.1.1',
        localSIPPort: 5061,
        logLevel: PortsipLogLevel.info,
        logFilePath: '/var/log/sip',
        maxCallLines: 4,
        sipAgent: 'MyAgent/1.0',
        audioDeviceLayer: 1,
        videoDeviceLayer: 2,
        tlsCertificatesRootPath: '/certs',
        tlsCipherList: 'HIGH:!aNULL',
        verifyTLSCertificate: true,
        dnsServers: '8.8.8.8',
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['transport'], TransportType.tls.value);
      expect(args['localIP'], '192.168.1.1');
      expect(args['localSIPPort'], 5061);
      expect(args['logLevel'], PortsipLogLevel.info.value);
      expect(args['logFilePath'], '/var/log/sip');
      expect(args['maxCallLines'], 4);
      expect(args['sipAgent'], 'MyAgent/1.0');
      expect(args['audioDeviceLayer'], 1);
      expect(args['videoDeviceLayer'], 2);
      expect(args['tlsCertificatesRootPath'], '/certs');
      expect(args['tlsCipherList'], 'HIGH:!aNULL');
      expect(args['verifyTLSCertificate'], true);
      expect(args['dnsServers'], '8.8.8.8');
    });

    test('passes optional ptime arguments with defaults', () async {
      await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['ptime'], 20); // Default value
      expect(args['maxPtime'], 60); // Default value
    });

    test('passes custom ptime values', () async {
      await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
        ptime: 30,
        maxPtime: 120,
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['ptime'], 30);
      expect(args['maxPtime'], 120);
    });

    test('returns result from native', () async {
      final result = await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      expect(result, 0);
    });

    test('maps all TransportType values correctly', () async {
      for (final transport in TransportType.values) {
        methodCalls.clear();
        await platform.initialize(
          transport: transport,
          localIP: '0.0.0.0',
          localSIPPort: 5060,
          logLevel: PortsipLogLevel.debug,
          logFilePath: '',
          maxCallLines: 8,
          sipAgent: 'TestAgent',
          audioDeviceLayer: 0,
          videoDeviceLayer: 0,
          tlsCertificatesRootPath: '',
          tlsCipherList: '',
          verifyTLSCertificate: false,
          dnsServers: '',
        );

        final args = methodCalls.first.arguments as Map;
        expect(args['transport'], transport.value);
      }
    });

    test('maps all PortsipLogLevel values correctly', () async {
      for (final logLevel in PortsipLogLevel.values) {
        methodCalls.clear();
        await platform.initialize(
          transport: TransportType.udp,
          localIP: '0.0.0.0',
          localSIPPort: 5060,
          logLevel: logLevel,
          logFilePath: '',
          maxCallLines: 8,
          sipAgent: 'TestAgent',
          audioDeviceLayer: 0,
          videoDeviceLayer: 0,
          tlsCertificatesRootPath: '',
          tlsCipherList: '',
          verifyTLSCertificate: false,
          dnsServers: '',
        );

        final args = methodCalls.first.arguments as Map;
        expect(args['logLevel'], logLevel.value);
      }
    });
  });

  group('register', () {
    test('calls method channel with correct method name', () async {
      final account = SipAccount(
        userName: 'test_user',
        password: 'password',
        sipServer: 'sip.example.com',
        sipServerPort: 5060,
        stunServer: 'stun.example.com',
        stunServerPort: 3478,
      );

      await platform.register(account: account);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'register');
    });

    test('passes all SipAccount fields correctly', () async {
      final account = SipAccount(
        userName: 'john_doe',
        password: 'secret123',
        sipServer: 'sip.company.com',
        sipServerPort: 5060,
        stunServer: 'stun.company.com',
        stunServerPort: 3478,
        outboundServer: 'proxy.company.com',
        outboundServerPort: 5065,
        displayName: 'John Doe',
        authName: 'john_auth',
        userDomain: 'company.com',
        licenseKey: 'LICENSE-KEY-123',
        registerTimeout: 180,
        registerRetryTimes: 5,
        videoBitrate: 1000,
        videoFrameRate: 30,
        videoWidth: 640,
        videoHeight: 480,
        audioCodecs: [AudioCodec.opus, AudioCodec.pcmu],
      );

      await platform.register(account: account);

      final args = methodCalls.first.arguments as Map;
      expect(args['userName'], 'john_doe');
      expect(args['password'], 'secret123');
      expect(args['sipServer'], 'sip.company.com');
      expect(args['sipServerPort'], 5060);
      expect(args['stunServer'], 'stun.company.com');
      expect(args['stunServerPort'], 3478);
      expect(args['outboundServer'], 'proxy.company.com');
      expect(args['outboundServerPort'], 5065);
      expect(args['displayName'], 'John Doe');
      expect(args['authName'], 'john_auth');
      expect(args['userDomain'], 'company.com');
      expect(args['licenseKey'], 'LICENSE-KEY-123');
      expect(args['registerTimeout'], 180);
      expect(args['registerRetryTimes'], 5);
      expect(args['videoBitrate'], 1000);
      expect(args['videoFrameRate'], 30);
      expect(args['videoWidth'], 640);
      expect(args['videoHeight'], 480);
      expect(args['audioCodecs'], [
        AudioCodec.opus.value,
        AudioCodec.pcmu.value,
      ]);
    });

    test('uses default values for optional fields', () async {
      final account = SipAccount(
        userName: 'user',
        password: 'pass',
        sipServer: 'sip.test.com',
        sipServerPort: 5060,
        stunServer: 'stun.test.com',
        stunServerPort: 3478,
      );

      await platform.register(account: account);

      final args = methodCalls.first.arguments as Map;
      expect(args['outboundServer'], '');
      expect(args['outboundServerPort'], 0);
      expect(args['displayName'], '');
      expect(args['authName'], '');
      expect(args['userDomain'], '');
      expect(args['licenseKey'], '');
      expect(args['registerTimeout'], 120);
      expect(args['registerRetryTimes'], 3);
      expect(args['videoBitrate'], 500);
      expect(args['videoFrameRate'], 10);
      expect(args['videoWidth'], 352);
      expect(args['videoHeight'], 288);
      // SipAccount uses default codecs when none provided
      expect(args['audioCodecs'], [
        AudioCodec.opus.value,
        AudioCodec.pcmu.value,
        AudioCodec.pcma.value,
      ]);
    });

    test('returns result from native', () async {
      final account = SipAccount(
        userName: 'test',
        password: 'test',
        sipServer: 'sip.test.com',
        sipServerPort: 5060,
        stunServer: 'stun.test.com',
        stunServerPort: 3478,
      );

      final result = await platform.register(account: account);
      expect(result, 0);
    });
  });

  group('unRegister', () {
    test('calls method channel with correct method name', () async {
      await platform.unRegister();

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'unRegister');
    });

    test('sends no arguments', () async {
      await platform.unRegister();

      expect(methodCalls.first.arguments, isNull);
    });
  });

  group('makeCall', () {
    test('calls method channel with correct method name', () async {
      await platform.makeCall(
        callee: '+1234567890',
        sendSdp: true,
        videoCall: false,
      );

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'makeCall');
    });

    test('passes all arguments correctly', () async {
      await platform.makeCall(
        callee: 'sip:user@domain.com',
        sendSdp: false,
        videoCall: true,
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['callee'], 'sip:user@domain.com');
      expect(args['sendSdp'], false);
      expect(args['videoCall'], true);
    });

    test('returns session ID from native', () async {
      final result = await platform.makeCall(
        callee: '+1234567890',
        sendSdp: true,
        videoCall: false,
      );

      expect(result, 12345);
    });
  });

  group('hangUp', () {
    test('calls method channel with correct method name', () async {
      await platform.hangUp(sessionId: 12345);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'hangUp');
    });

    test('passes sessionId correctly', () async {
      await platform.hangUp(sessionId: 99999);

      final args = methodCalls.first.arguments as Map;
      expect(args['sessionId'], 99999);
    });

    test('returns result from native', () async {
      final result = await platform.hangUp(sessionId: 12345);
      expect(result, 0);
    });
  });

  group('hold', () {
    test('calls method channel with correct method name', () async {
      await platform.hold(sessionId: 12345);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'hold');
    });

    test('passes sessionId correctly', () async {
      await platform.hold(sessionId: 77777);

      final args = methodCalls.first.arguments as Map;
      expect(args['sessionId'], 77777);
    });

    test('returns result from native', () async {
      final result = await platform.hold(sessionId: 12345);
      expect(result, 0);
    });
  });

  group('unHold', () {
    test('calls method channel with correct method name', () async {
      await platform.unHold(sessionId: 12345);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'unHold');
    });

    test('passes sessionId correctly', () async {
      await platform.unHold(sessionId: 88888);

      final args = methodCalls.first.arguments as Map;
      expect(args['sessionId'], 88888);
    });

    test('returns result from native', () async {
      final result = await platform.unHold(sessionId: 12345);
      expect(result, 0);
    });
  });

  group('muteSession', () {
    test('calls method channel with correct method name', () async {
      await platform.muteSession(
        sessionId: 12345,
        muteIncomingAudio: false,
        muteOutgoingAudio: true,
        muteIncomingVideo: false,
        muteOutgoingVideo: false,
      );

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'muteSession');
    });

    test('passes all arguments correctly', () async {
      await platform.muteSession(
        sessionId: 11111,
        muteIncomingAudio: true,
        muteOutgoingAudio: true,
        muteIncomingVideo: true,
        muteOutgoingVideo: true,
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['sessionId'], 11111);
      expect(args['muteIncomingAudio'], true);
      expect(args['muteOutgoingAudio'], true);
      expect(args['muteIncomingVideo'], true);
      expect(args['muteOutgoingVideo'], true);
    });

    test('handles mixed mute states', () async {
      await platform.muteSession(
        sessionId: 22222,
        muteIncomingAudio: false,
        muteOutgoingAudio: true,
        muteIncomingVideo: true,
        muteOutgoingVideo: false,
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['muteIncomingAudio'], false);
      expect(args['muteOutgoingAudio'], true);
      expect(args['muteIncomingVideo'], true);
      expect(args['muteOutgoingVideo'], false);
    });

    test('returns result from native', () async {
      final result = await platform.muteSession(
        sessionId: 12345,
        muteIncomingAudio: false,
        muteOutgoingAudio: false,
        muteIncomingVideo: false,
        muteOutgoingVideo: false,
      );
      expect(result, 0);
    });
  });

  group('setLoudspeakerStatus', () {
    test('calls method channel with correct method name', () async {
      await platform.setLoudspeakerStatus(enable: true);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'setLoudspeakerStatus');
    });

    test('passes enable=true correctly', () async {
      await platform.setLoudspeakerStatus(enable: true);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], true);
    });

    test('passes enable=false correctly', () async {
      await platform.setLoudspeakerStatus(enable: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], false);
    });
  });

  group('sendDtmf', () {
    test('calls method channel with correct method name', () async {
      await platform.sendDtmf(sessionId: 12345, dtmf: 5, playDtmfTone: true);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'sendDtmf');
    });

    test('passes required arguments correctly', () async {
      await platform.sendDtmf(sessionId: 11111, dtmf: 9, playDtmfTone: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['sessionId'], 11111);
      expect(args['dtmf'], 9);
      expect(args['playDtmfTone'], false);
    });

    test('uses default values for optional arguments', () async {
      await platform.sendDtmf(sessionId: 12345, dtmf: 0, playDtmfTone: true);

      final args = methodCalls.first.arguments as Map;
      expect(args['dtmfMethod'], 0); // Default: RFC2833
      expect(args['dtmfDuration'], 160); // Default: 160ms
    });

    test('passes custom optional arguments', () async {
      await platform.sendDtmf(
        sessionId: 12345,
        dtmf: 1,
        playDtmfTone: true,
        dtmfMethod: 1, // INFO
        dtmfDuration: 250,
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['dtmfMethod'], 1);
      expect(args['dtmfDuration'], 250);
    });

    test('handles all DTMF digits 0-9', () async {
      for (int digit = 0; digit <= 9; digit++) {
        methodCalls.clear();
        await platform.sendDtmf(
          sessionId: 12345,
          dtmf: digit,
          playDtmfTone: true,
        );

        final args = methodCalls.first.arguments as Map;
        expect(args['dtmf'], digit);
      }
    });

    test('returns result from native', () async {
      final result = await platform.sendDtmf(
        sessionId: 12345,
        dtmf: 5,
        playDtmfTone: true,
      );
      expect(result, 0);
    });
  });

  group('configureCallKit', () {
    test('calls method channel with correct method name', () async {
      await platform.configureCallKit(appName: 'MyApp');

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'configureCallKit');
    });

    test('passes required appName correctly', () async {
      await platform.configureCallKit(appName: 'TestPhone');

      final args = methodCalls.first.arguments as Map;
      expect(args['appName'], 'TestPhone');
    });

    test('uses default canUseCallKit=true', () async {
      await platform.configureCallKit(appName: 'MyApp');

      final args = methodCalls.first.arguments as Map;
      expect(args['canUseCallKit'], true);
    });

    test('passes canUseCallKit=false correctly', () async {
      await platform.configureCallKit(appName: 'MyApp', canUseCallKit: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['canUseCallKit'], false);
    });

    test('omits iconTemplateImageName when null', () async {
      await platform.configureCallKit(appName: 'MyApp');

      final args = methodCalls.first.arguments as Map;
      expect(args.containsKey('iconTemplateImageName'), false);
    });

    test('passes iconTemplateImageName when provided', () async {
      await platform.configureCallKit(
        appName: 'MyApp',
        iconTemplateImageName: 'CallKitIcon',
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['iconTemplateImageName'], 'CallKitIcon');
    });
  });

  group('enableCallKit', () {
    test('calls method channel with correct method name', () async {
      await platform.enableCallKit(enabled: true);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'enableCallKit');
    });

    test('passes enabled=true correctly', () async {
      await platform.enableCallKit(enabled: true);

      final args = methodCalls.first.arguments as Map;
      expect(args['enabled'], true);
    });

    test('passes enabled=false correctly', () async {
      await platform.enableCallKit(enabled: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['enabled'], false);
    });
  });

  group('setLicenseKey', () {
    test('calls method channel with correct method name', () async {
      await platform.setLicenseKey(licenseKey: 'ABC-123-XYZ');

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'setLicenseKey');
    });

    test('passes licenseKey correctly', () async {
      await platform.setLicenseKey(licenseKey: 'PORTSIP-LICENSE-KEY-2024');

      final args = methodCalls.first.arguments as Map;
      expect(args['licenseKey'], 'PORTSIP-LICENSE-KEY-2024');
    });

    test('returns result from native', () async {
      final result = await platform.setLicenseKey(licenseKey: 'KEY');
      expect(result, 0);
    });
  });

  group('setAudioCodecs', () {
    test('calls method channel with correct method name', () async {
      await platform.setAudioCodecs(audioCodecs: [AudioCodec.opus]);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'setAudioCodecs');
    });

    test('passes single codec correctly', () async {
      await platform.setAudioCodecs(audioCodecs: [AudioCodec.pcmu]);

      final args = methodCalls.first.arguments as Map;
      expect(args['audioCodecs'], [AudioCodec.pcmu.value]);
    });

    test('passes multiple codecs in order', () async {
      await platform.setAudioCodecs(
        audioCodecs: [
          AudioCodec.opus,
          AudioCodec.pcmu,
          AudioCodec.pcma,
          AudioCodec.g729,
        ],
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['audioCodecs'], [
        AudioCodec.opus.value,
        AudioCodec.pcmu.value,
        AudioCodec.pcma.value,
        AudioCodec.g729.value,
      ]);
    });

    test('handles empty codec list', () async {
      await platform.setAudioCodecs(audioCodecs: []);

      final args = methodCalls.first.arguments as Map;
      expect(args['audioCodecs'], []);
    });

    test('maps all AudioCodec values correctly', () async {
      for (final codec in AudioCodec.values) {
        methodCalls.clear();
        await platform.setAudioCodecs(audioCodecs: [codec]);

        final args = methodCalls.first.arguments as Map;
        expect(args['audioCodecs'], [codec.value]);
      }
    });

    test('returns result from native', () async {
      final result = await platform.setAudioCodecs(
        audioCodecs: [AudioCodec.opus],
      );
      expect(result, 0);
    });
  });

  group('registerServer', () {
    test('calls method channel with correct method name', () async {
      await platform.registerServer();

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'registerServer');
    });

    test('uses default values', () async {
      await platform.registerServer();

      final args = methodCalls.first.arguments as Map;
      expect(args['registerTimeout'], 120);
      expect(args['registerRetryTimes'], 3);
    });

    test('passes custom values', () async {
      await platform.registerServer(
        registerTimeout: 300,
        registerRetryTimes: 10,
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['registerTimeout'], 300);
      expect(args['registerRetryTimes'], 10);
    });

    test('returns result from native', () async {
      final result = await platform.registerServer();
      expect(result, 0);
    });
  });

  group('configureConnectionService', () {
    test('calls method channel with correct method name', () async {
      await platform.configureConnectionService(appName: 'MyApp');

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'configureConnectionService');
    });

    test('passes required appName correctly', () async {
      await platform.configureConnectionService(appName: 'TestVoIPApp');

      final args = methodCalls.first.arguments as Map;
      expect(args['appName'], 'TestVoIPApp');
    });

    test('uses default canUseConnectionService=true', () async {
      await platform.configureConnectionService(appName: 'MyApp');

      final args = methodCalls.first.arguments as Map;
      expect(args['canUseConnectionService'], true);
    });

    test('passes canUseConnectionService=false correctly', () async {
      await platform.configureConnectionService(
        appName: 'MyApp',
        canUseConnectionService: false,
      );

      final args = methodCalls.first.arguments as Map;
      expect(args['canUseConnectionService'], false);
    });

    test('returns result from native', () async {
      final result = await platform.configureConnectionService(appName: 'MyApp');
      expect(result, 0);
    });
  });

  group('enableConnectionService', () {
    test('calls method channel with correct method name', () async {
      await platform.enableConnectionService(enabled: true);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'enableConnectionService');
    });

    test('passes enabled=true correctly', () async {
      await platform.enableConnectionService(enabled: true);

      final args = methodCalls.first.arguments as Map;
      expect(args['enabled'], true);
    });

    test('passes enabled=false correctly', () async {
      await platform.enableConnectionService(enabled: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['enabled'], false);
    });

    test('returns result from native', () async {
      final result = await platform.enableConnectionService(enabled: true);
      expect(result, 0);
    });
  });

  group('enable3GppTags', () {
    test('calls method channel with correct method name', () async {
      await platform.enable3GppTags(enable: true);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'enable3GppTags');
    });

    test('passes enable=true correctly', () async {
      await platform.enable3GppTags(enable: true);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], true);
    });

    test('passes enable=false correctly', () async {
      await platform.enable3GppTags(enable: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], false);
    });

    test('returns result from native', () async {
      final result = await platform.enable3GppTags(enable: true);
      expect(result, 0);
    });
  });

  group('setSrtpPolicy', () {
    test('calls method channel with correct method name', () async {
      await platform.setSrtpPolicy(policy: 0);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'setSrtpPolicy');
    });

    test('passes policy=0 (none) correctly', () async {
      await platform.setSrtpPolicy(policy: 0);

      final args = methodCalls.first.arguments as Map;
      expect(args['policy'], 0);
    });

    test('passes policy=1 (prefer) correctly', () async {
      await platform.setSrtpPolicy(policy: 1);

      final args = methodCalls.first.arguments as Map;
      expect(args['policy'], 1);
    });

    test('passes policy=2 (force) correctly', () async {
      await platform.setSrtpPolicy(policy: 2);

      final args = methodCalls.first.arguments as Map;
      expect(args['policy'], 2);
    });

    test('returns result from native', () async {
      final result = await platform.setSrtpPolicy(policy: 1);
      expect(result, 0);
    });
  });

  group('enableAudioManager', () {
    test('calls method channel with correct method name', () async {
      await platform.enableAudioManager(enable: true);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'enableAudioManager');
    });

    test('passes enable=true correctly', () async {
      await platform.enableAudioManager(enable: true);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], true);
    });

    test('passes enable=false correctly', () async {
      await platform.enableAudioManager(enable: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], false);
    });

    test('returns result from native', () async {
      final result = await platform.enableAudioManager(enable: true);
      expect(result, 0);
    });
  });

  group('Error handling', () {
    test('initialize returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      expect(result, -1);
    });

    test('register returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final account = SipAccount(
        userName: 'test',
        password: 'test',
        sipServer: 'sip.test.com',
        sipServerPort: 5060,
        stunServer: 'stun.test.com',
        stunServerPort: 3478,
      );

      final result = await platform.register(account: account);
      expect(result, -1);
    });

    test('makeCall returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.makeCall(
        callee: '+1234567890',
        sendSdp: true,
        videoCall: false,
      );

      expect(result, -1);
    });

    test('hangUp returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.hangUp(sessionId: 12345);
      expect(result, -1);
    });

    test('hold returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.hold(sessionId: 12345);
      expect(result, -1);
    });

    test('unHold returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.unHold(sessionId: 12345);
      expect(result, -1);
    });

    test('muteSession returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.muteSession(
        sessionId: 12345,
        muteIncomingAudio: false,
        muteOutgoingAudio: true,
        muteIncomingVideo: false,
        muteOutgoingVideo: false,
      );
      expect(result, -1);
    });

    test('sendDtmf returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.sendDtmf(
        sessionId: 12345,
        dtmf: 5,
        playDtmfTone: true,
      );
      expect(result, -1);
    });

    test('setLicenseKey returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.setLicenseKey(licenseKey: 'KEY');
      expect(result, -1);
    });

    test('setAudioCodecs returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.setAudioCodecs(
        audioCodecs: [AudioCodec.opus],
      );
      expect(result, -1);
    });

    test('registerServer returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.registerServer();
      expect(result, -1);
    });

    test('configureConnectionService returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.configureConnectionService(appName: 'MyApp');
      expect(result, -1);
    });

    test('enableConnectionService returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.enableConnectionService(enabled: true);
      expect(result, -1);
    });

    test('enable3GppTags returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.enable3GppTags(enable: true);
      expect(result, -1);
    });

    test('setSrtpPolicy returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.setSrtpPolicy(policy: 1);
      expect(result, -1);
    });

    test('enableAudioManager returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.enableAudioManager(enable: true);
      expect(result, -1);
    });
  });

  group('Error codes from native', () {
    test('initialize returns negative error code from native', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return -100; // Simulated error code
          });

      final result = await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      expect(result, -100);
    });

    test('makeCall returns negative session ID on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return -1; // Error: call failed
          });

      final result = await platform.makeCall(
        callee: '+1234567890',
        sendSdp: true,
        videoCall: false,
      );

      expect(result, -1);
    });

    test('register returns specific error codes', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return -2; // Simulated: invalid credentials
          });

      final account = SipAccount(
        userName: 'test',
        password: 'test',
        sipServer: 'sip.test.com',
        sipServerPort: 5060,
        stunServer: 'stun.test.com',
        stunServerPort: 3478,
      );

      final result = await platform.register(account: account);
      expect(result, -2);
    });
  });

  group('PlatformException handling', () {
    // Note: The implementation now catches PlatformException and returns -1
    // instead of throwing. This is the expected behavior for graceful error handling.

    test('initialize returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'INITIALIZATION_ERROR',
              message: 'Failed to initialize SDK',
            );
          });

      final result = await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      expect(result, -1);
    });

    test('register returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'REGISTRATION_ERROR',
              message: 'Failed to register account',
            );
          });

      final account = SipAccount(
        userName: 'test',
        password: 'test',
        sipServer: 'sip.test.com',
        sipServerPort: 5060,
        stunServer: 'stun.test.com',
        stunServerPort: 3478,
      );

      final result = await platform.register(account: account);
      expect(result, -1);
    });

    test('makeCall returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'CALL_ERROR',
              message: 'Failed to make call',
            );
          });

      final result = await platform.makeCall(
        callee: '+1234567890',
        sendSdp: true,
        videoCall: false,
      );

      expect(result, -1);
    });

    test('hangUp returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'HANGUP_ERROR',
              message: 'Failed to hang up',
            );
          });

      final result = await platform.hangUp(sessionId: 12345);
      expect(result, -1);
    });

    test('unRegister completes without throwing on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'UNREGISTER_ERROR',
              message: 'Failed to unregister',
            );
          });

      // unRegister returns void and catches exceptions internally
      await expectLater(platform.unRegister(), completes);
    });

    test('configureConnectionService returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'CONNECTION_SERVICE_ERROR',
              message: 'Failed to configure ConnectionService',
            );
          });

      final result = await platform.configureConnectionService(appName: 'MyApp');
      expect(result, -1);
    });

    test('enableConnectionService returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'CONNECTION_SERVICE_ERROR',
              message: 'Failed to enable ConnectionService',
            );
          });

      final result = await platform.enableConnectionService(enabled: true);
      expect(result, -1);
    });

    test('enable3GppTags returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: '3GPP_TAGS_ERROR',
              message: 'Failed to enable 3GPP tags',
            );
          });

      final result = await platform.enable3GppTags(enable: true);
      expect(result, -1);
    });

    test('setSrtpPolicy returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'SRTP_POLICY_ERROR',
              message: 'Failed to set SRTP policy',
            );
          });

      final result = await platform.setSrtpPolicy(policy: 1);
      expect(result, -1);
    });

    test('enableAudioManager returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'AUDIO_MANAGER_ERROR',
              message: 'Failed to enable audio manager',
            );
          });

      final result = await platform.enableAudioManager(enable: true);
      expect(result, -1);
    });
  });

  group('events stream (broadcast)', () {
    test('returns a broadcast stream', () {
      final stream = platform.events;
      expect(stream.isBroadcast, isTrue);
    });

    test('supports multiple listeners', () async {
      final events1 = <PortsipEvent>[];
      final events2 = <PortsipEvent>[];

      final sub1 = platform.events.listen((event) => events1.add(event));
      final sub2 = platform.events.listen((event) => events2.add(event));

      // Simulate native calling back to Flutter
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'portsip',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onRegisterSuccess', {'statusCode': 200}),
            ),
            (ByteData? data) {},
          );

      expect(events1.length, 1);
      expect(events2.length, 1);
      expect(events1.first.name, 'onRegisterSuccess');
      expect(events2.first.name, 'onRegisterSuccess');

      await sub1.cancel();
      await sub2.cancel();
    });

    test('PortsipEvent has correct properties', () async {
      PortsipEvent? receivedEvent;

      final sub = platform.events.listen((event) => receivedEvent = event);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'portsip',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onInviteAnswered', {'sessionId': 12345}),
            ),
            (ByteData? data) {},
          );

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.name, 'onInviteAnswered');
      expect(receivedEvent!.data, {'sessionId': 12345});

      await sub.cancel();
    });

    test('PortsipEvent toString returns expected format', () {
      final event = PortsipEvent('testEvent', {'key': 'value'});
      expect(event.toString(), 'PortsipEvent(testEvent, {key: value})');
    });

    test('can filter events using where', () async {
      final callEvents = <PortsipEvent>[];

      final sub = platform.events
          .where((e) => e.name.startsWith('onInvite'))
          .listen((event) => callEvents.add(event));

      // Send multiple events
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'portsip',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onRegisterSuccess', {'statusCode': 200}),
            ),
            (ByteData? data) {},
          );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'portsip',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onInviteConnected', {'sessionId': 123}),
            ),
            (ByteData? data) {},
          );

      expect(callEvents.length, 1);
      expect(callEvents.first.name, 'onInviteConnected');

      await sub.cancel();
    });

    test('new listener receives future events only', () async {
      // Send first event before subscribing
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'portsip',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onRegisterSuccess', {'statusCode': 200}),
            ),
            (ByteData? data) {},
          );

      // Now subscribe
      final events = <PortsipEvent>[];
      final sub = platform.events.listen((event) => events.add(event));

      // Send second event after subscribing
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'portsip',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onInviteConnected', {'sessionId': 123}),
            ),
            (ByteData? data) {},
          );

      // Should only have the second event
      expect(events.length, 1);
      expect(events.first.name, 'onInviteConnected');

      await sub.cancel();
    });
  });

  group('enableAEC', () {
    test('calls method channel with correct method name on Android', () async {
      // Note: enableAEC only calls native on Android, skips on iOS
      // In tests, Platform.isAndroid is false, so we test the skip behavior
      await platform.enableAEC(enable: true);

      // On non-Android, method channel is not called
      expect(methodCalls.isEmpty, isTrue);
    });

    test('returns 0 on non-Android platforms', () async {
      final result = await platform.enableAEC(enable: true);
      expect(result, 0);
    });
  });

  group('enableAGC', () {
    test('calls method channel with correct method name on Android', () async {
      // Note: enableAGC only calls native on Android, skips on iOS
      await platform.enableAGC(enable: true);

      // On non-Android, method channel is not called
      expect(methodCalls.isEmpty, isTrue);
    });

    test('returns 0 on non-Android platforms', () async {
      final result = await platform.enableAGC(enable: false);
      expect(result, 0);
    });
  });

  group('enableCNG', () {
    test('calls method channel with correct method name', () async {
      await platform.enableCNG(enable: true);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'enableCNG');
    });

    test('passes enable=true correctly', () async {
      await platform.enableCNG(enable: true);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], true);
    });

    test('passes enable=false correctly', () async {
      await platform.enableCNG(enable: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], false);
    });

    test('returns result from native', () async {
      final result = await platform.enableCNG(enable: true);
      expect(result, 0);
    });

    test('returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.enableCNG(enable: true);
      expect(result, -1);
    });

    test('returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'CNG_ERROR',
              message: 'Failed to enable CNG',
            );
          });

      final result = await platform.enableCNG(enable: true);
      expect(result, -1);
    });
  });

  group('enableVAD', () {
    test('calls method channel with correct method name', () async {
      await platform.enableVAD(enable: true);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'enableVAD');
    });

    test('passes enable=true correctly', () async {
      await platform.enableVAD(enable: true);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], true);
    });

    test('passes enable=false correctly', () async {
      await platform.enableVAD(enable: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['enable'], false);
    });

    test('returns result from native', () async {
      final result = await platform.enableVAD(enable: true);
      expect(result, 0);
    });

    test('returns -1 when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return null;
          });

      final result = await platform.enableVAD(enable: true);
      expect(result, -1);
    });

    test('returns -1 on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(
              code: 'VAD_ERROR',
              message: 'Failed to enable VAD',
            );
          });

      final result = await platform.enableVAD(enable: true);
      expect(result, -1);
    });
  });

  group('enableANS', () {
    test('calls method channel with correct method name on Android', () async {
      // Note: enableANS only calls native on Android, skips on iOS
      await platform.enableANS(enable: true);

      // On non-Android, method channel is not called
      expect(methodCalls.isEmpty, isTrue);
    });

    test('returns 0 on non-Android platforms', () async {
      final result = await platform.enableANS(enable: false);
      expect(result, 0);
    });
  });

  group('setLogsEnabled', () {
    test('calls method channel with correct method name', () async {
      platform.setLogsEnabled(enabled: true);

      // Give time for async operation
      await Future.delayed(Duration.zero);

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'setLogsEnabled');
    });

    test('passes enabled=true correctly', () async {
      platform.setLogsEnabled(enabled: true);

      await Future.delayed(Duration.zero);

      final args = methodCalls.first.arguments as Map;
      expect(args['enabled'], true);
    });

    test('passes enabled=false correctly', () async {
      platform.setLogsEnabled(enabled: false);

      await Future.delayed(Duration.zero);

      final args = methodCalls.first.arguments as Map;
      expect(args['enabled'], false);
    });

  });

  group('Edge cases', () {
    test('handles empty string for callee', () async {
      await platform.makeCall(callee: '', sendSdp: true, videoCall: false);

      final args = methodCalls.first.arguments as Map;
      expect(args['callee'], '');
    });

    test('handles very large session ID', () async {
      const largeSessionId = 2147483647; // Max int32

      await platform.hangUp(sessionId: largeSessionId);

      final args = methodCalls.first.arguments as Map;
      expect(args['sessionId'], largeSessionId);
    });

    test('handles port boundary values', () async {
      // Port 0
      await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 0,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      var args = methodCalls.first.arguments as Map;
      expect(args['localSIPPort'], 0);

      methodCalls.clear();

      // Port 65535 (max valid port)
      await platform.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 65535,
        logLevel: PortsipLogLevel.debug,
        logFilePath: '',
        maxCallLines: 8,
        sipAgent: 'TestAgent',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      args = methodCalls.first.arguments as Map;
      expect(args['localSIPPort'], 65535);
    });

    test('handles special characters in strings', () async {
      final account = SipAccount(
        userName: 'user@test.com',
        password: 'p@ss\$word!#%',
        sipServer: 'sip.test.com',
        sipServerPort: 5060,
        stunServer: 'stun.test.com',
        stunServerPort: 3478,
        displayName: 'John "Johnny" O\'Connor',
      );

      await platform.register(account: account);

      final args = methodCalls.first.arguments as Map;
      expect(args['userName'], 'user@test.com');
      expect(args['password'], 'p@ss\$word!#%');
      expect(args['displayName'], 'John "Johnny" O\'Connor');
    });

    test('handles unicode characters in strings', () async {
      final account = SipAccount(
        userName: 'user',
        password: 'pass',
        sipServer: 'sip.test.com',
        sipServerPort: 5060,
        stunServer: 'stun.test.com',
        stunServerPort: 3478,
        displayName: '日本語ユーザー 🎉',
      );

      await platform.register(account: account);

      final args = methodCalls.first.arguments as Map;
      expect(args['displayName'], '日本語ユーザー 🎉');
    });

    test('handles empty license key', () async {
      final result = await platform.setLicenseKey(licenseKey: '');

      final args = methodCalls.first.arguments as Map;
      expect(args['licenseKey'], '');
      expect(result, 0);
    });

    test('handles zero values for timeout and retry', () async {
      await platform.registerServer(registerTimeout: 0, registerRetryTimes: 0);

      final args = methodCalls.first.arguments as Map;
      expect(args['registerTimeout'], 0);
      expect(args['registerRetryTimes'], 0);
    });

    test('handles all DTMF methods', () async {
      // RFC2833 (0)
      await platform.sendDtmf(
        sessionId: 12345,
        dtmf: 1,
        playDtmfTone: true,
        dtmfMethod: 0,
      );
      expect((methodCalls.last.arguments as Map)['dtmfMethod'], 0);

      // INFO (1)
      await platform.sendDtmf(
        sessionId: 12345,
        dtmf: 1,
        playDtmfTone: true,
        dtmfMethod: 1,
      );
      expect((methodCalls.last.arguments as Map)['dtmfMethod'], 1);

      // INBAND (2)
      await platform.sendDtmf(
        sessionId: 12345,
        dtmf: 1,
        playDtmfTone: true,
        dtmfMethod: 2,
      );
      expect((methodCalls.last.arguments as Map)['dtmfMethod'], 2);
    });
  });
}
