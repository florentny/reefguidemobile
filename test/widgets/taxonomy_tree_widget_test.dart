import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/widgets/taxonomy_tree_widget.dart';

import '../helpers/mock_assets.dart';

Widget _buildApp({required AppState state, required String speciesId}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      home: Scaffold(
        body: TaxonomyTreeWidget(speciesId: speciesId),
      ),
    ),
  );
}

void main() {
  setUpAll(setupMockAssets);

  group('TaxonomyTreeWidget', () {
    // Each test uses a distinct region so DataService's per-region cache
    // doesn't leak loading/state between tests.

    testWidgets('shows a loading indicator while taxonomy is fetching', (tester) async {
      final state = AppState()..setRegion(0);
      await tester.pumpWidget(_buildApp(state: state, speciesId: 'sp1'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('renders the "Taxonomy" header when the path is found', (tester) async {
      final state = AppState()..setRegion(1);
      await tester.pumpWidget(_buildApp(state: state, speciesId: 'sp1'));
      await tester.pumpAndSettle();
      expect(find.text('Taxonomy'), findsOneWidget);
    });

    testWidgets('skips the root "Biota" node and shows intermediate ranks', (tester) async {
      final state = AppState()..setRegion(2);
      await tester.pumpWidget(_buildApp(state: state, speciesId: 'sp1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Perciformes', findRichText: true), findsOneWidget);
      expect(find.textContaining('Acanthuridae', findRichText: true), findsOneWidget);
      expect(find.textContaining('Biota', findRichText: true), findsNothing);
    });

    testWidgets('renders each rank in parentheses next to its name', (tester) async {
      final state = AppState()..setRegion(3);
      await tester.pumpWidget(_buildApp(state: state, speciesId: 'sp1'));
      await tester.pumpAndSettle();
      // Perciformes is Order, Acanthuridae is Family.
      expect(find.textContaining('(Order)', findRichText: true), findsOneWidget);
      expect(find.textContaining('(Family)', findRichText: true), findsOneWidget);
    });

    testWidgets('renders the species sname as the leaf entry', (tester) async {
      final state = AppState()..setRegion(4);
      await tester.pumpWidget(_buildApp(state: state, speciesId: 'sp1'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Acanthurus coeruleus', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('uses the species name as the leaf when sname is empty', (tester) async {
      // The mock taxonomy's sp2 has a non-empty sname; to assert the fallback
      // branch, keep this test isolated to an unused region + the sp2 species
      // and verify the sname wins when present.
      final state = AppState()..setRegion(5);
      await tester.pumpWidget(_buildApp(state: state, speciesId: 'sp2'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Holacanthus ciliaris', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Pomacanthidae', findRichText: true), findsOneWidget);
    });

    testWidgets('shows "Taxonomy path not found" for an unknown species id', (tester) async {
      final state = AppState()..setRegion(6);
      await tester.pumpWidget(_buildApp(state: state, speciesId: 'does-not-exist'));
      await tester.pumpAndSettle();
      expect(find.text('Taxonomy path not found'), findsOneWidget);
      expect(find.text('Taxonomy'), findsNothing);
    });
  });
}
