import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/species.dart';
import '../models/taxonomy_node.dart';

String pixPath(String speciesId, int photoId) {
  final c = speciesId[0].toLowerCase();
  final dir = (c.compareTo('a') >= 0 && c.compareTo('d') <= 0)
      ? 'pix1'
      : (c.compareTo('e') >= 0 && c.compareTo('l') <= 0)
      ? 'pix2'
      : (c.compareTo('m') >= 0 && c.compareTo('r') <= 0)
      ? 'pix3'
      : 'pix4';

  return 'asset/$dir/$speciesId$photoId.jpg';
}

class CategoryEntry {
  final String name;
  final String firstSpeciesId;
  final int firstThumb;
  final int speciesCount;

  const CategoryEntry({
    required this.name,
    required this.firstSpeciesId,
    required this.firstThumb,
    required this.speciesCount,
  });
}

class SpeciesGroup {
  final String? groupName; // null = ungrouped (no enclosing family/subfamily)
  final String? groupRank; // e.g. "Family", "Subfamily", "Tribe"
  final String? parentName; // enclosing Subfamily (Tribe) or Family (Subfamily)
  final String? parentCategory;
  final String? grandparentName; // enclosing Family when groupRank == "Tribe"
  final String? grandparentCategory;
  final String? groupCategory; // taxonomy node's category label, if present
  // Non-null when every species in this group shares the same genus-level category.
  final String? genusGroupCategory;
  final List<SpeciesRef> species;

  const SpeciesGroup({
    required this.groupName,
    required this.groupRank,
    required this.parentName,
    required this.parentCategory,
    required this.grandparentName,
    required this.grandparentCategory,
    required this.groupCategory,
    required this.genusGroupCategory,
    required this.species,
  });
}

class AppStats {
  final int speciesCount;
  final int photoCount;
  final int categoryCount;

  const AppStats({required this.speciesCount, required this.photoCount, required this.categoryCount});
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

  Future<List<Species>> getAllSpecies() => _allSpeciesFuture ??= _loadAllSpecies();

