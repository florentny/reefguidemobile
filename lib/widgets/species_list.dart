import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/taxonomy_node.dart';
import '../providers/app_state.dart';
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
        child: Text('Select a category', style: TextStyle(fontSize: 14, color: Colors.grey)),
      );
    }

    return FutureBuilder<List<SpeciesGroup>>(
      key: ValueKey('$region-$superCat-$category'),
      future: DataService.instance.getSpeciesGroupedForCategory(region, category, superCat),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading species', style: TextStyle(color: Colors.red[700])),
          );
        }
        final groups = snapshot.data ?? [];
        final totalCount = {
          for (final g in groups)
            for (final r in g.species) r.id,
        }.length;

        // Flatten into a scrollable item list.
        // Item types: _SectionHeader (SpeciesGroup), SpeciesRef.

        // Only emit section headers when there are multiple groups, or when the
        // single group has a named family/subfamily.
        final showSections = groups.length > 1 || (groups.length == 1 && groups.first.groupName != null);

        final items = <Object>[];

        // Collect ordered IDs for prev/next navigation in species detail screen.
        final orderedIds = <String>[];

        for (final group in groups) {
          if (showSections && group.groupName != null) {
            items.add(group); // section header marker
          }
          for (final ref in group.species) {
            items.add(ref);
            orderedIds.add(ref.id);
          }
        }

        return ListView.builder(
          key: ValueKey(category),
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is SpeciesGroup) {
              return _FamilyHeader(group: item, totalCount: totalCount, selectedCategory: category);
            }
            final ref = item as SpeciesRef;
            return _SpeciesCard(
              ref: ref,
              onTap: () {
                final appState = context.read<AppState>();
                appState.openSpecies(ref.id, orderedIds);
                context.push(
                  Uri(
                    path: '/browse/species/${ref.id}',
                    queryParameters: {
                      'region': '${appState.selectedRegion}',
                      'supercat': appState.selectedSuperCat,
                      if (appState.selectedCategory != null) 'category': appState.selectedCategory!,
                    },
                  ).toString(),
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
// Family / Subfamily / Tribe section header
// -----------------------------------------------------------------------------

class _FamilyHeader extends StatelessWidget {
  final SpeciesGroup group;
  final int totalCount;
  final String? selectedCategory;

  const _FamilyHeader({required this.group, required this.totalCount, required this.selectedCategory});

  @override
  Widget build(BuildContext context) {
    final isTribe = group.groupRank == 'Tribe' && group.parentName != null;
    final isSubfamily = group.groupRank == 'Subfamily' && group.parentName != null;

    // Effective category: deepest available rank's category takes precedence.
    final String? effectiveCategory = isTribe
        ? (group.groupCategory ?? group.parentCategory ?? group.grandparentCategory)
        : isSubfamily
        ? (group.groupCategory ?? group.parentCategory)
        : group.groupCategory;

    // Show the category above the header only when it differs from the
    // currently selected category in the left panel.
    final String? categoryAbove = (effectiveCategory != null && effectiveCategory != selectedCategory)
        ? effectiveCategory
        : null;

    // Genus group category overrides the title when all species share one.
    final String? title = group.genusGroupCategory ?? categoryAbove;
    final String? displayTitle = title != selectedCategory ? title : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blue[700],
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (displayTitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                displayTitle,
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 1.0), fontWeight: FontWeight.w600),
              ),
            ),
          // Family row — shown for Subfamily and Tribe
          if (isSubfamily || isTribe)
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 1.0),
                  fontWeight: FontWeight.normal,
                ),
                children: [
                  TextSpan(
                    text: isTribe ? group.grandparentName! : group.parentName!,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const TextSpan(
                    text: '  (Family)',
                    style: TextStyle(fontStyle: FontStyle.normal, color: Colors.white70),
                  ),
                ],
              ),
            ),
          // Subfamily row — shown for Tribe only
          if (isTribe)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '└ ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    TextSpan(
                      text: group.parentName!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                    const TextSpan(
                      text: '  (Subfamily)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          // Group name row (Family / Subfamily / Tribe)
          Padding(
            padding: EdgeInsets.only(
              left: isTribe
                  ? 32
                  : isSubfamily
                  ? 16
                  : 0,
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  if (isSubfamily || isTribe)
                    TextSpan(
                      text: '└ ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  TextSpan(
                    text: group.groupName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                  if (group.groupRank != null)
                    TextSpan(
                      text: '  (${group.groupRank})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (group.species.map((r) => r.id).toSet().length < totalCount)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${group.species.map((r) => r.id).toSet().length} species',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
              ),
            ),
        ],
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
          // Photo — 4:3 aspect ratio
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.asset(
              pixPath(ref.id, ref.thumb),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.camera_alt, color: Colors.grey, size: 40),
              ),
            ),
          ),
          // Names
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ref.sname.isNotEmpty)
                  Text(
                    ref.sname,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
