import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/species.dart';
import '../models/taxonomy_node.dart';
import '../providers/app_state.dart';
import '../services/data_service.dart';
import '../widgets/photo_carousel.dart';
import '../widgets/taxonomy_tree_widget.dart';

class SpeciesScreen extends StatelessWidget {
  const SpeciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final speciesId = appState.currentSpeciesId;
    final region = appState.selectedRegion;

    if (speciesId == null) {
      // Should not normally happen; pop defensively
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final future = Future.wait<dynamic>([
      DataService.instance.getAllSpecies(),
      DataService.instance.getTaxonomy(region),
    ]);

    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: _buildAppBar(context, null),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final allSpecies = snapshot.data?[0] as List<Species>? ?? [];
        final taxonomy = snapshot.data?[1] as TaxonomyNode?;

        Species? species;
        for (final s in allSpecies) {
          if (s.id == speciesId) {
            species = s;
            break;
          }
        }

        if (species == null) {
          return Scaffold(
            appBar: _buildAppBar(context, null),
            body: const Center(child: Text('Species not found')),
          );
        }

        // Find the deepest taxonomy node with a category set.
        String? lowestCategory;
        if (taxonomy != null) {
          final path = taxonomy.pathToSpecies(speciesId);
          if (path != null) {
            for (final node in path.reversed) {
              if (node.category != null && node.category!.isNotEmpty) {
                lowestCategory = node.category;
                break;
              }
            }
          }
        }

        return _SpeciesDetail(species: species, lowestTaxonomyCategory: lowestCategory);
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, Species? species) {
    return AppBar(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: _NavButton(label: '<', onPressed: () => context.pop()),
      title: null,
      actions: [
        Consumer<AppState>(
          builder: (ctx, state, child) => _NavButton(
            label: '\u2227', // ∧
            enabled: state.hasPrevious,
            onPressed: state.hasPrevious ? state.goToPreviousSpecies : null,
          ),
        ),
        const SizedBox(width: 4),
        Consumer<AppState>(
          builder: (ctx, state, child) => _NavButton(
            label: '\u2228', // ∨
            enabled: state.hasNext,
            onPressed: state.hasNext ? state.goToNextSpecies : null,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The actual detail layout
// -----------------------------------------------------------------------------

class _SpeciesDetail extends StatelessWidget {
  final Species species;
  final String? lowestTaxonomyCategory;

  const _SpeciesDetail({required this.species, this.lowestTaxonomyCategory});

  @override
  Widget build(BuildContext context) {
    final isLandscape = !kIsWeb && MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return _LandscapePhotoView(species: species, lowestTaxonomyCategory: lowestTaxonomyCategory);
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scientific / common name header
            _NameHeader(species: species),
            // Photo carousel
            PhotoCarousel(
              // Key forces carousel reset when species changes
              key: ValueKey(species.id),
              species: species,
            ),
            // Details section
            _DetailsSection(species: species),
            // Taxonomy section
            TaxonomyTreeWidget(speciesId: species.id),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: _NavButton(label: '<', onPressed: () => context.pop()),
      centerTitle: false,
      title: lowestTaxonomyCategory != null
          ? Text(
              lowestTaxonomyCategory!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
            )
          : null,
      actions: [
        Consumer<AppState>(
          builder: (ctx, state, child) => _NavButton(
            label: '\u2227', // ∧
            enabled: state.hasPrevious,
            onPressed: state.hasPrevious ? state.goToPreviousSpecies : null,
          ),
        ),
        const SizedBox(width: 0),
        Consumer<AppState>(
          builder: (ctx, state, child) => _NavButton(
            label: '\u2228', // ∨
            enabled: state.hasNext,
            onPressed: state.hasNext ? state.goToNextSpecies : null,
          ),
        ),
        const SizedBox(width: 2),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Landscape full-screen photo view
// -----------------------------------------------------------------------------

class _LandscapePhotoView extends StatefulWidget {
  final Species species;
  final String? lowestTaxonomyCategory;

  const _LandscapePhotoView({required this.species, this.lowestTaxonomyCategory});

  @override
  State<_LandscapePhotoView> createState() => _LandscapePhotoViewState();
}

class _LandscapePhotoViewState extends State<_LandscapePhotoView> {
  int _currentPage = 0;
  late final PageController _pageController;
  late final TransformationController _transformController;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onTransformChanged() {
    final zoomed = _transformController.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.species.photos;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Photos
          if (photos.isEmpty)
            const Center(child: Icon(Icons.camera_alt, color: Colors.white38, size: 64))
          else
            PageView.builder(
              controller: _pageController,
              physics: _isZoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: photos.length,
              onPageChanged: (page) {
                _transformController.value = Matrix4.identity();
                setState(() => _currentPage = page);
              },
              itemBuilder: (context, index) {
                final photo = photos[index];
                return InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.asset(
                    'asset/pix/${widget.species.id}${photo.id}.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.camera_alt, color: Colors.white38, size: 64)),
                  ),
                );
              },
            ),

          // Top overlay: back button (left) + species name (centre) + nav (right)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, left: 4, right: 8, bottom: 8),
              child: Row(
                children: [
                  // Back
                  _NavButton(label: '<', onPressed: () => context.pop()),
                  // Species name
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.species.name.isNotEmpty ? widget.species.name : widget.species.sciName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Prev / Next species
                  Consumer<AppState>(
                    builder: (ctx, state, child) => _NavButton(
                      label: '\u2227',
                      enabled: state.hasPrevious,
                      onPressed: state.hasPrevious ? state.goToPreviousSpecies : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Consumer<AppState>(
                    builder: (ctx, state, child) => _NavButton(
                      label: '\u2228',
                      enabled: state.hasNext,
                      onPressed: state.hasNext ? state.goToNextSpecies : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Page counter badge (top-right corner, below header)
          if (photos.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${_currentPage + 1}/${photos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // Dot indicator (bottom-centre)
          if (photos.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 28,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photos.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentPage ? 10 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _currentPage ? Colors.white : Colors.white54,
                    ),
                  );
                }),
              ),
            ),

          // Photo caption (bottom)
          if (photos.isNotEmpty)
            Builder(
              builder: (context) {
                final photo = photos[_currentPage];
                final parts = [if (photo.location.isNotEmpty) photo.location, if (photo.type.isNotEmpty) photo.type];
                if (parts.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 6,
                      bottom: MediaQuery.of(context).padding.bottom + 6,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Text(
                      parts.join('  ·  '),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Name header
// -----------------------------------------------------------------------------

class _NameHeader extends StatelessWidget {
  final Species species;

  const _NameHeader({required this.species});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (species.name.isNotEmpty)
            Text(
              species.name,
              style: TextStyle(
                fontSize: 18,
                color: Colors.teal[700],
                fontWeight: FontWeight.w600,
                fontStyle: species.name == species.sciName ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          if (species.sciName.isNotEmpty && species.sciName != species.name)
            Text(
              species.sciName,
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Details section
// -----------------------------------------------------------------------------

class _DetailsSection extends StatelessWidget {
  final Species species;

  const _DetailsSection({required this.species});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (species.size.isNotEmpty) _DetailRow(label: 'Size', value: species.size),
          if (species.depth.isNotEmpty) _DetailRow(label: 'Depth', value: species.depth),
          if (species.distribution.isNotEmpty)
            _DetailRow(label: 'Distribution', value: species.distribution.join(', ')),
          if (species.endemic) const _DetailRow(label: 'Endemic', value: 'Yes'),
          if (species.synonyms.isNotEmpty) _DetailRow(label: 'Synonyms', value: species.synonyms),
          if (species.aka.isNotEmpty) _DetailRow(label: 'Also known as', value: species.aka),
          if (species.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  children: [
                    const TextSpan(
                      text: 'Note: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ..._parseItalicSpans(species.note),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Splits [text] on `<i>…</i>` tags and returns a list of [TextSpan]s,
/// rendering tagged segments in italic.
List<TextSpan> _parseItalicSpans(String text) {
  final spans = <TextSpan>[];
  final re = RegExp(r'<i>(.*?)</i>', dotAll: true);
  int cursor = 0;
  for (final match in re.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Navigation button (rounded rectangle style)
// -----------------------------------------------------------------------------

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  const _NavButton({required this.label, this.onPressed, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Colors.white.withAlpha(51) : Colors.white.withAlpha(20),
          foregroundColor: enabled ? Colors.white : Colors.white54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(36, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
