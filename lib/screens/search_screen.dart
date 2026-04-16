import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/species.dart';
import '../models/taxonomy_node.dart';
import '../providers/app_state.dart';
import '../services/data_service.dart';
import '../widgets/appbar_dropdown.dart';

enum _SortMode { commonName, sciName }

const double _kItemHeight = 80.0;

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

class _TaxInfo {
  final String superCat;
  final String? familyName;
  final String? orderName;
  final String? categoryLabel;
  const _TaxInfo({required this.superCat, this.familyName, this.orderName, this.categoryLabel});
}

class _SearchResult {
  final Species species;
  final String? familyName;
  final String? orderName;
  final String? categoryLabel;
  const _SearchResult({required this.species, this.familyName, this.orderName, this.categoryLabel});
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // All species from species_all.json — loaded once.
  List<Species> _allSpecies = [];

  // id → taxonomy info for the currently loaded region.
  Map<String, _TaxInfo> _regionMap = {};
  int _loadedRegion = -1;
  bool _taxonomyLoading = false;

  bool _speciesLoading = true;
  String _query = '';
  _SortMode _sortMode = _SortMode.commonName;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  // AppState listener reference so we can remove it on dispose.
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    DataService.instance.getAllSpecies().then((list) {
      if (!mounted) return;
      setState(() {
        _allSpecies = list;
        _speciesLoading = false;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context, listen: false);
    // Register listener once.
    if (!_listeningToAppState) {
      _listeningToAppState = true;
      _appState = appState;
      _appState.addListener(_onAppStateChanged);
      _loadTaxonomy(appState.selectedRegion);
    }
  }

  bool _listeningToAppState = false;

  @override
  void dispose() {
    if (_listeningToAppState) _appState.removeListener(_onAppStateChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Returns the text used as the sort/index key for a result.
  String _primaryKey(_SearchResult r) {
    if (_sortMode == _SortMode.sciName) {
      return r.species.sciName.isNotEmpty ? r.species.sciName : (r.familyName ?? r.orderName ?? r.species.name);
    }
    return r.species.name;
  }

  Map<String, int> _computeLetterIndex(List<_SearchResult> results) {
    final map = <String, int>{};
    for (var i = 0; i < results.length; i++) {
      final first = _primaryKey(results[i]).toUpperCase();
      if (first.isEmpty) continue;
      final key = RegExp(r'[A-Z]').hasMatch(first[0]) ? first[0] : '#';
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

  void _onAppStateChanged() {
    final region = _appState.selectedRegion;
    if (region != _loadedRegion && !_taxonomyLoading) {
      _loadTaxonomy(region);
    }
    // superCat change is handled by context.watch in build — no reload needed.
    if (mounted) setState(() {});
  }

  Future<void> _loadTaxonomy(int region) async {
    setState(() => _taxonomyLoading = true);
    final TaxonomyNode root = await DataService.instance.getTaxonomy(region);
    if (!mounted) return;
    final map = <String, _TaxInfo>{};

    void walk(TaxonomyNode node, String? order, String? family, String? category) {
      final rank = node.rank;
      if (rank == 'Order') {
        order = node.name;
        family = null;
      } else if (rank == 'Family') {
        family = node.name;
      }
      if (node.category != null) category = node.category;
      for (final ref in node.species) {
        map[ref.id] = _TaxInfo(superCat: ref.superCat, familyName: family, orderName: order, categoryLabel: category);
      }
      for (final child in node.children) {
        walk(child, order, family, category);
      }
    }

    walk(root, null, null, null);
    setState(() {
      _regionMap = map;
      _loadedRegion = region;
      _taxonomyLoading = false;
    });
  }

  void _onQueryChanged(String query) {
    setState(() => _query = query);
  }

  void _clearQuery() {
    _controller.clear();
    setState(() => _query = '');
  }

  List<_SearchResult> _computeFiltered(String superCat) {
    final q = _query.toLowerCase();
    final results = <_SearchResult>[];
    for (final s in _allSpecies) {
      final info = _regionMap[s.id];
      if (info == null || info.superCat != superCat) continue;
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.sciName.toLowerCase().contains(q) &&
          !(info.categoryLabel?.toLowerCase().contains(q) ?? false)) {
        continue;
      }
      results.add(
        _SearchResult(
          species: s,
          familyName: info.familyName,
          orderName: info.orderName,
          categoryLabel: info.categoryLabel,
        ),
      );
    }
    results.sort((a, b) {
      if (_sortMode == _SortMode.commonName) {
        return a.species.name.compareTo(b.species.name);
      }
      // Scientific name sort: fall back to family → order when sciName is empty.
      final aKey = a.species.sciName.isNotEmpty ? a.species.sciName : (a.familyName ?? a.orderName ?? a.species.name);
      final bKey = b.species.sciName.isNotEmpty ? b.species.sciName : (b.familyName ?? b.orderName ?? b.species.name);
      return aKey.compareTo(bKey);
    });
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final superCat = appState.selectedSuperCat;

    final loading = _speciesLoading || _taxonomyLoading;
    final filtered = loading ? <_SearchResult>[] : _computeFiltered(superCat);
    final ids = filtered.map((r) => r.species.id).toList();

    return Scaffold(
      appBar: _SearchAppBar(onBack: () => context.pop()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search by common or scientific name…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _clearQuery)
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          // Count + sort toggle on the same row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 12, 2),
            child: Row(
              children: [
                if (!loading)
                  Text(
                    _query.isEmpty
                        ? '${filtered.length} species'
                        : '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                const Spacer(),
                SegmentedButton<_SortMode>(
                  segments: const [
                    ButtonSegment(value: _SortMode.commonName, label: Text('Common name')),
                    ButtonSegment(value: _SortMode.sciName, label: Text('Scientific name')),
                  ],
                  selected: {_sortMode},
                  onSelectionChanged: (selection) => setState(() => _sortMode = selection.first),
                  style: SegmentedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          // List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? 'No species' : 'No results',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final letterIndexMap = _computeLetterIndex(filtered);
                      return Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(right: 24),
                            itemCount: filtered.length,
                            itemExtent: _kItemHeight,
                            itemBuilder: (context, index) {
                              final result = filtered[index];
                              return _SearchSpeciesCard(
                                species: result.species,
                                familyName: result.familyName,
                                orderName: result.orderName,
                                categoryLabel: result.categoryLabel,
                                sortMode: _sortMode,
                                query: _query,
                                onTap: () {
                                  appState.openSpecies(result.species.id, ids);
                                  context.push('/search/species/${result.species.id}');
                                },
                              );
                            },
                          ),
                          _AlphabetSidebar(
                            availableLetters: letterIndexMap.keys.toSet(),
                            onLetterTap: (letter) => _scrollToLetter(letter, letterIndexMap),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// AppBar — matches MainScreen style with region + superCat dropdowns
// -----------------------------------------------------------------------------

class _SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBack;

  const _SearchAppBar({required this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [_SuperCatDropdown(), SizedBox(width: 8), _RegionDropdown()],
      ),
      centerTitle: false,
    );
  }
}

class _RegionDropdown extends StatelessWidget {
  const _RegionDropdown();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return AppBarDropdown<int>(
      value: appState.selectedRegion,
      items: List.generate(regionNames.length, (i) => i),
      labelOf: (i) => regionNames[i],
      onChanged: (v) => context.read<AppState>().setRegion(v),
    );
  }
}

class _SuperCatDropdown extends StatelessWidget {
  const _SuperCatDropdown();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return AppBarDropdown<String>(
      value: appState.selectedSuperCat,
      items: AppState.superCats,
      labelOf: AppState.superCatLabel,
      onChanged: (v) => context.read<AppState>().setSuperCat(v),
    );
  }
}

// -----------------------------------------------------------------------------
// Species card
// -----------------------------------------------------------------------------

class _SearchSpeciesCard extends StatelessWidget {
  final Species species;
  final String? familyName;
  final String? orderName;
  final String? categoryLabel;
  final _SortMode sortMode;
  final String query;
  final VoidCallback onTap;

  const _SearchSpeciesCard({
    required this.species,
    required this.sortMode,
    required this.query,
    required this.onTap,
    this.familyName,
    this.orderName,
    this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final thumbId = species.thumbs.isNotEmpty ? species.thumbs.first : 1;
    final sciMode = sortMode == _SortMode.sciName;

    // Primary line: scientific name in sci mode, common name otherwise.
    // Fallback for missing sci name: family → order.
    final String primaryText;
    final bool primaryIsItalic;
    final bool primaryHighlight;
    if (sciMode) {
      if (species.sciName.isNotEmpty) {
        primaryText = species.sciName;
        primaryIsItalic = true;
        primaryHighlight = true;
      } else {
        primaryText = familyName ?? orderName ?? species.name;
        primaryIsItalic = true;
        primaryHighlight = false; // fallback label — don't highlight
      }
    } else {
      primaryText = species.name;
      primaryIsItalic = false;
      primaryHighlight = true;
    }

    // Secondary line.
    final String? secondaryText;
    final bool secondaryIsItalic;
    final bool secondaryHighlight;
    if (sciMode) {
      secondaryText = species.name.isNotEmpty ? species.name : null;
      secondaryIsItalic = false;
      secondaryHighlight = true;
    } else {
      if (species.sciName.isNotEmpty) {
        secondaryText = species.sciName;
        secondaryIsItalic = true;
        secondaryHighlight = true;
      } else {
        secondaryText = familyName ?? orderName;
        secondaryIsItalic = true;
        secondaryHighlight = false;
      }
    }

    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 107,
              height: 80,
              child: Image.asset(
                'asset/pix/${species.id}$thumbId.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.camera_alt, color: Colors.grey, size: 32),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HighlightText(
                      text: primaryText,
                      query: primaryHighlight ? query : '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontStyle: primaryIsItalic ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    if (secondaryText != null)
                      _HighlightText(
                        text: secondaryText,
                        query: secondaryHighlight ? query : '',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: secondaryIsItalic ? FontStyle.italic : FontStyle.normal,
                          color: Colors.black54,
                        ),
                      ),
                    if (categoryLabel != null && categoryLabel!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          categoryLabel!,
                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Highlight matching text in bold teal
// -----------------------------------------------------------------------------

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightText({required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final lowerText = text.toLowerCase();
    final matchStart = lowerText.indexOf(query.toLowerCase());

    if (matchStart < 0) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final matchEnd = matchStart + query.length;
    final boldStyle = style.copyWith(fontWeight: FontWeight.bold, color: Colors.teal[700]);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (matchStart > 0) TextSpan(text: text.substring(0, matchStart)),
          TextSpan(text: text.substring(matchStart, matchEnd), style: boldStyle),
          if (matchEnd < text.length) TextSpan(text: text.substring(matchEnd)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// -----------------------------------------------------------------------------
// Alphabet sidebar
// -----------------------------------------------------------------------------

class _AlphabetSidebar extends StatelessWidget {
  final Set<String> availableLetters;
  final void Function(String) onLetterTap;

  const _AlphabetSidebar({required this.availableLetters, required this.onLetterTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _allLetters.map((letter) {
          final available = availableLetters.contains(letter);
          return GestureDetector(
            onTap: available ? () => onLetterTap(letter) : null,
            child: SizedBox(
              height: 18,
              child: Text(
                letter,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
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
