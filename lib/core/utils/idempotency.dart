import 'dart:math';

/// Utility to generate RFC 4122 compliant UUID v4 strings for Idempotency-Key headers.
class IdempotencyUtils {
  IdempotencyUtils._();

  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically secure UUID v4 string.
  /// Example: 'c4e3b789-231a-4c28-98e6-5cfa1034ba72'
  static String generateKey() {
    final values = List<int>.generate(16, (i) => _secureRandom.nextInt(256));

    // Set version to 4 (bits 12-15 of time_hi_and_version to 0100)
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant to 10xx (bits 6-7 of clock_seq_hi_and_reserved to 10)
    values[8] = (values[8] & 0x3f) | 0x80;

    final hexChars = values.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();

    return '${hexChars[0]}${hexChars[1]}${hexChars[2]}${hexChars[3]}-'
        '${hexChars[4]}${hexChars[5]}-'
        '${hexChars[6]}${hexChars[7]}-'
        '${hexChars[8]}${hexChars[9]}-'
        '${hexChars[10]}${hexChars[11]}${hexChars[12]}${hexChars[13]}${hexChars[14]}${hexChars[15]}';
  }

  /// Helper to return HTTP headers map with Idempotency-Key.
  static Map<String, String> header([String? existingKey]) {
    return {'Idempotency-Key': existingKey ?? generateKey()};
  }
}
