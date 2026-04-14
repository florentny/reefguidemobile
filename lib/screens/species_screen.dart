import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/species.dart';
import '../providers/app_state.dart';
import '../services/data_service.dart';
import '../widgets/photo_carousel.dart';
import '../widgets/taxonomy_tree_widget.dart';

class SpeciesScreen extends StatelessWidget {
  const SpeciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch currentSpeciesId so the screen updates on prev/next navigation
    final speciesId = context.watch<AppState>().currentSpeciesId;

    if (speciesId == null) {
      // Should not normally happen; pop defensively
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<List<Species>>(
      future: DataService.instance.getAllSpecies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: _buildAppBar(context, null),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final allSpecies = snapshot.data ?? [];
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

        return _SpeciesDetail(species: species);
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, Species? species) {
    final appState = context.read<AppState>();
    return AppBar(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: _NavButton(
        label: '<',
        onPressed: () {
          appState.closeSpecies();
          Navigator.of(context).pop();
        },
      ),
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

  const _SpeciesDetail({required this.species});

  @override
  Widget build(BuildContext context) {
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
      leading: _NavButton(
        label: '<',
        onPressed: () {
          context.read<AppState>().closeSpecies();
          Navigator.of(context).pop();
        },
      ),
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
// Name header
// -----------------------------------------------------------------------------

class _NameHeader extends StatelessWidget {
  final Species species;

  const _NameHeader({required this.species});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
              ),
            ),
          if (species.name.isNotEmpty) const SizedBox(height: 2),
          Text(
            species.sciName,
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
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
          if (species.size.isNotEmpty)
            _DetailRow(label: 'Size', value: species.size),
          if (species.depth.isNotEmpty)
            _DetailRow(label: 'Depth', value: species.depth),
          if (species.distribution.isNotEmpty)
            _DetailRow(
              label: 'Distribution',
              value: species.distribution.join(', '),
            ),
          if (species.endemic) const _DetailRow(label: 'Endemic', value: 'Yes'),
          if (species.synonyms.isNotEmpty)
            _DetailRow(label: 'Synonyms', value: species.synonyms),
          if (species.aka.isNotEmpty)
            _DetailRow(label: 'Also known as', value: species.aka),
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
                    TextSpan(text: species.note),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
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
          style: const TextStyle(fontSize: 13, color: Colors.black87),
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
          backgroundColor: enabled
              ? Colors.white.withAlpha(51)
              : Colors.white.withAlpha(20),
          foregroundColor: enabled ? Colors.white : Colors.white54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(36, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
