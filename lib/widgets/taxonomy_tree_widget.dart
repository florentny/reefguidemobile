import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/taxonomy_node.dart';
import '../providers/app_state.dart';
import '../services/data_service.dart';

class TaxonomyTreeWidget extends StatelessWidget {
  final String speciesId;

  const TaxonomyTreeWidget({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context) {
    final region = context.watch<AppState>().selectedRegion;

    return FutureBuilder<TaxonomyNode>(
      future: DataService.instance.getTaxonomy(region),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Padding(padding: EdgeInsets.all(16), child: Text('Taxonomy unavailable'));
        }

        final root = snapshot.data!;
        final path = root.pathToSpecies(speciesId);

        if (path == null || path.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Taxonomy path not found', style: TextStyle(color: Colors.grey, fontSize: 12)),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Taxonomy',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[700]),
              ),
              const SizedBox(height: 8),
              _TaxonomyPathList(path: path, speciesId: speciesId),
            ],
          ),
        );
      },
    );
  }
}

class _TaxonomyPathList extends StatelessWidget {
  final List<TaxonomyNode> path;
  final String speciesId;

  const _TaxonomyPathList({required this.path, required this.speciesId});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    // Skip index 0 (root "Biota" node) — start from the first meaningful rank.
    for (var i = 1; i < path.length; i++) {
      final node = path[i];
      final indent = (i - 1) * 5.0;
      final prefix = i == 1 ? '' : '\u2514'; // └

      items.add(
        Padding(
          padding: EdgeInsets.only(left: indent, bottom: 2),
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: 'monospace'),
              children: [
                if (prefix.isNotEmpty)
                  TextSpan(
                    text: '$prefix ',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                TextSpan(
                  text: node.name,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                if (node.rank.isNotEmpty)
                  TextSpan(
                    text: ' (${node.rank})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (node.category != null && node.category!.isNotEmpty)
                  TextSpan(
                    text: '  ${node.category}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Add the species leaf entry, one level deeper than the last path node
    final leafIndent = (path.length - 1) * 5.0;
    // Find the SpeciesRef in the last path node
    final lastNode = path.last;
    final speciesRef = lastNode.species.where((s) => s.id == speciesId).firstOrNull;

    if (speciesRef != null) {
      items.add(
        Padding(
          padding: EdgeInsets.only(left: leafIndent, bottom: 2),
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(fontSize: 13),
              children: [
                TextSpan(
                  text: '\u2514 ',
                  style: TextStyle(color: Colors.grey[400], fontFamily: 'monospace'),
                ),
                TextSpan(
                  text: speciesRef.sname.isNotEmpty ? speciesRef.sname : speciesRef.name,
                  style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: Colors.teal[700]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }
}
