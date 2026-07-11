import 'package:canteen_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated Firebase options are available for the current platform', () {
    final options = DefaultFirebaseOptions.currentPlatform;

    expect(options.apiKey, isNotEmpty);
    expect(options.appId, isNotEmpty);
    expect(options.projectId, equals('canteen-app-e1c8d'));
  });
}
