import 'package:canteen_app/core/utils/idempotency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdempotencyUtils tests', () {
    test('generates valid UUID v4 formatted keys', () {
      final key = IdempotencyUtils.generateKey();
      expect(key, isNotEmpty);
      final uuidV4Regex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidV4Regex.hasMatch(key), isTrue);
    });

    test('generates unique keys across multiple invocations', () {
      final keys = List.generate(50, (_) => IdempotencyUtils.generateKey());
      final uniqueKeys = keys.toSet();
      expect(uniqueKeys.length, equals(50));
    });

    test('produces valid headers map', () {
      final headers = IdempotencyUtils.header('custom-key-123');
      expect(headers['Idempotency-Key'], equals('custom-key-123'));

      final dynamicHeaders = IdempotencyUtils.header();
      expect(dynamicHeaders['Idempotency-Key'], isNotEmpty);
    });
  });
}
