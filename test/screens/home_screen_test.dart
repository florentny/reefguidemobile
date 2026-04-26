import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/screens/home_screen.dart';
import 'package:reefmobile/widgets/app_drawer.dart';

import '../helpers/mock_assets.dart';

// Plain MaterialApp — fine for tests that don't trigger navigation.
Widget _buildApp(AppState state) => ChangeNotifierProvider<AppState>.value(
  value: state,
  child: const MaterialApp(home: HomeScreen()),
);

// GoRouter wrapper — required when tapping buttons that call context.push().
Widget _buildWithRouter(AppState state, {List<GoRoute> extra = const []}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/browse',
        builder: (_, __) => const Scaffold(body: Text('browse')),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const Scaffold(body: Text('search')),
      ),
      ...extra,
    ],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp.router(routerConfig: router),
  );
}

// The default 800×600 viewport clips the scrollable body — the two radio
// columns (6+7 items) plus buttons exceed 600 px.  1200 px fits everything.
void _setTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// Mount with a tall viewport so all interactive elements are hittable.
Future<void> _mount(WidgetTester tester, Widget app) async {
  _setTallViewport(tester);
  await tester.pumpWidget(app);
}

void main() {
  setUpAll(setupMockAssets);

  group('HomeScreen', () {
    // ── Static rendering ──────────────────────────────────────────────────

    testWidgets('renders the title text', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      expect(find.text("Florent's guide to the marine life of the tropical reefs"), findsOneWidget);
    });

    testWidgets('scaffold background is blue[900]', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.blue[900]);
    });

    testWidgets('has a drawer (AppDrawer)', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isA<AppDrawer>());
    });

    testWidgets('shows "Browse by categories" button', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      expect(find.text('Browse by categories'), findsOneWidget);
    });

    testWidgets('shows "Search by species name" button', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      expect(find.text('Search by species name'), findsOneWidget);
    });

    testWidgets('shows copyright footer', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      expect(find.textContaining('Florent Charpin'), findsOneWidget);
    });

    testWidgets('renders all superCat labels in radio column', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      for (final label in ['Fish', 'Invertebrates', 'Sponges', 'Corals', 'Algae', 'Mammals and Reptiles']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('renders all region labels in radio column', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      for (final name in regionNames) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('default superCat "Fish" is shown as selected (bold, white)', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      final fishText = tester.widget<Text>(find.text('Fish'));
      expect(fishText.style?.fontWeight, FontWeight.w600);
      expect(fishText.style?.color, Colors.white);
    });

    testWidgets('non-selected superCat label is dimmed', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      final coralText = tester.widget<Text>(find.text('Corals'));
      expect(coralText.style?.color, Colors.white70);
      expect(coralText.style?.fontWeight, FontWeight.normal);
    });

    testWidgets('default region "All Regions" is shown as selected', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      final allRegionsText = tester.widget<Text>(find.text('All Regions'));
      expect(allRegionsText.style?.fontWeight, FontWeight.w600);
      expect(allRegionsText.style?.color, Colors.white);
    });

    // ── Interaction — tall viewport required for off-screen elements ───────

    testWidgets('tapping a superCat updates AppState', (tester) async {
      final state = AppState();
      await _mount(tester, _buildApp(state));
      await tester.tap(find.text('Corals'));
      await tester.pump();
      expect(state.selectedSuperCat, 'Corals');
    });

    testWidgets('tapping a superCat highlights it as selected', (tester) async {
      final state = AppState();
      await _mount(tester, _buildApp(state));
      await tester.tap(find.text('Corals'));
      await tester.pump();
      final coralText = tester.widget<Text>(find.text('Corals'));
      expect(coralText.style?.fontWeight, FontWeight.w600);
      expect(coralText.style?.color, Colors.white);
    });

    testWidgets('tapping a region updates AppState', (tester) async {
      final state = AppState();
      await _mount(tester, _buildApp(state));
      await tester.tap(find.text('Hawaii'));
      await tester.pump();
      expect(state.selectedRegion, 4);
    });

    testWidgets('tapping a region highlights it as selected', (tester) async {
      final state = AppState();
      await _mount(tester, _buildApp(state));
      await tester.tap(find.text('Hawaii'));
      await tester.pump();
      final hawaiiText = tester.widget<Text>(find.text('Hawaii'));
      expect(hawaiiText.style?.fontWeight, FontWeight.w600);
      expect(hawaiiText.style?.color, Colors.white);
    });

    testWidgets('"Browse by categories" navigates to /browse', (tester) async {
      await _mount(tester, _buildWithRouter(AppState()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse by categories'));
      await tester.pumpAndSettle();
      expect(find.text('browse'), findsOneWidget);
    });

    testWidgets('"Search by species name" navigates to /search', (tester) async {
      await _mount(tester, _buildWithRouter(AppState()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search by species name'));
      await tester.pumpAndSettle();
      expect(find.text('search'), findsOneWidget);
    });

    testWidgets('Browse button encodes region and superCat in query params', (tester) async {
      final state = AppState()
        ..setRegion(2)
        ..setSuperCat('Corals');
      String? pushedUri;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/browse',
            builder: (_, routeState) {
              pushedUri = routeState.uri.toString();
              return const Scaffold(body: Text('browse'));
            },
          ),
          GoRoute(
            path: '/search',
            builder: (_, __) => const Scaffold(body: Text('search')),
          ),
        ],
      );
      await _mount(
        tester,
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse by categories'));
      await tester.pumpAndSettle();
      expect(pushedUri, contains('region=2'));
      expect(pushedUri, contains('supercat=Corals'));
    });
  });
}
