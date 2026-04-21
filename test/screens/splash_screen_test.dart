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

// Advance the fake clock past the 5-second navigation timer so no timer
// is left pending when the widget tree is disposed.
Future<void> _drainTimer(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setupMockAssets);

  group('SplashScreen', () {
    testWidgets('renders a full-width Image.asset', (tester) async {
      await tester.pumpWidget(_buildWithRouter(homeStub: const Scaffold()));
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.fitWidth);
      expect((image.image as AssetImage).assetName, 'asset/img/splash.png');
      expect(image.width, double.infinity);
      await _drainTimer(tester);
    });

    testWidgets('image is centered on screen', (tester) async {
      await tester.pumpWidget(_buildWithRouter(homeStub: const Scaffold()));
      await tester.pump();
      expect(find.byType(Center), findsOneWidget);
      await _drainTimer(tester);
    });

    testWidgets('does not navigate before 5 seconds', (tester) async {
      await tester.pumpWidget(
        _buildWithRouter(homeStub: const Scaffold(body: Text('home'))),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4, milliseconds: 999));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('home'), findsNothing);
      // drain the remaining timer
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('navigates to / after 5 seconds', (tester) async {
      await tester.pumpWidget(
        _buildWithRouter(homeStub: const Scaffold(body: Text('home'))),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });
  });
}
