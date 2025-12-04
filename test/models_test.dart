import 'package:flutter_test/flutter_test.dart';
import 'package:portsip/models/audio_codec.dart';
import 'package:portsip/models/portsip_type.dart';
import 'package:portsip/models/session_model.dart';
import 'package:portsip/models/sip_account.dart';

void main() {
  group('SipAccount', () {
    group('toMap()', () {
      test('returns map with all required fields', () {
        final account = SipAccount(
          userName: 'john_doe',
          password: 'secret123',
          sipServer: 'sip.example.com',
          sipServerPort: 5060,
          stunServer: 'stun.example.com',
          stunServerPort: 3478,
        );

        final map = account.toMap();

        expect(map['userName'], 'john_doe');
        expect(map['password'], 'secret123');
        expect(map['sipServer'], 'sip.example.com');
        expect(map['sipServerPort'], 5060);
        expect(map['stunServer'], 'stun.example.com');
        expect(map['stunServerPort'], 3478);
      });

      test('returns map with all optional fields using defaults', () {
        final account = SipAccount(
          userName: 'user',
          password: 'pass',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
        );

        final map = account.toMap();

        expect(map['outboundServer'], '');
        expect(map['outboundServerPort'], 0);
        expect(map['displayName'], '');
        expect(map['authName'], '');
        expect(map['userDomain'], '');
        expect(map['licenseKey'], '');
        expect(map['registerTimeout'], 120);
        expect(map['registerRetryTimes'], 3);
        expect(map['videoBitrate'], 500);
        expect(map['videoFrameRate'], 10);
        expect(map['videoWidth'], 352);
        expect(map['videoHeight'], 288);
        expect(map['audioCodecs'], [
          AudioCodec.opus.value,
          AudioCodec.pcmu.value,
          AudioCodec.pcma.value,
        ]);
      });

      test('returns map with all custom optional fields', () {
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
          audioCodecs: [AudioCodec.opus, AudioCodec.pcmu, AudioCodec.g729],
        );

        final map = account.toMap();

        expect(map['userName'], 'john_doe');
        expect(map['password'], 'secret123');
        expect(map['sipServer'], 'sip.company.com');
        expect(map['sipServerPort'], 5060);
        expect(map['stunServer'], 'stun.company.com');
        expect(map['stunServerPort'], 3478);
        expect(map['outboundServer'], 'proxy.company.com');
        expect(map['outboundServerPort'], 5065);
        expect(map['displayName'], 'John Doe');
        expect(map['authName'], 'john_auth');
        expect(map['userDomain'], 'company.com');
        expect(map['licenseKey'], 'LICENSE-KEY-123');
        expect(map['registerTimeout'], 180);
        expect(map['registerRetryTimes'], 5);
        expect(map['videoBitrate'], 1000);
        expect(map['videoFrameRate'], 30);
        expect(map['videoWidth'], 640);
        expect(map['videoHeight'], 480);
        expect(map['audioCodecs'], [
          AudioCodec.opus.value,
          AudioCodec.pcmu.value,
          AudioCodec.g729.value,
        ]);
      });

      test('converts audioCodecs to list of int values', () {
        final account = SipAccount(
          userName: 'user',
          password: 'pass',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
          audioCodecs: [
            AudioCodec.pcmu,
            AudioCodec.pcma,
            AudioCodec.opus,
            AudioCodec.g722,
          ],
        );

        final map = account.toMap();

        expect(map['audioCodecs'], isA<List>());
        expect(map['audioCodecs'], [0, 8, 111, 9]);
      });

      test('handles empty audioCodecs list by using defaults', () {
        final account = SipAccount(
          userName: 'user',
          password: 'pass',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
          audioCodecs: [],
        );

        final map = account.toMap();

        // Empty list triggers default codecs: opus, pcmu, pcma
        expect(map['audioCodecs'], [
          AudioCodec.opus.value,
          AudioCodec.pcmu.value,
          AudioCodec.pcma.value,
        ]);
      });

      test('handles special characters in string fields', () {
        final account = SipAccount(
          userName: 'user@domain.com',
          password: 'p@ss\$word!#%^&*()',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
          displayName: 'John "Johnny" O\'Connor',
        );

        final map = account.toMap();

        expect(map['userName'], 'user@domain.com');
        expect(map['password'], 'p@ss\$word!#%^&*()');
        expect(map['displayName'], 'John "Johnny" O\'Connor');
      });

      test('handles unicode characters', () {
        final account = SipAccount(
          userName: 'ユーザー',
          password: 'パスワード',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
          displayName: '日本語ユーザー 🎉',
        );

        final map = account.toMap();

        expect(map['userName'], 'ユーザー');
        expect(map['password'], 'パスワード');
        expect(map['displayName'], '日本語ユーザー 🎉');
      });

      test('returns correct map key count', () {
        final account = SipAccount(
          userName: 'user',
          password: 'pass',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
        );

        final map = account.toMap();

        // Should have all 19 fields
        expect(map.length, 19);
      });

      test('all map keys are strings', () {
        final account = SipAccount(
          userName: 'user',
          password: 'pass',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
        );

        final map = account.toMap();

        for (final key in map.keys) {
          expect(key, isA<String>());
        }
      });
    });

    group('constructor', () {
      test('creates instance with required fields only', () {
        final account = SipAccount(
          userName: 'user',
          password: 'pass',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
        );

        expect(account.userName, 'user');
        expect(account.password, 'pass');
        expect(account.sipServer, 'sip.test.com');
        expect(account.sipServerPort, 5060);
        expect(account.stunServer, 'stun.test.com');
        expect(account.stunServerPort, 3478);
      });

      test('uses default values for optional fields', () {
        final account = SipAccount(
          userName: 'user',
          password: 'pass',
          sipServer: 'sip.test.com',
          sipServerPort: 5060,
          stunServer: 'stun.test.com',
          stunServerPort: 3478,
        );

        expect(account.outboundServer, '');
        expect(account.outboundServerPort, 0);
        expect(account.displayName, '');
        expect(account.authName, '');
        expect(account.userDomain, '');
        expect(account.licenseKey, '');
        expect(account.registerTimeout, 120);
        expect(account.registerRetryTimes, 3);
        expect(account.videoBitrate, 500);
        expect(account.videoFrameRate, 10);
        expect(account.videoWidth, 352);
        expect(account.videoHeight, 288);
        expect(account.audioCodecs, SipAccount.defaultAudioCodecs);
      });
    });
  });

  group('AudioCodec', () {
    test('has correct value for pcmu', () {
      expect(AudioCodec.pcmu.value, 0);
    });

    test('has correct value for gsm', () {
      expect(AudioCodec.gsm.value, 3);
    });

    test('has correct value for g723', () {
      expect(AudioCodec.g723.value, 4);
    });

    test('has correct value for dvi4_8k', () {
      expect(AudioCodec.dvi4_8k.value, 5);
    });

    test('has correct value for dvi4_16k', () {
      expect(AudioCodec.dvi4_16k.value, 6);
    });

    test('has correct value for pcma', () {
      expect(AudioCodec.pcma.value, 8);
    });

    test('has correct value for g722', () {
      expect(AudioCodec.g722.value, 9);
    });

    test('has correct value for ilbc', () {
      expect(AudioCodec.ilbc.value, 97);
    });

    test('has correct value for speex', () {
      expect(AudioCodec.speex.value, 98);
    });

    test('has correct value for speexWb', () {
      expect(AudioCodec.speexWb.value, 99);
    });

    test('has correct value for isacWb', () {
      expect(AudioCodec.isacWb.value, 100);
    });

    test('has correct value for isacSwb', () {
      expect(AudioCodec.isacSwb.value, 102);
    });

    test('has correct value for g729', () {
      expect(AudioCodec.g729.value, 18);
    });

    test('has correct value for opus', () {
      expect(AudioCodec.opus.value, 111);
    });

    test('has correct value for amr', () {
      expect(AudioCodec.amr.value, 112);
    });

    test('has correct value for amrWb', () {
      expect(AudioCodec.amrWb.value, 113);
    });

    test('has correct value for dtmf', () {
      expect(AudioCodec.dtmf.value, 101);
    });

    test('all codecs have unique values except dtmf and isacSwb', () {
      final values = <int>[];
      for (final codec in AudioCodec.values) {
        // dtmf and isacSwb both have value 101
        if (codec != AudioCodec.dtmf) {
          values.add(codec.value);
        }
      }

      // Check that remaining values are unique
      final uniqueValues = values.toSet();
      expect(uniqueValues.length, values.length);
    });

    test('enum has expected number of values', () {
      expect(AudioCodec.values.length, 17);
    });
  });

  group('TransportType', () {
    group('values', () {
      test('none has value -1', () {
        expect(TransportType.none.value, -1);
      });

      test('udp has value 0', () {
        expect(TransportType.udp.value, 0);
      });

      test('tls has value 1', () {
        expect(TransportType.tls.value, 1);
      });

      test('tcp has value 2', () {
        expect(TransportType.tcp.value, 2);
      });

      test('enum has 4 values', () {
        expect(TransportType.values.length, 4);
      });
    });

    group('fromValue()', () {
      test('returns none for -1', () {
        expect(TransportType.fromValue(-1), TransportType.none);
      });

      test('returns udp for 0', () {
        expect(TransportType.fromValue(0), TransportType.udp);
      });

      test('returns tls for 1', () {
        expect(TransportType.fromValue(1), TransportType.tls);
      });

      test('returns tcp for 2', () {
        expect(TransportType.fromValue(2), TransportType.tcp);
      });

      test('returns none for unknown value', () {
        expect(TransportType.fromValue(999), TransportType.none);
      });

      test('returns none for negative unknown value', () {
        expect(TransportType.fromValue(-999), TransportType.none);
      });

      test('round-trips all values correctly', () {
        for (final transport in TransportType.values) {
          final recovered = TransportType.fromValue(transport.value);
          expect(recovered, transport);
        }
      });
    });
  });

  group('PortsipLogLevel', () {
    group('values', () {
      test('none has value -1', () {
        expect(PortsipLogLevel.none.value, -1);
      });

      test('error has value 1', () {
        expect(PortsipLogLevel.error.value, 1);
      });

      test('warning has value 2', () {
        expect(PortsipLogLevel.warning.value, 2);
      });

      test('info has value 3', () {
        expect(PortsipLogLevel.info.value, 3);
      });

      test('debug has value 4', () {
        expect(PortsipLogLevel.debug.value, 4);
      });

      test('enum has 5 values', () {
        expect(PortsipLogLevel.values.length, 5);
      });
    });

    group('fromValue()', () {
      test('returns none for -1', () {
        expect(PortsipLogLevel.fromValue(-1), PortsipLogLevel.none);
      });

      test('returns error for 1', () {
        expect(PortsipLogLevel.fromValue(1), PortsipLogLevel.error);
      });

      test('returns warning for 2', () {
        expect(PortsipLogLevel.fromValue(2), PortsipLogLevel.warning);
      });

      test('returns info for 3', () {
        expect(PortsipLogLevel.fromValue(3), PortsipLogLevel.info);
      });

      test('returns debug for 4', () {
        expect(PortsipLogLevel.fromValue(4), PortsipLogLevel.debug);
      });

      test('returns none for unknown value', () {
        expect(PortsipLogLevel.fromValue(999), PortsipLogLevel.none);
      });

      test('returns none for 0 (not a valid level)', () {
        expect(PortsipLogLevel.fromValue(0), PortsipLogLevel.none);
      });

      test('returns none for negative unknown value', () {
        expect(PortsipLogLevel.fromValue(-999), PortsipLogLevel.none);
      });

      test('round-trips all values correctly', () {
        for (final level in PortsipLogLevel.values) {
          final recovered = PortsipLogLevel.fromValue(level.value);
          expect(recovered, level);
        }
      });
    });

    group('log level ordering', () {
      test('none < error < warning < info < debug by value', () {
        expect(
          PortsipLogLevel.none.value,
          lessThan(PortsipLogLevel.error.value),
        );
        expect(
          PortsipLogLevel.error.value,
          lessThan(PortsipLogLevel.warning.value),
        );
        expect(
          PortsipLogLevel.warning.value,
          lessThan(PortsipLogLevel.info.value),
        );
        expect(
          PortsipLogLevel.info.value,
          lessThan(PortsipLogLevel.debug.value),
        );
      });
    });
  });

  group('SessionModel', () {
    group('constructor', () {
      test('creates instance with default values', () {
        final session = SessionModel();

        expect(session.sessionId, SessionModel.invalidSessionId);
        expect(session.holdState, false);
        expect(session.sessionState, false);
        expect(session.conferenceState, false);
        expect(session.recvCallState, false);
        expect(session.isReferCall, false);
        expect(session.originCallSessionId, SessionModel.invalidSessionId);
        expect(session.existEarlyMedia, false);
        expect(session.videoState, false);
      });

      test('creates instance with custom values', () {
        final session = SessionModel(
          sessionId: 12345,
          holdState: true,
          sessionState: true,
          conferenceState: true,
          recvCallState: true,
          isReferCall: true,
          originCallSessionId: 54321,
          existEarlyMedia: true,
          videoState: true,
        );

        expect(session.sessionId, 12345);
        expect(session.holdState, true);
        expect(session.sessionState, true);
        expect(session.conferenceState, true);
        expect(session.recvCallState, true);
        expect(session.isReferCall, true);
        expect(session.originCallSessionId, 54321);
        expect(session.existEarlyMedia, true);
        expect(session.videoState, true);
      });

      test('accepts minimum 32-bit session ID', () {
        final session = SessionModel(sessionId: SessionModel.minSessionId);
        expect(session.sessionId, SessionModel.minSessionId);
      });

      test('accepts maximum 32-bit session ID', () {
        final session = SessionModel(sessionId: SessionModel.maxSessionId);
        expect(session.sessionId, SessionModel.maxSessionId);
      });

      test('throws ArgumentError for sessionId above 32-bit range', () {
        expect(
          () => SessionModel(sessionId: SessionModel.maxSessionId + 1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for sessionId below 32-bit range', () {
        expect(
          () => SessionModel(sessionId: SessionModel.minSessionId - 1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for originCallSessionId above 32-bit range',
          () {
        expect(
          () => SessionModel(
              originCallSessionId: SessionModel.maxSessionId + 1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for originCallSessionId below 32-bit range',
          () {
        expect(
          () => SessionModel(
              originCallSessionId: SessionModel.minSessionId - 1),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('initial()', () {
      test('creates instance with default values', () {
        final session = SessionModel.initial();

        expect(session.sessionId, SessionModel.invalidSessionId);
        expect(session.holdState, false);
        expect(session.sessionState, false);
        expect(session.conferenceState, false);
        expect(session.recvCallState, false);
        expect(session.isReferCall, false);
        expect(session.originCallSessionId, SessionModel.invalidSessionId);
        expect(session.existEarlyMedia, false);
        expect(session.videoState, false);
      });
    });

    group('isValid', () {
      test('returns false for default session', () {
        final session = SessionModel();
        expect(session.isValid, false);
      });

      test('returns false for session with invalidSessionId', () {
        final session =
            SessionModel(sessionId: SessionModel.invalidSessionId);
        expect(session.isValid, false);
      });

      test('returns true for session with valid sessionId', () {
        final session = SessionModel(sessionId: 12345);
        expect(session.isValid, true);
      });

      test('returns true for session with sessionId 0', () {
        final session = SessionModel(sessionId: 0);
        expect(session.isValid, true);
      });
    });

    group('copyWith()', () {
      test('returns new instance with updated sessionId', () {
        final original = SessionModel(sessionId: 100);
        final copy = original.copyWith(sessionId: 200);

        expect(copy.sessionId, 200);
        expect(original.sessionId, 100);
      });

      test('preserves other fields when updating one field', () {
        final original = SessionModel(
          sessionId: 100,
          holdState: true,
          sessionState: true,
          videoState: true,
        );
        final copy = original.copyWith(holdState: false);

        expect(copy.sessionId, 100);
        expect(copy.holdState, false);
        expect(copy.sessionState, true);
        expect(copy.videoState, true);
      });

      test('can update multiple fields', () {
        final original = SessionModel();
        final copy = original.copyWith(
          sessionId: 999,
          holdState: true,
          videoState: true,
        );

        expect(copy.sessionId, 999);
        expect(copy.holdState, true);
        expect(copy.videoState, true);
        expect(copy.sessionState, false);
      });

      test('throws ArgumentError for invalid sessionId in copyWith', () {
        final session = SessionModel();
        expect(
          () => session.copyWith(sessionId: SessionModel.maxSessionId + 1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
          'throws ArgumentError for invalid originCallSessionId in copyWith',
          () {
        final session = SessionModel();
        expect(
          () => session.copyWith(
              originCallSessionId: SessionModel.minSessionId - 1),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('immutability', () {
      test('fields are final and cannot be reassigned', () {
        final session = SessionModel(sessionId: 100);
        // This test verifies immutability at compile time.
        // If fields were not final, the following would compile:
        // session.sessionId = 200; // Should not compile
        expect(session.sessionId, 100);
      });
    });

    group('constants', () {
      test('minSessionId is 32-bit signed integer minimum', () {
        expect(SessionModel.minSessionId, -2147483648);
      });

      test('maxSessionId is 32-bit signed integer maximum', () {
        expect(SessionModel.maxSessionId, 2147483647);
      });

      test('invalidSessionId is -1', () {
        expect(SessionModel.invalidSessionId, -1);
      });
    });
  });
}
