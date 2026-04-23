import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/widgets/category_list.dart';

import '../helpers/mock_assets.dart';

// Mock fixture yields two Fish categories: "Angelfish" (sp2) and "Surgeonfish" (sp1).
Widget _buildApp(AppState state) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 600,
          child: const CategoryList(),
        ),
      ),
    ),
  );
}

// DataService + Image.asset interactions leave pumpAndSettle busy across tests.
// Use runAsync to let the mock asset handler resolve on a real clock, then
// pump once to flush the resulting frame.
Future<void> _mount(WidgetTester tester, AppState state) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(_buildApp(state));
    await Future.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  await tester.pump();
}

void main() {
  setUpAll(setupMockAssets);

  group('CategoryList', () {
    testWidgets('shows a loading indicator before categories resolve', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_buildApp(AppState()));
        // First frame: FutureBuilder is in ConnectionState.waiting.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    });

    testWidgets('renders the search field and a row per category', (tester) async {
      await _mount(tester, AppState());
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search…'), findsOneWidget);
      expect(find.text('Angelfish (1)'), findsOneWidget);
      expect(find.text('Surgeonfish (1)'), findsOneWidget);
    });

    testWidgets('sorts categories alphabetically', (tester) async {
      await _mount(tester, AppState());
      final angelY = tester.getTopLeft(find.text('Angelfish (1)')).dy;
      final surgeonY = tester.getTopLeft(find.text('Surgeonfish (1)')).dy;
      expect(angelY, lessThan(surgeonY));
    });

    testWidgets('shows "No categories" when the superCat yields nothing', (tester) async {
      final state = AppState()..setSuperCat('Corals');
      await _mount(tester, state);
      expect(find.text('No categories'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('filters the list by search query', (tester) async {
      await _mount(tester, AppState());
      await tester.enterText(find.byType(TextField), 'ang');
      await tester.pump();
      expect(find.text('Angelfish (1)'), findsOneWidget);
      expect(find.text('Surgeonfish (1)'), findsNothing);
    });

    testWidgets('search is case-insensitive', (tester) async {
      await _mount(tester, AppState());
      await tester.enterText(find.byType(TextField), 'SURGEON');
      await tester.pump();
      expect(find.text('Surgeonfish (1)'), findsOneWidget);
      expect(find.text('Angelfish (1)'), findsNothing);
    });

    testWidgets('shows "No results" when the query matches nothing', (tester) async {
      await _mount(tester, AppState());
      await tester.enterText(find.byType(TextField), 'zzz-nomatch');
      await tester.pump();
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('clear icon appears with a query and empties the field when tapped', (tester) async {
      await _mount(tester, AppState());
      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byType(TextField), 'ang');
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.text('Angelfish (1)'), findsOneWidget);
      expect(find.text('Surgeonfish (1)'), findsOneWidget);
    });

    testWidgets('tapping a row updates AppState.selectedCategory', (tester) async {
      final state = AppState();
      await _mount(tester, state);

      await tester.tap(find.text('Angelfish (1)'));
      await tester.pump();

      expect(state.selectedCategory, 'Angelfish');
    });

    testWidgets('selected category row renders bold blue text', (tester) async {
      final state = AppState()..setCategory('Angelfish');
      await _mount(tester, state);

      final text = tester.widget<Text>(find.text('Angelfish (1)'));
      expect(text.style?.fontWeight, FontWeight.bold);
      expect(text.style?.color, Colors.blue[700]);
    });

    testWidgets('unselected rows render normal-weight text', (tester) async {
      await _mount(tester, AppState());
      final text = tester.widget<Text>(find.text('Surgeonfish (1)'));
      expect(text.style?.fontWeight, FontWeight.normal);
    });

    testWidgets('reloads the list when the selected region changes', (tester) async {
      final state = AppState();
      await _mount(tester, state);
      expect(find.text('Angelfish (1)'), findsOneWidget);

      state.setRegion(2);
      await tester.pump(); // let the rebuild create the new categories Future
      await _settle(tester); // then give the mock handler real-clock time to resolve
      // Mock fixture returns the same taxonomy for every region, so rows persist.
      expect(find.text('Angelfish (1)'), findsOneWidget);
      expect(find.text('Surgeonfish (1)'), findsOneWidget);
    });

    testWidgets('renders one thumbnail image per category row', (tester) async {
      await _mount(tester, AppState());
      // One Image.asset per row; errorBuilder takes over for missing asset bytes.
      expect(find.byType(Image), findsNWidgets(2));
    });
  });
}
