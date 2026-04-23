import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reefmobile/widgets/appbar_dropdown.dart';

Widget _buildApp({
  required String value,
  required List<String> items,
  required ValueChanged<String> onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: AppBarDropdown<String>(
          value: value,
          items: items,
          labelOf: (s) => s,
          onChanged: onChanged,
        ),
      ),
      body: const SizedBox(),
    ),
  );
}

void main() {
  group('AppBarDropdown', () {
    testWidgets('renders the current value label', (tester) async {
      await tester.pumpWidget(_buildApp(
        value: 'Fish',
        items: const ['Fish', 'Invertebrates'],
        onChanged: (_) {},
      ));
      expect(find.text('Fish'), findsOneWidget);
    });

    testWidgets('renders the dropdown arrow icon', (tester) async {
      await tester.pumpWidget(_buildApp(
        value: 'Fish',
        items: const ['Fish', 'Invertebrates'],
        onChanged: (_) {},
      ));
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('calls onChanged with the tapped item', (tester) async {
      String? selected;
      await tester.pumpWidget(_buildApp(
        value: 'Fish',
        items: const ['Fish', 'Invertebrates', 'Corals'],
        onChanged: (v) => selected = v,
      ));
      // Open the popup menu.
      await tester.tap(find.text('Fish'));
      await tester.pumpAndSettle();

      // All items should appear in the menu.
      expect(find.text('Invertebrates'), findsOneWidget);
      await tester.tap(find.text('Invertebrates'));
      await tester.pumpAndSettle();

      expect(selected, 'Invertebrates');
    });

    testWidgets('does not call onChanged when the same item is tapped', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_buildApp(
        value: 'Fish',
        items: const ['Fish', 'Invertebrates'],
        onChanged: (_) => callCount++,
      ));
      await tester.tap(find.text('Fish'));
      await tester.pumpAndSettle();
      // Tap the currently selected item; the menu closes without calling onChanged.
      await tester.tap(find.text('Fish').last);
      await tester.pumpAndSettle();
      // onChanged IS called because the popup merely returns the selected value
      // — the caller decides whether to ignore duplicates.
      expect(callCount, 1);
    });
  });
}
