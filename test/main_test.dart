import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/main.dart';
import 'package:reefmobile/providers/app_state.dart';

Widget _buildApp() => ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: const ReefMobileApp(),
    );

/// Pump the widget and flush the SplashScreen's 5-second navigation timer.
Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(_buildApp());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  group('ReefMobileApp', () {
    testWidgets('renders a MaterialApp widget', (tester) async {
      await _pumpApp(tester);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('app title is reefguide.org', (tester) async {
      await _pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'reefguide.org');
    });

    testWidgets('theme uses Material3 with blue seed color', (tester) async {
      await _pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
      final scheme = app.theme?.colorScheme;
      expect(scheme, isNotNull);
      expect(scheme!.primary, isNotNull);
    });

    testWidgets('is a StatelessWidget', (tester) async {
      await _pumpApp(tester);
      expect(find.byType(ReefMobileApp), findsOneWidget);
      expect(tester.widget(find.byType(ReefMobileApp)), isA<StatelessWidget>());
    });
  });
}
