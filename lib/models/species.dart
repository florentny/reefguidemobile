class Photo {
  final int id;
  final String location;
  final String type;
  final String comment;

  const Photo({
    required this.id,
    required this.location,
    required this.type,
    required this.comment,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as int? ?? 0,
      location: json['location'] as String? ?? '',
      type: json['type'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
    );
  }
}

class Species {
  final String id;
  final String name;
  final String sciName;
  final String subGenus;
  final String category;
  final String size;
  final String depth;
  final String note;
  final String synonyms;
  final String aka;
  final bool endemic;
  final List<String> distribution;
  final List<Photo> photos;
  final List<int> thumbs;
  final List<String> dispNames;

  const Species({
    required this.id,
    required this.name,
    required this.sciName,
    required this.subGenus,
    required this.category,
    required this.size,
    required this.depth,
    required this.note,
    required this.synonyms,
    required this.aka,
    required this.endemic,
    required this.distribution,
    required this.photos,
    required this.thumbs,
    required this.dispNames,
  });

  factory Species.fromJson(Map<String, dynamic> json) {
    return Species(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sciName: json['sciName'] as String? ?? '',
      subGenus: json['subGenus'] as String? ?? '',
      category: json['category'] as String? ?? '',
      size: json['size'] as String? ?? '',
      depth: json['depth'] as String? ?? '',
      note: json['note'] as String? ?? '',
      synonyms: json['synonyms'] as String? ?? '',
      aka: json['aka'] as String? ?? '',
      endemic: json['endemic'] as bool? ?? false,
      distribution: (json['distribution'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      thumbs: (json['thumbs'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      dispNames: (json['dispNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
