import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/species.dart';
import '../models/taxonomy_node.dart';

class CategoryEntry {
  final String name;
  final String firstSpeciesId;
  final int firstThumb;

  const CategoryEntry({
    required this.name,
    required this.firstSpeciesId,
    required this.firstThumb,
  });
}

/// Singleton data service. Load and cache JSON assets.
class DataService {
  DataService._();
  static final DataService instance = DataService._();

  // Cache the in-flight Futures so concurrent callers share one parse.
  Future<List<Species>>? _allSpeciesFuture;
  Future<Map<String, Species>>? _speciesMapFuture;
  final Map<int, Future<TaxonomyNode>> _taxonomyFutures = {};

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  Future<List<Species>> getAllSpecies() =>
      _allSpeciesFuture ??= _loadAllSpecies();

  Future<List<Species>> _loadAllSpecies() async {
    final raw = await rootBundle.loadString('asset/json/species_all.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Species.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cached id→Species lookup map built from species_all.json.
  Future<Map<String, Species>> _getSpeciesMap() =>
      _speciesMapFuture ??= getAllSpecies().then(
        (list) => {for (final s in list) s.id: s},
      );

  Future<TaxonomyNode> getTaxonomy(int regionIndex) =>
      _taxonomyFutures.putIfAbsent(regionIndex, () => _loadTaxonomy(regionIndex));

  Future<TaxonomyNode> _loadTaxonomy(int regionIndex) async {
    final raw = await rootBundle
        .loadString('asset/json/taxonomy_region_$regionIndex.json');
    return TaxonomyNode.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Returns the unique categories (from species_all.json) of all species that
  /// appear in [region]'s taxonomy and match [superCat], sorted alphabetically.
  /// The thumbnail for each category is taken from the first matching species.
  Future<List<CategoryEntry>> getCategoriesForRegionAndSuperCat(
    int region,
    String superCat,
  ) async {
    final speciesMap = await _getSpeciesMap();
    final root = await getTaxonomy(region);

    final seen = <String>{};
    final entries = <CategoryEntry>[];

    for (final ref in root.allSpecies) {
      if (ref.superCat != superCat) continue;
      final species = speciesMap[ref.id];
      final cat = species?.category ?? '';
      if (cat.isEmpty || seen.contains(cat)) continue;
      seen.add(cat);
      entries.add(CategoryEntry(
        name: cat,
        firstSpeciesId: ref.id,
        firstThumb: ref.thumb,
      ));
    }

    entries.sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }

  /// Returns all [SpeciesRef] in [region] whose species_all.json [category]
  /// matches [categoryName] and whose [superCat] matches, sorted by name.
  Future<List<SpeciesRef>> getSpeciesForCategory(
    int region,
    String categoryName,
    String superCat,
  ) async {
    final speciesMap = await _getSpeciesMap();
    final root = await getTaxonomy(region);

    return root.allSpecies
        .where((ref) =>
            ref.superCat == superCat &&
            (speciesMap[ref.id]?.category ?? '') == categoryName)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
