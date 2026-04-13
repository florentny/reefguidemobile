import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/taxonomy_node.dart';
import '../providers/app_state.dart';
import '../screens/species_screen.dart';
import '../services/data_service.dart';

class SpeciesList extends StatelessWidget {
  const SpeciesList({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final region = appState.selectedRegion;
    final superCat = appState.selectedSuperCat;
    final category = appState.selectedCategory;

    if (category == null) {
      return const Center(
        child: Text(
          'Select a category',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      );
    }

    return FutureBuilder<List<SpeciesRef>>(
      key: ValueKey('$region-$superCat-$category'),
      future: DataService.instance.getSpeciesForCategory(
        region,
        category,
        superCat,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading species',
              style: TextStyle(color: Colors.red[700]),
            ),
          );
        }
        final species = snapshot.data ?? [];

        // Collect ordered IDs for prev/next navigation in species detail screen
        final orderedIds = species.map((s) => s.id).toList();

        return ListView.builder(
          // Reset scroll to top when category changes
          key: ValueKey(category),
          itemCount: species.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) {
              return _SpeciesListHeader(
                category: category,
                count: species.length,
              );
            }
            final ref = species[index - 1];
            return _SpeciesCard(
              ref: ref,
              onTap: () {
                context.read<AppState>().openSpecies(ref.id, orderedIds);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SpeciesScreen(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Header row
// -----------------------------------------------------------------------------

class _SpeciesListHeader extends StatelessWidget {
  final String category;
  final int count;

  const _SpeciesListHeader({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.blue[700],
      alignment: Alignment.centerLeft,
      child: Text(
        '$category ($count species)',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Species card
// -----------------------------------------------------------------------------

class _SpeciesCard extends StatelessWidget {
  final SpeciesRef ref;
  final VoidCallback onTap;

  const _SpeciesCard({required this.ref, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo
          Image.asset(
            'asset/pix/${ref.id}${ref.thumb}.jpg',
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 140,
              color: Colors.grey[200],
              child: const Icon(
                Icons.camera_alt,
                color: Colors.grey,
                size: 40,
              ),
            ),
          ),
          // Name — fixed height of 32px so scroll math stays accurate
          SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  ref.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

