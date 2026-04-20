import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reefmobile/widgets/app_drawer.dart';

Widget _buildApp() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Test App')),
          drawer: const AppDrawer(),
          body: const SizedBox(),
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const Scaffold(body: Text('Search')),
      ),
      GoRoute(
        path: '/info',
        builder: (_, __) => const Scaffold(body: Text('Info')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<void> _openDrawer(WidgetTester tester) async {
  final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
  scaffold.openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  group('AppDrawer', () {
    testWidgets('renders the app title in the header', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      expect(find.text("Florent's Reef Guide"), findsOneWidget);
    });

    testWidgets('renders the Home tile', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('renders the Search species tile', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      expect(find.text('Search species'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders the Contact tile', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      expect(find.text('Contact'), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    });

    testWidgets('renders the Desktop Version tile', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      expect(find.text('Desktop Version'), findsOneWidget);
      expect(find.byIcon(Icons.computer_outlined), findsOneWidget);
    });

    testWidgets('renders the About tile', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      expect(find.text('About'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('tapping Home closes the drawer and stays on /', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      // Drawer is closed; tile text gone from tree.
      expect(find.text("Florent's Reef Guide"), findsNothing);
    });

    testWidgets('tapping Search species navigates to /search', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      await tester.tap(find.text('Search species'));
      await tester.pumpAndSettle();
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('tapping About navigates to /info', (tester) async {
      await tester.pumpWidget(_buildApp());
      await _openDrawer(tester);
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      expect(find.text('Info'), findsOneWidget);
    });
  });
}
