import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reefmobile/screens/splash_screen.dart';

import '../helpers/mock_assets.dart';

Widget _buildWithRouter({required Widget homeStub}) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/', builder: (_, __) => homeStub),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

// Advance past the minimum splash duration used by SplashScreen.
Future<void> _drainTimer(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setupMockAssets);

  group('SplashScreen', () {
    testWidgets('renders the splash image', (tester) async {
      await tester.pumpWidget(_buildWithRouter(homeStub: const Scaffold()));
      await tester.pump();
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
        images.any(
          (img) =>
              img.image is AssetImage &&
              (img.image as AssetImage).assetName == 'asset/img/splash.png',
        ),
        isTrue,
      );
      await _drainTimer(tester);
    });

    testWidgets('shows a progress indicator', (tester) async {
      await tester.pumpWidget(_buildWithRouter(homeStub: const Scaffold()));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      await _drainTimer(tester);
    });

    testWidgets('navigates to / after the minimum splash duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(homeStub: const Scaffold(body: Text('home'))),
      );
      await tester.pump();
      // On non-Android hosts the service completes immediately; the screen
      // still holds for the minimum splash duration before advancing.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });
  });
}
