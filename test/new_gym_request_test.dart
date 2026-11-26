import 'package:flutter_test/flutter_test.dart';
import 'package:team_flo_app/models/gym_model.dart';
import 'package:team_flo_app/models/new_gym_request.dart';

/// PLATFORM ADMIN (Milestone 1): tests for NewGymRequest.
///
/// Run with:   flutter test test/new_gym_request_test.dart
///
/// These only check valid (null) vs not valid (a message), so the wording
/// of your error messages is up to you.
void main() {
  group('validateGymId', () {
    test('accepts good IDs', () {
      for (final id in ['teamflo', 'team-flo-2', 'abc', 'a' * 30]) {
        expect(NewGymRequest.validateGymId(id), isNull, reason: '"$id" should be valid');
      }
    });

    test('rejects bad IDs', () {
      for (final id in [null, '', 'ab', 'a' * 31, 'Team', 'team flo', '-team', 'team-', 'team--flo', 'team_flo']) {
        expect(NewGymRequest.validateGymId(id), isNotNull, reason: '"$id" should be rejected');
      }
    });
  });

  group('validateName', () {
    test('accepts good names', () {
      expect(NewGymRequest.validateName('Team Flo BJJ'), isNull);
      expect(NewGymRequest.validateName('x' * 60), isNull);
    });

    test('rejects bad names', () {
      for (final name in [null, '', '   ', 'x' * 61]) {
        expect(NewGymRequest.validateName(name), isNotNull, reason: '"$name" should be rejected');
      }
    });
  });

  group('validateEmail', () {
    test('accepts good emails', () {
      for (final email in ['owner@gym.com', '  owner@gym.com  ', 'first.last@my-gym.co.uk']) {
        expect(NewGymRequest.validateEmail(email), isNull, reason: '"$email" should be valid');
      }
    });

    test('rejects bad emails', () {
      for (final email in [null, '', 'owner', 'owner@', '@gym.com', 'owner@gym', 'own er@gym.com']) {
        expect(NewGymRequest.validateEmail(email), isNotNull, reason: '"$email" should be rejected');
      }
    });
  });

  group('validateHexColor', () {
    test('optional: empty is fine', () {
      expect(NewGymRequest.validateHexColor(null), isNull);
      expect(NewGymRequest.validateHexColor(''), isNull);
    });

    test('accepts readable colors', () {
      expect(NewGymRequest.validateHexColor('#1E88E5'), isNull);
      expect(NewGymRequest.validateHexColor('1e88e5'), isNull);
    });

    test('rejects unreadable colors', () {
      for (final c in ['#12345', 'blue', '#GGGGGG']) {
        expect(NewGymRequest.validateHexColor(c), isNotNull, reason: '"$c" should be rejected');
      }
    });
  });

  group('suggestGymId (bonus)', () {
    test('turns names into IDs', () {
      expect(NewGymRequest.suggestGymId('Team Flo BJJ'), 'team-flo-bjj');
      expect(NewGymRequest.suggestGymId('  Gracie   Barra! '), 'gracie-barra');
      expect(NewGymRequest.suggestGymId("Joe's BJJ"), 'joes-bjj');
    });

    test('suggestions pass validateGymId', () {
      final id = NewGymRequest.suggestGymId('Team Flo BJJ');
      expect(NewGymRequest.validateGymId(id), isNull);
    });
  });

  group('toMap', () {
    test('cleans up the values', () {
      const request = NewGymRequest(
        gymId: ' test-gym ',
        name: ' Test Gym ',
        plan: GymPlans.academy,
        ownerEmail: ' Owner@Gym.COM ',
      );
      final map = request.toMap();

      expect(map['gymId'], 'test-gym');
      expect(map['name'], 'Test Gym');
      expect(map['plan'], 'academy');
      expect(map['ownerEmail'], 'owner@gym.com');
    });

    test('leaves out empty optional fields', () {
      const request = NewGymRequest(
        gymId: 'test-gym',
        name: 'Test Gym',
        plan: GymPlans.community,
        ownerEmail: 'owner@gym.com',
        primaryColor: '',
      );
      final map = request.toMap();

      expect(map.containsKey('primaryColor'), isFalse);
      expect(map.containsKey('instagramHandle'), isFalse);
    });

    test('keeps optional fields that are filled in', () {
      const request = NewGymRequest(
        gymId: 'test-gym',
        name: 'Test Gym',
        plan: GymPlans.branded,
        ownerEmail: 'owner@gym.com',
        primaryColor: '#1E88E5',
        instagramHandle: 'testgym',
      );
      final map = request.toMap();

      expect(map['primaryColor'], '#1E88E5');
      expect(map['instagramHandle'], 'testgym');
    });
  });
}