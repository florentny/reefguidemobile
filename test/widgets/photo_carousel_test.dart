import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reefmobile/models/species.dart';
import 'package:reefmobile/widgets/photo_carousel.dart';

Species _species({List<Photo> photos = const []}) => Species(
      id: 'sp1',
      name: 'Test Species',
      sciName: '',
      subGenus: '',
      category: '',
      size: '',
      depth: '',
      note: '',
      synonyms: '',
      aka: '',
      endemic: false,
      distribution: const [],
      photos: photos,
      thumbs: const [],
      dispNames: const [],
    );

// 300px width keeps AspectRatio(4/3) height to 225px, well within the 600px viewport.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 300, child: child)),
    );

void main() {
  group('PhotoCarousel', () {
    testWidgets('shows placeholder icon when species has no photos', (tester) async {
      await tester.pumpWidget(_wrap(PhotoCarousel(species: _species())));
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('shows PageView when photos are present', (tester) async {
      final s = _species(photos: [
        const Photo(id: 1, location: '', type: '', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(species: s)));
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('hides counter badge and dot indicators for a single photo', (tester) async {
      final s = _species(photos: [
        const Photo(id: 1, location: '', type: '', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(species: s)));
      expect(find.text('1/1'), findsNothing);
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('shows counter badge when there are multiple photos', (tester) async {
      final s = _species(photos: [
        const Photo(id: 1, location: '', type: '', comment: ''),
        const Photo(id: 2, location: '', type: '', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(species: s)));
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('renders one dot indicator per photo', (tester) async {
      final s = _species(photos: [
        const Photo(id: 1, location: '', type: '', comment: ''),
        const Photo(id: 2, location: '', type: '', comment: ''),
        const Photo(id: 3, location: '', type: '', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(species: s)));
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('shows joined location and type as caption', (tester) async {
      final s = _species(photos: [
        const Photo(id: 1, location: 'Hawaii', type: 'Juvenile', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(species: s)));
      expect(find.text('Hawaii  -  Juvenile'), findsOneWidget);
    });

    testWidgets('shows location alone when type and comment are empty', (tester) async {
      final s = _species(photos: [
        const Photo(id: 1, location: 'Fiji', type: '', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(species: s)));
      expect(find.text('Fiji'), findsOneWidget);
    });

    testWidgets('shows no caption text when all caption fields are empty', (tester) async {
      final s = _species(photos: [
        const Photo(id: 1, location: '', type: '', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(species: s)));
      // No caption → no Text widgets (no AppBar or other text in this fixture).
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('respects initialPage parameter', (tester) async {
      final s = _species(photos: [
        const Photo(id: 1, location: 'Page 1', type: '', comment: ''),
        const Photo(id: 2, location: 'Page 2', type: '', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(species: s, initialPage: 1)));
      await tester.pump();
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
    });

    testWidgets('calls onPageChanged when swiping to the next page', (tester) async {
      int? notifiedPage;
      final s = _species(photos: [
        const Photo(id: 1, location: '', type: '', comment: ''),
        const Photo(id: 2, location: '', type: '', comment: ''),
      ]);
      await tester.pumpWidget(_wrap(PhotoCarousel(
        species: s,
        onPageChanged: (p) => notifiedPage = p,
      )));
      // Fling left to advance to the second page.
      await tester.fling(find.byType(PageView), const Offset(-150, 0), 800);
      await tester.pumpAndSettle();
      expect(notifiedPage, 1);
    });
  });
}
