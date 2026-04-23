import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reefmobile/firebase_options.dart';

void main() {
  group('DefaultFirebaseOptions.web', () {
    test('has correct apiKey', () {
      expect(DefaultFirebaseOptions.web.apiKey, 'AIzaSyD-3UF0xzn4kVVwGgHbn0hlssJ8_ozjAPs');
    });

    test('has correct appId', () {
      expect(DefaultFirebaseOptions.web.appId, '1:706308999246:web:6fc2bcd92f27d1bd1b1b1f');
    });

    test('has correct messagingSenderId', () {
      expect(DefaultFirebaseOptions.web.messagingSenderId, '706308999246');
    });

    test('has correct projectId', () {
      expect(DefaultFirebaseOptions.web.projectId, 'reef-guide');
    });

    test('has correct authDomain', () {
      expect(DefaultFirebaseOptions.web.authDomain, 'reef-guide.firebaseapp.com');
    });

    test('has correct storageBucket', () {
      expect(DefaultFirebaseOptions.web.storageBucket, 'reef-guide.firebasestorage.app');
    });

    test('has correct measurementId', () {
      expect(DefaultFirebaseOptions.web.measurementId, 'G-4FHR850TJZ');
    });
  });

  group('DefaultFirebaseOptions.currentPlatform', () {
    // Tests run on the host machine (not a browser), so kIsWeb is false and
    // currentPlatform should throw UnsupportedError for every TargetPlatform.

    for (final platform in TargetPlatform.values) {
      test('throws UnsupportedError on $platform', () {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        expect(() => DefaultFirebaseOptions.currentPlatform, throwsUnsupportedError);
      });
    }
  });
}
