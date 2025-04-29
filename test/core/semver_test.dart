import 'package:emotic/core/semver.dart';
import 'package:test/test.dart';

void main() {
  group('SemVer string constructor', () {
    test('0 major version', () {
      expect(
        SemVer.fromString("0.0.1"),
        SemVer(major: 0, minor: 0, patch: 1),
      );
    });

    test('Wrong version string', () async {
      expect(
        () => SemVer.fromString("1.2.3.4"),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Typical version', () {
      expect(
        SemVer.fromString("1.4.15"),
        SemVer(major: 1, minor: 4, patch: 15),
      );
    });
  });

  group('SemVer operators', () {
    test('Greater than', () {
      expect(
        SemVer(major: 1, minor: 0, patch: 0) > SemVer.fromString("0.0.1"),
        isTrue,
      );
    });
    test("Less than or equal", () {
      expect(
          SemVer.fromString("0.0.10") <= SemVer.fromString("0.0.11"), isTrue);
    });
    test("Not greater", () {
      expect(
        SemVer.fromString("0.0.10") > SemVer.fromString("0.0.11"),
        isFalse,
      );
    });
  });
}
