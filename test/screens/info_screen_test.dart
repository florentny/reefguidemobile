import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reefmobile/screens/info_screen.dart';

import '../helpers/mock_assets.dart';

// InfoScreen has no AppState dependency — plain MaterialApp suffices.
Widget _buildApp() => const MaterialApp(home: InfoScreen());

// Pump widget and wait for DataService.getStats() to resolve.
Future<void> _mount(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(_buildApp());
    await Future.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
}

void main() {
  setUpAll(setupMockAssets);

  group('InfoScreen', () {
    testWidgets('renders AppBar with "About" title', (tester) async {
      await _mount(tester);
      expect(find.text('About'), findsOneWidget);
    });

    // _StatRow renders a CircularProgressIndicator (not "—" text) when loading==true,
    // so the correct loading-state assertion is on the indicator widget.
    testWidgets('shows a small CircularProgressIndicator per stat while loading', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_buildApp());
        expect(find.byType(CircularProgressIndicator), findsNWidgets(3));
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    });

    testWidgets('shows all section headers', (tester) async {
      await _mount(tester);
      for (final header in ['Statistics', 'Website', 'Contact', 'Privacy Policy', 'Copyright']) {
        expect(find.text(header), findsOneWidget);
      }
    });

    testWidgets('shows correct species, photo, and category counts from mock data', (tester) async {
      // Mock: sp1 + sp2 → 2 species; sp1 has 1 photo → 1 photo;
      // categories: Surgeonfish + Angelfish → 2 categories.
      await _mount(tester);
      expect(find.text('—'), findsNothing); // all placeholders replaced
      expect(find.text('2'), findsNWidgets(2)); // speciesCount=2 and categoryCount=2
      expect(find.text('1'), findsOneWidget);   // photoCount=1
    });

    testWidgets('shows the stat row labels', (tester) async {
      await _mount(tester);
      expect(find.text('Species'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
    });

    testWidgets('shows the website URL', (tester) async {
      await _mount(tester);
      expect(find.text('https://reefguide.org'), findsOneWidget);
    });

    testWidgets('shows the contact email address', (tester) async {
      await _mount(tester);
      expect(find.text('mobile@reefguide.org'), findsOneWidget);
    });

    testWidgets('shows the privacy policy link with underline decoration', (tester) async {
      await _mount(tester);
      const linkUrl = 'https://reefguide.org/privacy_policy.txt';
      expect(find.text(linkUrl), findsOneWidget);
      final text = tester.widget<Text>(find.text(linkUrl));
      expect(text.style?.decoration, TextDecoration.underline);
      expect(text.style?.color, Colors.blue);
    });

    testWidgets('shows the copyright notice', (tester) async {
      await _mount(tester);
      expect(find.textContaining('Florent Charpin'), findsAtLeastNWidgets(1));
      expect(find.textContaining('All rights reserved'), findsOneWidget);
    });
  });
}
