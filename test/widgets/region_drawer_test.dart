import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/widgets/region_drawer.dart';

Widget _buildApp(AppState state) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test')),
        drawer: const RegionDrawer(),
        body: const SizedBox(),
      ),
    ),
  );
}

Future<void> _openDrawer(WidgetTester tester) async {
  final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
  scaffold.openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  group('RegionDrawer', () {
    testWidgets('renders "Region" header', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      await _openDrawer(tester);
      expect(find.text('Region'), findsOneWidget);
    });

    testWidgets('renders all region names', (tester) async {
      await tester.pumpWidget(_buildApp(AppState()));
      await _openDrawer(tester);
      for (final name in regionNames) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('shows check icon only for the selected region', (tester) async {
      final state = AppState()..setRegion(2);
      await tester.pumpWidget(_buildApp(state));
      await _openDrawer(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);
      final tile = tester.widget<Text>(find.text(regionNames[2]));
      expect(tile.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('tapping a region updates selectedRegion and closes the drawer', (tester) async {
      final state = AppState();
      await tester.pumpWidget(_buildApp(state));
      await _openDrawer(tester);

      await tester.tap(find.text(regionNames[3]));
      await tester.pumpAndSettle();

      expect(state.selectedRegion, 3);
      // Drawer closed — region list no longer visible.
      expect(find.text(regionNames[0]), findsNothing);
    });

    testWidgets('tapping the already-selected region still closes the drawer', (tester) async {
      final state = AppState(); // region 0 by default
      await tester.pumpWidget(_buildApp(state));
      await _openDrawer(tester);

      await tester.tap(find.text(regionNames[0]));
      await tester.pumpAndSettle();

      expect(state.selectedRegion, 0);
      expect(find.text(regionNames[0]), findsNothing);
    });
  });
}
