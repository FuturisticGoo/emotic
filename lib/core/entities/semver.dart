import 'package:equatable/equatable.dart';

class SemVer extends Equatable {
  final int major;
  final int minor;
  final int patch;
  const SemVer({
    required this.major,
    required this.minor,
    required this.patch,
  });

  @override
  List<Object?> get props => [
        major,
        minor,
        patch,
      ];

  operator <(SemVer other) {
    return (major <= other.major) &&
        (minor <= other.minor) &&
        (patch < other.patch);
  }

  operator >(SemVer other) {
    return !(this <= other);
  }

  operator <=(SemVer other) {
    return (major <= other.major) &&
        (minor <= other.minor) &&
        (patch <= other.patch);
  }

  operator >=(SemVer other) {
    return !(this < other);
  }

  @override
  String toString() {
    return "$major.$minor.$patch";
  }

  factory SemVer.fromString(String versionString) {
    final split = versionString.split(".");
    if (split.length != 3) {
      throw ArgumentError(
        "The version string isn't in Semantic Versioning format",
      );
    } else {
      return SemVer(
        major: int.parse(split[0]),
        minor: int.parse(split[1]),
        patch: int.parse(split[2]),
      );
    }
  }
}
