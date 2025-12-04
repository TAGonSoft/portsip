import 'package:flutter_test/flutter_test.dart';
import 'package:portsip/models/portsip_events.dart';

void main() {
  group('PortsipEvent', () {
    test('creates event with name and data', () {
      final event = PortsipEvent('testEvent', {'key': 'value'});

      expect(event.name, 'testEvent');
      expect(event.data, {'key': 'value'});
    });

    test('creates event with null data', () {
      final event = PortsipEvent('testEvent', null);

      expect(event.name, 'testEvent');
      expect(event.data, isNull);
    });

    test('sets timestamp on creation', () {
      final before = DateTime.now();
      final event = PortsipEvent('testEvent', null);
      final after = DateTime.now();

      expect(event.timestamp.isAfter(before) || event.timestamp.isAtSameMomentAs(before), isTrue);
      expect(event.timestamp.isBefore(after) || event.timestamp.isAtSameMomentAs(after), isTrue);
    });

    test('toString returns expected format', () {
      final event = PortsipEvent('testEvent', {'key': 'value'});
      expect(event.toString(), 'PortsipEvent(testEvent, {key: value})');
    });

    test('toString handles null data', () {
      final event = PortsipEvent('testEvent', null);
      expect(event.toString(), 'PortsipEvent(testEvent, null)');
    });
  });

  group('Registration Events', () {
    group('RegisterSuccessEvent', () {
      test('creates event with correct properties', () {
        final event = RegisterSuccessEvent('OK', 200);

        expect(event.name, 'onRegisterSuccess');
        expect(event.statusText, 'OK');
        expect(event.statusCode, 200);
        expect(event.data, {'statusText': 'OK', 'statusCode': 200});
      });

      test('handles empty status text', () {
        final event = RegisterSuccessEvent('', 200);

        expect(event.statusText, '');
        expect(event.statusCode, 200);
      });
    });

    group('RegisterFailureEvent', () {
      test('creates event with correct properties', () {
        final event = RegisterFailureEvent('Unauthorized', 401);

        expect(event.name, 'onRegisterFailure');
        expect(event.statusText, 'Unauthorized');
        expect(event.statusCode, 401);
        expect(event.data, {'statusText': 'Unauthorized', 'statusCode': 401});
      });

      test('handles various error codes', () {
        final event403 = RegisterFailureEvent('Forbidden', 403);
        final event404 = RegisterFailureEvent('Not Found', 404);

        expect(event403.statusCode, 403);
        expect(event404.statusCode, 404);
      });
    });
  });

  group('Call Events', () {
    group('InviteTryingEvent', () {
      test('creates event with correct properties', () {
        final event = InviteTryingEvent(12345);

        expect(event.name, 'onInviteTrying');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });

    group('InviteRingingEvent', () {
      test('creates event with correct properties', () {
        final event = InviteRingingEvent(12345);

        expect(event.name, 'onInviteRinging');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });

    group('InviteAnsweredEvent', () {
      test('creates event with correct properties', () {
        final event = InviteAnsweredEvent(12345);

        expect(event.name, 'onInviteAnswered');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });

    group('InviteConnectedEvent', () {
      test('creates event with correct properties', () {
        final event = InviteConnectedEvent(12345);

        expect(event.name, 'onInviteConnected');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });

    group('InviteClosedEvent', () {
      test('creates event with correct properties', () {
        final event = InviteClosedEvent(12345);

        expect(event.name, 'onInviteClosed');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });

    group('InviteFailureEvent', () {
      test('creates event with correct properties', () {
        final event = InviteFailureEvent(12345, 'Busy Here', 486);

        expect(event.name, 'onInviteFailure');
        expect(event.sessionId, 12345);
        expect(event.reason, 'Busy Here');
        expect(event.code, 486);
        expect(event.data, {
          'sessionId': 12345,
          'reason': 'Busy Here',
          'code': 486,
        });
      });

      test('handles various failure codes', () {
        final event480 = InviteFailureEvent(1, 'Temporarily Unavailable', 480);
        final event603 = InviteFailureEvent(2, 'Decline', 603);

        expect(event480.code, 480);
        expect(event603.code, 603);
      });
    });
  });

  group('Remote State Events', () {
    group('RemoteHoldEvent', () {
      test('creates event with correct properties', () {
        final event = RemoteHoldEvent(12345);

        expect(event.name, 'onRemoteHold');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });

    group('RemoteUnHoldEvent', () {
      test('creates event with correct properties', () {
        final event = RemoteUnHoldEvent(12345);

        expect(event.name, 'onRemoteUnHold');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });
  });

  group('Audio Session Events', () {
    group('AudioSessionErrorEvent', () {
      test('creates event with correct properties', () {
        final event = AudioSessionErrorEvent(
          'Failed to configure audio session',
          560557684,
          'NSOSStatusErrorDomain',
        );

        expect(event.name, 'onAudioSessionError');
        expect(event.error, 'Failed to configure audio session');
        expect(event.errorCode, 560557684);
        expect(event.errorDomain, 'NSOSStatusErrorDomain');
        expect(event.data, {
          'error': 'Failed to configure audio session',
          'errorCode': 560557684,
          'errorDomain': 'NSOSStatusErrorDomain',
        });
      });
    });
  });

  group('CallKit Events', () {
    group('CallKitHoldEvent', () {
      test('creates event with correct properties', () {
        final event = CallKitHoldEvent(12345, true);

        expect(event.name, 'onCallKitHold');
        expect(event.sessionId, 12345);
        expect(event.onHold, true);
        expect(event.data, {'sessionId': 12345, 'onHold': true});
      });

      test('handles onHold=false', () {
        final event = CallKitHoldEvent(12345, false);
        expect(event.onHold, false);
      });
    });

    group('CallKitMuteEvent', () {
      test('creates event with correct properties', () {
        final event = CallKitMuteEvent(12345, true);

        expect(event.name, 'onCallKitMute');
        expect(event.sessionId, 12345);
        expect(event.muted, true);
        expect(event.data, {'sessionId': 12345, 'muted': true});
      });

      test('handles muted=false', () {
        final event = CallKitMuteEvent(12345, false);
        expect(event.muted, false);
      });
    });

    group('CallKitSpeakerEvent', () {
      test('creates event with correct properties', () {
        final event = CallKitSpeakerEvent(12345, true);

        expect(event.name, 'onCallKitSpeaker');
        expect(event.sessionId, 12345);
        expect(event.enableSpeaker, true);
        expect(event.data, {'sessionId': 12345, 'enableSpeaker': true});
      });

      test('handles enableSpeaker=false', () {
        final event = CallKitSpeakerEvent(12345, false);
        expect(event.enableSpeaker, false);
      });
    });

    group('CallKitDTMFEvent', () {
      test('creates event with correct properties', () {
        final event = CallKitDTMFEvent(12345, '123#');

        expect(event.name, 'onCallKitDTMF');
        expect(event.sessionId, 12345);
        expect(event.digits, '123#');
        expect(event.data, {'sessionId': 12345, 'digits': '123#'});
      });

      test('handles empty digits', () {
        final event = CallKitDTMFEvent(12345, '');
        expect(event.digits, '');
      });
    });

    group('CallKitEndCallEvent', () {
      test('creates event with correct properties', () {
        final event = CallKitEndCallEvent(12345);

        expect(event.name, 'onCallKitEndCall');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });

    group('CallKitFailureEvent', () {
      test('creates event with correct properties', () {
        final event = CallKitFailureEvent(12345, 'Failed to report call');

        expect(event.name, 'onCallKitFailure');
        expect(event.sessionId, 12345);
        expect(event.error, 'Failed to report call');
        expect(event.data, {'sessionId': 12345, 'error': 'Failed to report call'});
      });
    });
  });

  group('ConnectionService Events', () {
    group('ConnectionServiceEndCallEvent', () {
      test('creates event with correct properties', () {
        final event = ConnectionServiceEndCallEvent(12345);

        expect(event.name, 'onConnectionServiceEndCall');
        expect(event.sessionId, 12345);
        expect(event.data, {'sessionId': 12345});
      });
    });

    group('ConnectionServiceHoldEvent', () {
      test('creates event with correct properties', () {
        final event = ConnectionServiceHoldEvent(12345, true);

        expect(event.name, 'onConnectionServiceHold');
        expect(event.sessionId, 12345);
        expect(event.onHold, true);
        expect(event.data, {'sessionId': 12345, 'onHold': true});
      });

      test('handles onHold=false', () {
        final event = ConnectionServiceHoldEvent(12345, false);
        expect(event.onHold, false);
      });
    });

    group('ConnectionServiceMuteEvent', () {
      test('creates event with correct properties', () {
        final event = ConnectionServiceMuteEvent(12345, true);

        expect(event.name, 'onConnectionServiceMute');
        expect(event.sessionId, 12345);
        expect(event.muted, true);
        expect(event.data, {'sessionId': 12345, 'muted': true});
      });

      test('handles muted=false', () {
        final event = ConnectionServiceMuteEvent(12345, false);
        expect(event.muted, false);
      });
    });

    group('ConnectionServiceSpeakerEvent', () {
      test('creates event with correct properties', () {
        final event = ConnectionServiceSpeakerEvent(12345, true);

        expect(event.name, 'onConnectionServiceSpeaker');
        expect(event.sessionId, 12345);
        expect(event.enableSpeaker, true);
        expect(event.data, {'sessionId': 12345, 'enableSpeaker': true});
      });

      test('handles enableSpeaker=false', () {
        final event = ConnectionServiceSpeakerEvent(12345, false);
        expect(event.enableSpeaker, false);
      });
    });

    group('ConnectionServiceDTMFEvent', () {
      test('creates event with correct properties', () {
        final event = ConnectionServiceDTMFEvent(12345, '456*');

        expect(event.name, 'onConnectionServiceDTMF');
        expect(event.sessionId, 12345);
        expect(event.digits, '456*');
        expect(event.data, {'sessionId': 12345, 'digits': '456*'});
      });
    });

    group('ConnectionServiceFailureEvent', () {
      test('creates event with correct properties', () {
        final event = ConnectionServiceFailureEvent(12345, 'Connection failed');

        expect(event.name, 'onConnectionServiceFailure');
        expect(event.sessionId, 12345);
        expect(event.message, 'Connection failed');
        expect(event.data, {'sessionId': 12345, 'message': 'Connection failed'});
      });

      test('handles null sessionId', () {
        final event = ConnectionServiceFailureEvent(null, 'General failure');

        expect(event.sessionId, isNull);
        expect(event.message, 'General failure');
      });
    });
  });

  group('toTypedEvent', () {
    group('Registration Events', () {
      test('converts onRegisterSuccess', () {
        final generic = PortsipEvent('onRegisterSuccess', {
          'statusText': 'OK',
          'statusCode': 200,
        });

        final typed = toTypedEvent(generic);

        expect(typed, isA<RegisterSuccessEvent>());
        final event = typed as RegisterSuccessEvent;
        expect(event.statusText, 'OK');
        expect(event.statusCode, 200);
      });

      test('converts onRegisterFailure', () {
        final generic = PortsipEvent('onRegisterFailure', {
          'statusText': 'Unauthorized',
          'statusCode': 401,
        });

        final typed = toTypedEvent(generic);

        expect(typed, isA<RegisterFailureEvent>());
        final event = typed as RegisterFailureEvent;
        expect(event.statusText, 'Unauthorized');
        expect(event.statusCode, 401);
      });

      test('handles missing data in onRegisterSuccess', () {
        final generic = PortsipEvent('onRegisterSuccess', null);

        final typed = toTypedEvent(generic);

        expect(typed, isA<RegisterSuccessEvent>());
        final event = typed as RegisterSuccessEvent;
        expect(event.statusText, '');
        expect(event.statusCode, 0);
      });
    });

    group('Call Events', () {
      test('converts onInviteTrying', () {
        final generic = PortsipEvent('onInviteTrying', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<InviteTryingEvent>());
        expect((typed as InviteTryingEvent).sessionId, 12345);
      });

      test('converts onInviteRinging', () {
        final generic = PortsipEvent('onInviteRinging', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<InviteRingingEvent>());
        expect((typed as InviteRingingEvent).sessionId, 12345);
      });

      test('converts onInviteAnswered', () {
        final generic = PortsipEvent('onInviteAnswered', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<InviteAnsweredEvent>());
        expect((typed as InviteAnsweredEvent).sessionId, 12345);
      });

      test('converts onInviteConnected', () {
        final generic = PortsipEvent('onInviteConnected', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<InviteConnectedEvent>());
        expect((typed as InviteConnectedEvent).sessionId, 12345);
      });

      test('converts onInviteClosed', () {
        final generic = PortsipEvent('onInviteClosed', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<InviteClosedEvent>());
        expect((typed as InviteClosedEvent).sessionId, 12345);
      });

      test('converts onInviteFailure', () {
        final generic = PortsipEvent('onInviteFailure', {
          'sessionId': 12345,
          'reason': 'Busy',
          'code': 486,
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<InviteFailureEvent>());
        final event = typed as InviteFailureEvent;
        expect(event.sessionId, 12345);
        expect(event.reason, 'Busy');
        expect(event.code, 486);
      });

      test('handles missing sessionId in call events', () {
        final generic = PortsipEvent('onInviteTrying', null);
        final typed = toTypedEvent(generic);

        expect(typed, isA<InviteTryingEvent>());
        expect((typed as InviteTryingEvent).sessionId, -1);
      });
    });

    group('Remote State Events', () {
      test('converts onRemoteHold', () {
        final generic = PortsipEvent('onRemoteHold', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<RemoteHoldEvent>());
        expect((typed as RemoteHoldEvent).sessionId, 12345);
      });

      test('converts onRemoteUnHold', () {
        final generic = PortsipEvent('onRemoteUnHold', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<RemoteUnHoldEvent>());
        expect((typed as RemoteUnHoldEvent).sessionId, 12345);
      });
    });

    group('Audio Session Events', () {
      test('converts onAudioSessionError', () {
        final generic = PortsipEvent('onAudioSessionError', {
          'error': 'Audio error',
          'errorCode': 123,
          'errorDomain': 'TestDomain',
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<AudioSessionErrorEvent>());
        final event = typed as AudioSessionErrorEvent;
        expect(event.error, 'Audio error');
        expect(event.errorCode, 123);
        expect(event.errorDomain, 'TestDomain');
      });
    });

    group('CallKit Events', () {
      test('converts onCallKitHold', () {
        final generic = PortsipEvent('onCallKitHold', {
          'sessionId': 12345,
          'onHold': true,
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<CallKitHoldEvent>());
        final event = typed as CallKitHoldEvent;
        expect(event.sessionId, 12345);
        expect(event.onHold, true);
      });

      test('converts onCallKitMute', () {
        final generic = PortsipEvent('onCallKitMute', {
          'sessionId': 12345,
          'muted': true,
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<CallKitMuteEvent>());
        final event = typed as CallKitMuteEvent;
        expect(event.sessionId, 12345);
        expect(event.muted, true);
      });

      test('converts onCallKitSpeaker', () {
        final generic = PortsipEvent('onCallKitSpeaker', {
          'sessionId': 12345,
          'enableSpeaker': true,
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<CallKitSpeakerEvent>());
        final event = typed as CallKitSpeakerEvent;
        expect(event.sessionId, 12345);
        expect(event.enableSpeaker, true);
      });

      test('converts onCallKitDTMF', () {
        final generic = PortsipEvent('onCallKitDTMF', {
          'sessionId': 12345,
          'digits': '123',
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<CallKitDTMFEvent>());
        final event = typed as CallKitDTMFEvent;
        expect(event.sessionId, 12345);
        expect(event.digits, '123');
      });

      test('converts onCallKitEndCall', () {
        final generic = PortsipEvent('onCallKitEndCall', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<CallKitEndCallEvent>());
        expect((typed as CallKitEndCallEvent).sessionId, 12345);
      });

      test('converts onCallKitFailure', () {
        final generic = PortsipEvent('onCallKitFailure', {
          'sessionId': 12345,
          'error': 'Failed',
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<CallKitFailureEvent>());
        final event = typed as CallKitFailureEvent;
        expect(event.sessionId, 12345);
        expect(event.error, 'Failed');
      });
    });

    group('ConnectionService Events', () {
      test('converts onConnectionServiceEndCall', () {
        final generic = PortsipEvent('onConnectionServiceEndCall', {'sessionId': 12345});
        final typed = toTypedEvent(generic);

        expect(typed, isA<ConnectionServiceEndCallEvent>());
        expect((typed as ConnectionServiceEndCallEvent).sessionId, 12345);
      });

      test('converts onConnectionServiceHold', () {
        final generic = PortsipEvent('onConnectionServiceHold', {
          'sessionId': 12345,
          'onHold': true,
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<ConnectionServiceHoldEvent>());
        final event = typed as ConnectionServiceHoldEvent;
        expect(event.sessionId, 12345);
        expect(event.onHold, true);
      });

      test('converts onConnectionServiceMute', () {
        final generic = PortsipEvent('onConnectionServiceMute', {
          'sessionId': 12345,
          'muted': false,
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<ConnectionServiceMuteEvent>());
        final event = typed as ConnectionServiceMuteEvent;
        expect(event.sessionId, 12345);
        expect(event.muted, false);
      });

      test('converts onConnectionServiceSpeaker', () {
        final generic = PortsipEvent('onConnectionServiceSpeaker', {
          'sessionId': 12345,
          'enableSpeaker': false,
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<ConnectionServiceSpeakerEvent>());
        final event = typed as ConnectionServiceSpeakerEvent;
        expect(event.sessionId, 12345);
        expect(event.enableSpeaker, false);
      });

      test('converts onConnectionServiceDTMF', () {
        final generic = PortsipEvent('onConnectionServiceDTMF', {
          'sessionId': 12345,
          'digits': '789',
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<ConnectionServiceDTMFEvent>());
        final event = typed as ConnectionServiceDTMFEvent;
        expect(event.sessionId, 12345);
        expect(event.digits, '789');
      });

      test('converts onConnectionServiceFailure', () {
        final generic = PortsipEvent('onConnectionServiceFailure', {
          'sessionId': 12345,
          'message': 'Connection failed',
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<ConnectionServiceFailureEvent>());
        final event = typed as ConnectionServiceFailureEvent;
        expect(event.sessionId, 12345);
        expect(event.message, 'Connection failed');
      });

      test('handles null sessionId in ConnectionServiceFailure', () {
        final generic = PortsipEvent('onConnectionServiceFailure', {
          'sessionId': null,
          'message': 'General failure',
        });
        final typed = toTypedEvent(generic);

        expect(typed, isA<ConnectionServiceFailureEvent>());
        final event = typed as ConnectionServiceFailureEvent;
        expect(event.sessionId, isNull);
      });
    });

    group('Unknown Events', () {
      test('returns original event for unknown event name', () {
        final generic = PortsipEvent('onUnknownEvent', {'foo': 'bar'});
        final typed = toTypedEvent(generic);

        expect(typed, same(generic));
        expect(typed.name, 'onUnknownEvent');
        expect(typed.data, {'foo': 'bar'});
      });

      test('returns original event for custom event', () {
        final generic = PortsipEvent('onCustomEvent', null);
        final typed = toTypedEvent(generic);

        expect(typed, same(generic));
      });
    });
  });
}
