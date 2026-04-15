import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/data_service.dart';

// Each category row: image 60 + vertical padding 6+6 = 72px fixed height.
const double _kItemHeight = 72.0;

const List<String> _allLetters = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '#',
];

class CategoryList extends StatefulWidget {
  const CategoryList({super.key});

  @override
  State<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Future<List<CategoryEntry>>? _categoriesFuture;
  int? _lastRegion;
  String? _lastSuperCat;
  String _searchQuery = '';

  Future<List<CategoryEntry>> _getCategories(int region, String superCat) {
    if (_categoriesFuture == null ||
        _lastRegion != region ||
        _lastSuperCat != superCat) {
      _lastRegion = region;
      _lastSuperCat = superCat;
      _categoriesFuture = DataService.instance
          .getCategoriesForRegionAndSuperCat(region, superCat);
    }
    return _categoriesFuture!;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Pure function — maps first letter → index in the sorted category list.
  Map<String, int> _computeLetterIndex(List<CategoryEntry> categories) {
    final map = <String, int>{};
    for (var i = 0; i < categories.length; i++) {
      final name = categories[i].name.toUpperCase();
      if (name.isEmpty) continue;
      final first = name[0];
      final key = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
      map.putIfAbsent(key, () => i);
    }
    return map;
  }

  void _scrollToLetter(String letter, Map<String, int> letterIndexMap) {
    final index = letterIndexMap[letter];
    if (index == null) return;
    final offset = index * _kItemHeight;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final region = appState.selectedRegion;
    final superCat = appState.selectedSuperCat;
    final selected = appState.selectedCategory;

    return FutureBuilder<List<CategoryEntry>>(
      future: _getCategories(region, superCat),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading categories',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          );
        }
        final categories = snapshot.data ?? [];
        if (categories.isEmpty) {
          return const Center(
            child: Text(
              'No categories',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          );
        }

        final filtered = _searchQuery.isEmpty
            ? categories
            : categories
                  .where(
                    (e) => e.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
                  )
                  .toList();

        final letterIndexMap = _computeLetterIndex(filtered);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search…',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 24,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No results', style: TextStyle(fontSize: 12)),
                    )
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            return _CategoryRow(
                              entry: entry,
                              isSelected: entry.name == selected,
                              onTap: () => context.read<AppState>().setCategory(
                                entry.name,
                              ),
                            );
                          },
                        ),
                        _AlphabetSidebar(
                          availableLetters: letterIndexMap.keys.toSet(),
                          onLetterTap: (letter) =>
                              _scrollToLetter(letter, letterIndexMap),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Category row
// -----------------------------------------------------------------------------

class _CategoryRow extends StatelessWidget {
  final CategoryEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: _kItemHeight,
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                  left: BorderSide(color: Colors.blue[700]!, width: 3),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'asset/pix/${entry.firstSpeciesId}${entry.firstThumb}.jpg',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image, color: Colors.grey, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.name} (${entry.speciesCount})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue[700] : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Alphabet sidebar
// -----------------------------------------------------------------------------

class _AlphabetSidebar extends StatelessWidget {
  final Set<String> availableLetters;
  final void Function(String) onLetterTap;

  const _AlphabetSidebar({
    required this.availableLetters,
    required this.onLetterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: 16,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _allLetters.map((letter) {
          final available = availableLetters.contains(letter);
          return GestureDetector(
            onTap: available ? () => onLetterTap(letter) : null,
            child: SizedBox(
              height: 11,
              child: Text(
                letter,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: available ? Colors.blue[700] : Colors.grey[400],
                  height: 1.1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