  Future<List<Species>> _loadAllSpecies() async {
    final raw = await rootBundle.loadString('asset/json/species_all.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Species.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Cached id→Species lookup map built from species_all.json.
  Future<Map<String, Species>> _getSpeciesMap() =>
      _speciesMapFuture ??= getAllSpecies().then((list) => {for (final s in list) s.id: s});

  Future<TaxonomyNode> getTaxonomy(int regionIndex) =>
      _taxonomyFutures.putIfAbsent(regionIndex, () => _loadTaxonomy(regionIndex));

  Future<TaxonomyNode> _loadTaxonomy(int regionIndex) async {
    final raw = await rootBundle.loadString('asset/json/taxonomy_region_$regionIndex.json');
    return TaxonomyNode.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Returns the unique categories (from species_all.json) of all species that
  /// appear in [region]'s taxonomy and match [superCat], sorted alphabetically.
  /// The thumbnail for each category is taken from the first matching species.
  Future<List<CategoryEntry>> getCategoriesForRegionAndSuperCat(int region, String superCat) async {
    final speciesMap = await _getSpeciesMap();
    final root = await getTaxonomy(region);

    final firstRef = <String, SpeciesRef>{};
    final uniqueIds = <String, Set<String>>{};

    final allSuperCats = superCat == 'All Species';
    for (final ref in root.allSpecies) {
      if (!allSuperCats && ref.superCat != superCat) continue;
      final species = speciesMap[ref.id];
      final cat = species?.category ?? '';
      if (cat.isEmpty) continue;
      firstRef.putIfAbsent(cat, () => ref);
      (uniqueIds[cat] ??= {}).add(ref.id);
    }

    final entries = firstRef.entries.map((e) {
      final ref = e.value;
      return CategoryEntry(
        name: e.key,
        firstSpeciesId: ref.id,
        firstThumb: ref.thumb,
        speciesCount: uniqueIds[e.key]!.length,
      );
    }).toList();

    entries.sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }

  /// Returns aggregate stats across all species.
  Future<AppStats> getStats() async {
    final species = await getAllSpecies();
    final totalPhotos = species.fold(0, (sum, s) => sum + s.photos.length);
    final categories = species.map((s) => s.category).where((c) => c.isNotEmpty).toSet();
    return AppStats(speciesCount: species.length, photoCount: totalPhotos, categoryCount: categories.length);
  }

  /// Returns all [SpeciesRef] in [region] whose species_all.json [category]
  /// matches [categoryName] and whose [superCat] matches, sorted by name.
  Future<List<SpeciesRef>> getSpeciesForCategory(int region, String categoryName, String superCat) async {
    final speciesMap = await _getSpeciesMap();
    final root = await getTaxonomy(region);

    final allSuperCats = superCat == 'All Species';
    return root.allSpecies
        .where((ref) => (allSuperCats || ref.superCat == superCat) && (speciesMap[ref.id]?.category ?? '') == categoryName)
        .toList()
      ..sort((a, b) => a.sname.compareTo(b.sname));
  }

  /// Same as [getSpeciesForCategory] but groups species by the nearest enclosing
  /// Family or Subfamily node in the taxonomy tree. Groups are returned in
  /// tree-walk order; species within each group are sorted by scientific name.
  Future<List<SpeciesGroup>> getSpeciesGroupedForCategory(int region, String categoryName, String superCat) async {
    final speciesMap = await _getSpeciesMap();
    final root = await getTaxonomy(region);

    // Ordered list of group keys (null = ungrouped)
    final groupOrder = <String?>[];
    final groupRanks = <String?, String?>{};
    final groupParents = <String?, String?>{};
    final groupParentCategories = <String?, String?>{};
    final groupGrandparents = <String?, String?>{};
    final groupGrandparentCategories = <String?, String?>{};
    final groupCategories = <String?, String?>{};
    final groupSpecies = <String?, List<SpeciesRef>>{};
    // Maps species id → genus-level category for species added to groups.
    final speciesGenusCategory = <String, String?>{};
    final allSuperCats = superCat == 'All Species';

    void walk(
      TaxonomyNode node, {
      String? order,
      String? orderCategory,
      String? family,
      String? familyCategory,
      String? subfamily,
      String? subfamilyCategory,
      String? tribe,
      String? tribeCategory,
      String? genusCategory,
    }) {
      final rank = node.rank;
      if (rank == 'Order') {
        order = node.name;
        orderCategory = node.category;
        family = null;
        familyCategory = null;
        subfamily = null;
        subfamilyCategory = null;
        tribe = null;
        tribeCategory = null;
        genusCategory = null;
      } else if (rank == 'Family') {
        family = node.name;
        familyCategory = node.category;
        subfamily = null;
        subfamilyCategory = null;
        tribe = null;
        tribeCategory = null;
        genusCategory = null;
      } else if (rank == 'Subfamily') {
        subfamily = node.name;
        subfamilyCategory = node.category;
        tribe = null;
        tribeCategory = null;
        genusCategory = null;
      } else if (rank == 'Tribe') {
        tribe = node.name;
        tribeCategory = node.category;
        genusCategory = null;
      } else if (rank == 'Genus') {
        genusCategory = node.category;
      }

      // Prefer Tribe > Subfamily > Family > Order as the group key.
      final groupKey = tribe ?? subfamily ?? family ?? order;
      final groupRank = tribe != null
          ? 'Tribe'
          : subfamily != null
          ? 'Subfamily'
          : family != null
          ? 'Family'
          : order != null
          ? 'Order'
          : null;
      // Category belongs to whichever rank defines this group.
      final groupCat = tribe != null
          ? tribeCategory
          : subfamily != null
          ? subfamilyCategory
          : family != null
          ? familyCategory
          : orderCategory;
      // Parent: Subfamily for Tribe, Family for Subfamily, null otherwise.
      final parentName = tribe != null ? subfamily : subfamily != null ? family : null;
      final parentCat = tribe != null ? subfamilyCategory : subfamily != null ? familyCategory : null;
      // Grandparent: Family for Tribe, null otherwise.
      final grandparentName = tribe != null ? family : null;
      final grandparentCat = tribe != null ? familyCategory : null;

      void registerGroup() {
        groupOrder.add(groupKey);
        groupRanks[groupKey] = groupRank;
        groupParents[groupKey] = parentName;
        groupParentCategories[groupKey] = parentCat;
        groupGrandparents[groupKey] = grandparentName;
        groupGrandparentCategories[groupKey] = grandparentCat;
        groupCategories[groupKey] = groupCat;
        groupSpecies[groupKey] = [];
      }

      if (groupKey != null && !groupSpecies.containsKey(groupKey)) {
        registerGroup();
      }

      for (final ref in node.species) {
        if ((allSuperCats || ref.superCat == superCat) && (speciesMap[ref.id]?.category ?? '') == categoryName) {
          if (!groupSpecies.containsKey(groupKey)) {
            registerGroup();
          }
          groupSpecies[groupKey]!.add(ref);
          speciesGenusCategory[ref.id] = genusCategory;
        }
      }

      for (final child in node.children) {
        walk(
          child,
          order: order,
          orderCategory: orderCategory,
          family: family,
          familyCategory: familyCategory,
          subfamily: subfamily,
          subfamilyCategory: subfamilyCategory,
          tribe: tribe,
          tribeCategory: tribeCategory,
          genusCategory: genusCategory,
        );
      }
    }

    walk(root);

    final result = <SpeciesGroup>[];
    for (final key in groupOrder) {
      final species = groupSpecies[key]!;
      if (species.isEmpty) continue;
      species.sort((a, b) => a.sname.compareTo(b.sname));

      // Use a genus-level category as the header name if all species in this
      // group share the same non-empty genus category.
      final genusCats = species.map((s) => speciesGenusCategory[s.id]).where((c) => c != null && c.isNotEmpty).toSet();
      final genusGroupCat = (genusCats.length == 1) ? genusCats.first : null;

      result.add(
        SpeciesGroup(
          groupName: key,
          groupRank: groupRanks[key],
          parentName: groupParents[key],
          parentCategory: groupParentCategories[key],
          grandparentName: groupGrandparents[key],
          grandparentCategory: groupGrandparentCategories[key],
          groupCategory: groupCategories[key],
          genusGroupCategory: genusGroupCat,
          species: species,
        ),
      );
    }
    return result;
  }
}
