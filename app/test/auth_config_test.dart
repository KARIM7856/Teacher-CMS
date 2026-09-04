import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_cms_app/src/core/config/auth_config.dart';

void main() {
  group('studentEmailForUsername', () {
    test('builds the synthetic address, normalized', () {
      expect(
        studentEmailForUsername('  Ahmed123 '),
        'ahmed123@$kStudentEmailDomain',
      );
    });
  });

  group('usernameFromStudentEmail', () {
    test('recovers the username', () {
      expect(
        usernameFromStudentEmail('abdullah24819@$kStudentEmailDomain'),
        'abdullah24819',
      );
    });

    test('round-trips with studentEmailForUsername', () {
      const String username = 'sara.omar';
      expect(
        usernameFromStudentEmail(studentEmailForUsername(username)),
        username,
      );
    });

    test('ignores an address from another domain', () {
      expect(usernameFromStudentEmail('teacher@example.com'), isNull);
    });

    test('returns null for missing or empty input', () {
      expect(usernameFromStudentEmail(null), isNull);
      expect(usernameFromStudentEmail(''), isNull);
    });

    test('returns null when there is no local part', () {
      expect(usernameFromStudentEmail('@$kStudentEmailDomain'), isNull);
    });
  });
}
