import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/sip_account.dart';
import 'package:portsip/portsip.dart';
import 'package:portsip/portsip_method_channel.dart';
import 'package:portsip/portsip_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelPortsip platform = MethodChannelPortsip();
  const MethodChannel channel = MethodChannel('portsip');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'register') {
            final args = methodCall.arguments as Map;
            if (args['userName'] == 'test_user') {
              return 0; // Success
            }
            return -1; // Failure
          }
          if (methodCall.method == 'initialize') {
            return 0; // Success
          }
          if (methodCall.method == 'dispose') {
            return null;
          }
          if (methodCall.method == 'makeCall') {
            return 12345; // Session ID
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('register calls method channel with correct arguments', () async {
    final account = SipAccount(
      userName: 'test_user',
      password: 'password',
      sipServer: 'sip.example.com',
      sipServerPort: 5060,
      displayName: 'Test User',
      authName: 'auth',
      userDomain: 'example.com',
      stunServer: 'stun.example.com',
      stunServerPort: 3478,
      outboundServer: '',
      outboundServerPort: 0,
      licenseKey: 'TEST_LICENSE',
    );

    final result = await platform.register(account: account);
    expect(result, 0);
  });

  group('Portsip lifecycle state tracking', () {
    test('initial state is uninitialized', () {
      final portsip = Portsip();
      expect(portsip.state, PortsipState.uninitialized);
      expect(portsip.isInitialized, false);
      expect(portsip.isDisposed, false);
    });

    test('state becomes initialized after successful initialize()', () async {
      final portsip = Portsip();

      await portsip.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.none,
        logFilePath: '/tmp',
        maxCallLines: 1,
        sipAgent: 'Test',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      expect(portsip.state, PortsipState.initialized);
      expect(portsip.isInitialized, true);
      expect(portsip.isDisposed, false);

      // Clean up
      await portsip.dispose();
    });

    test('state becomes disposed after dispose()', () async {
      final portsip = Portsip();

      await portsip.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.none,
        logFilePath: '/tmp',
        maxCallLines: 1,
        sipAgent: 'Test',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      await portsip.dispose();

      expect(portsip.state, PortsipState.disposed);
      expect(portsip.isInitialized, false);
      expect(portsip.isDisposed, true);
    });

    test('dispose() on uninitialized instance marks as disposed', () async {
      final portsip = Portsip();
      await portsip.dispose();

      expect(portsip.state, PortsipState.disposed);
      expect(portsip.isDisposed, true);
    });

    test('throws PortsipStateException when calling register() before initialize()', () {
      final portsip = Portsip();
      final account = SipAccount(
        userName: 'test',
        password: 'pass',
        sipServer: 'sip.example.com',
        sipServerPort: 5060,
        displayName: 'Test',
        authName: 'auth',
        userDomain: 'example.com',
        stunServer: '',
        stunServerPort: 0,
        outboundServer: '',
        outboundServerPort: 0,
        licenseKey: '',
      );

      expect(
        () => portsip.register(account: account),
        throwsA(isA<PortsipStateException>()),
      );
    });

    test('throws PortsipStateException when calling makeCall() before initialize()', () {
      final portsip = Portsip();

      expect(
        () => portsip.makeCall(callee: '1234', sendSdp: true, videoCall: false),
        throwsA(isA<PortsipStateException>()),
      );
    });

    test('throws PortsipStateException when calling methods after dispose()', () async {
      final portsip = Portsip();

      await portsip.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.none,
        logFilePath: '/tmp',
        maxCallLines: 1,
        sipAgent: 'Test',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      await portsip.dispose();

      expect(
        () => portsip.makeCall(callee: '1234', sendSdp: true, videoCall: false),
        throwsA(isA<PortsipStateException>()),
      );
    });

    test('throws PortsipStateException when calling initialize() twice', () async {
      final portsip = Portsip();

      await portsip.initialize(
        transport: TransportType.udp,
        localIP: '0.0.0.0',
        localSIPPort: 5060,
        logLevel: PortsipLogLevel.none,
        logFilePath: '/tmp',
        maxCallLines: 1,
        sipAgent: 'Test',
        audioDeviceLayer: 0,
        videoDeviceLayer: 0,
        tlsCertificatesRootPath: '',
        tlsCipherList: '',
        verifyTLSCertificate: false,
        dnsServers: '',
      );

      expect(
        () => portsip.initialize(
          transport: TransportType.udp,
          localIP: '0.0.0.0',
          localSIPPort: 5060,
          logLevel: PortsipLogLevel.none,
          logFilePath: '/tmp',
          maxCallLines: 1,
          sipAgent: 'Test',
          audioDeviceLayer: 0,
          videoDeviceLayer: 0,
          tlsCertificatesRootPath: '',
          tlsCipherList: '',
          verifyTLSCertificate: false,
          dnsServers: '',
        ),
        throwsA(isA<PortsipStateException>()),
      );

      // Clean up
      await portsip.dispose();
    });

    test('throws PortsipStateException when calling dispose() twice', () async {
      final portsip = Portsip();
      await portsip.dispose();

      expect(
        () => portsip.dispose(),
        throwsA(isA<PortsipStateException>()),
      );
    });

    test('PortsipStateException has correct message', () {
      const exception = PortsipStateException('Test error message');
      expect(exception.message, 'Test error message');
      expect(exception.toString(), 'PortsipStateException: Test error message');
    });
  });

  group('Portsip events stream', () {
    test('events getter returns a stream', () {
      final portsip = Portsip();
      expect(portsip.events, isA<Stream<PortsipEvent>>());
    });

    test('typedEvents getter returns a stream', () {
      final portsip = Portsip();
      expect(portsip.typedEvents, isA<Stream<PortsipEvent>>());
    });

    test('typedEvents maps events through toTypedEvent', () {
      // Test that typedEvents stream exists and transforms correctly
      // by checking the transformation logic directly
      final genericEvent = PortsipEvent('onInviteConnected', {'sessionId': 12345});
      final typedEvent = toTypedEvent(genericEvent);

      expect(typedEvent, isA<InviteConnectedEvent>());
      expect((typedEvent as InviteConnectedEvent).sessionId, 12345);
    });
  });

  group('Portsip setLogsEnabled', () {
    test('setLogsEnabled does not throw', () {
      final portsip = Portsip();
      expect(() => portsip.setLogsEnabled(enabled: true), returnsNormally);
      expect(() => portsip.setLogsEnabled(enabled: false), returnsNormally);
    });
  });

  group('PortsipPlatform interface', () {
    test('default instance is MethodChannelPortsip', () {
      expect(PortsipPlatform.instance, isA<MethodChannelPortsip>());
    });
  });
}
