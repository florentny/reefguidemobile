class SpeciesRef {
  final String id;
  final String name;
  final String sname;
  final String superCat;
  final int thumb;

  const SpeciesRef({
    required this.id,
    required this.name,
    required this.sname,
    required this.superCat,
    required this.thumb,
  });

  factory SpeciesRef.fromJson(Map<String, dynamic> json) {
    return SpeciesRef(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sname: json['sname'] as String? ?? '',
      superCat: json['superCat'] as String? ?? '',
      thumb: json['thumb'] as int? ?? 1,
    );
  }
}

class TaxonomyNode {
  final String name;
  final String rank;
  // Non-null when this node serves as a labelled category in the left panel
  final String? category;
  final List<TaxonomyNode> children;
  final List<SpeciesRef> species;

  TaxonomyNode({
    required this.name,
    required this.rank,
    this.category,
    required this.children,
    required this.species,
  });

  factory TaxonomyNode.fromJson(Map<String, dynamic> json) {
    final catRaw = json['category'] as String?;
    return TaxonomyNode(
      name: json['name'] as String? ?? '',
      rank: json['rank'] as String? ?? '',
      category: (catRaw != null && catRaw.isNotEmpty) ? catRaw : null,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => TaxonomyNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      species: (json['species'] as List<dynamic>?)
              ?.map((e) => SpeciesRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Recursively collect all SpeciesRef under this node (including direct species).
  /// Result is memoized since TaxonomyNode is immutable after construction.
  late final List<SpeciesRef> allSpecies = _computeAllSpecies();

  List<SpeciesRef> _computeAllSpecies() {
    final result = <SpeciesRef>[...species];
    for (final child in children) {
      result.addAll(child.allSpecies);
    }
    return result;
  }

  /// Find the path from this node to the node containing [speciesId].
  /// Returns null if not found.
  List<TaxonomyNode>? pathToSpecies(String speciesId) {
    // Check if this node directly contains the species
    if (species.any((s) => s.id == speciesId)) {
      return [this];
    }
    // Recurse into children
    for (final child in children) {
      final childPath = child.pathToSpecies(speciesId);
      if (childPath != null) {
        return [this, ...childPath];
      }
    }
    return null;
  }
}
