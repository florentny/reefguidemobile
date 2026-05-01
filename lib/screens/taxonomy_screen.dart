import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/species.dart';
import '../models/taxonomy_node.dart';
import '../providers/app_state.dart';
import '../services/data_service.dart';
import '../widgets/appbar_dropdown.dart';

const double _kItemHeight = 80.0;

const List<String> _kAlphabetLetters = [
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
  final String? familyName;
  final String? orderName;
  final String? categoryLabel;
  const _TaxInfo({this.familyName, this.orderName, this.categoryLabel});
}

class _SpeciesItem {
  final Species species;
  final String? familyName;
  final String? orderName;
  final String? categoryLabel;
  const _SpeciesItem({required this.species, this.familyName, this.orderName, this.categoryLabel});
}

class _TreeItem {
  final TaxonomyNode node;
  final int depth;
  const _TreeItem(this.node, this.depth);
}

class TaxonomyScreen extends StatefulWidget {
  const TaxonomyScreen({super.key});

  @override
  State<TaxonomyScreen> createState() => _TaxonomyScreenState();
}

class _TaxonomyScreenState extends State<TaxonomyScreen> {
  TaxonomyNode? _root;
  Map<String, Species> _speciesMap = {};
  Map<String, _TaxInfo> _taxInfoMap = {};
  bool _loading = true;
  int _loadedRegion = -1;
  String _loadedSuperCat = '';

  final Set<TaxonomyNode> _expandedNodes = {};
  TaxonomyNode? _selectedNode;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  late AppState _appState;
  bool _listeningToAppState = false;

  @override
  void initState() {
    super.initState();
    DataService.instance.getAllSpecies().then((list) {
      if (!mounted) return;
      setState(() => _speciesMap = {for (final s in list) s.id: s});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context, listen: false);
    if (!_listeningToAppState) {
      _listeningToAppState = true;
      _appState = appState;
      _appState.addListener(_onAppStateChanged);
      _loadTaxonomy(appState.selectedRegion);
    }
  }

  @override
  void dispose() {
    if (_listeningToAppState) _appState.removeListener(_onAppStateChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    final region = _appState.selectedRegion;
    final superCat = _appState.selectedSuperCat;
    if (region != _loadedRegion) {
      if (!_loading) _loadTaxonomy(region);
    } else if (superCat != _loadedSuperCat && mounted) {
      setState(() {
        _loadedSuperCat = superCat;
        _expandedNodes.clear();
        _selectedNode = null;
        if (_root != null) _preExpand(_root!.children, superCat);
      });
    }
  }

  Future<void> _loadTaxonomy(int region) async {
    setState(() {
      _loading = true;
      _expandedNodes.clear();
      _selectedNode = null;
    });
    final root = await DataService.instance.getTaxonomy(region);
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
        map[ref.id] = _TaxInfo(familyName: family, orderName: order, categoryLabel: category);
      }
      for (final child in node.children) {
        walk(child, order, family, category);
      }
    }

    walk(root, null, null, null);

    setState(() {
      _root = root;
      _taxInfoMap = map;
      _loadedRegion = region;
      _loadedSuperCat = _appState.selectedSuperCat;
      _loading = false;
      _preExpand(root.children, _appState.selectedSuperCat);
    });
  }

  void _preExpand(List<TaxonomyNode> nodes, String superCat) {
    final visible = nodes.where((n) => _nodeHasSpecies(n, superCat)).toList();
    if (visible.length == 1) {
      _expandedNodes.add(visible.first);
      _preExpand(visible.first.children, superCat);
    }
  }

  bool _nodeHasSpecies(TaxonomyNode node, String superCat) {
    if (superCat == 'All Species') return node.allSpecies.isNotEmpty;
    return node.allSpecies.any((r) => r.superCat == superCat);
  }

  List<_TreeItem> _buildVisibleItems(List<TaxonomyNode> nodes, int depth, String superCat) {
    final items = <_TreeItem>[];
    for (final node in nodes) {
      if (!_nodeHasSpecies(node, superCat)) continue;
      items.add(_TreeItem(node, depth));
      if (_expandedNodes.contains(node) && node.children.isNotEmpty) {
        items.addAll(_buildVisibleItems(node.children, depth + 1, superCat));
      }
    }
    return items;
  }

  List<_SpeciesItem> _buildSpeciesList(String superCat) {
    if (_root == null || _speciesMap.isEmpty) return [];
    final refs = (_selectedNode ?? _root!).allSpecies;
    final result = <_SpeciesItem>[];
    for (final ref in refs) {
      if (superCat != 'All Species' && ref.superCat != superCat) continue;
      final species = _speciesMap[ref.id];
      if (species == null) continue;
      final info = _taxInfoMap[ref.id];
      result.add(
        _SpeciesItem(
          species: species,
          familyName: info?.familyName,
          orderName: info?.orderName,
          categoryLabel: info?.categoryLabel,
        ),
      );
    }
    result.sort((a, b) {
      final aKey = a.species.sciName.isNotEmpty ? a.species.sciName : (a.familyName ?? a.orderName ?? a.species.name);
      final bKey = b.species.sciName.isNotEmpty ? b.species.sciName : (b.familyName ?? b.orderName ?? b.species.name);
      return aKey.compareTo(bKey);
    });
    // Remove duplicate entries for the same species (male/female or phase variants share sciName).
    final seen = <String>{};
    result.removeWhere((item) {
      final key = item.species.sciName.isNotEmpty ? item.species.sciName : item.species.id;
      return !seen.add(key);
    });
    return result;
  }

  String _primaryKey(_SpeciesItem item) {
    return item.species.sciName.isNotEmpty
        ? item.species.sciName
        : (item.familyName ?? item.orderName ?? item.species.name);
  }

  Map<String, int> _computeLetterIndex(List<_SpeciesItem> items) {
    final map = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final first = _primaryKey(items[i]).toUpperCase();
      if (first.isEmpty) continue;
      final key = RegExp(r'[A-Z]').hasMatch(first[0]) ? first[0] : '#';
      map.putIfAbsent(key, () => i);
    }
    return map;
  }

  void _scrollToLetter(String letter, Map<String, int> letterIndexMap) {
    final index = letterIndexMap[letter];
    if (index == null) return;
    _scrollController.animateTo(
      (index * _kItemHeight).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  bool _isDescendant(TaxonomyNode ancestor, TaxonomyNode target) {
    for (final child in ancestor.children) {
      if (child == target || _isDescendant(child, target)) return true;
    }
    return false;
  }

  // Returns the path from root's children down to [target], inclusive, or null if not found.
  List<TaxonomyNode>? _pathToNode(List<TaxonomyNode> nodes, TaxonomyNode target) {
    for (final node in nodes) {
      if (node == target) return [node];
      final sub = _pathToNode(node.children, target);
      if (sub != null) return [node, ...sub];
    }
    return null;
  }

  void _collectDescendants(TaxonomyNode node, Set<TaxonomyNode> result) {
    for (final child in node.children) {
      result.add(child);
      _collectDescendants(child, result);
    }
  }

  TaxonomyNode? _searchInNodes(List<TaxonomyNode> nodes, String query, String superCat) {
    for (final node in nodes) {
      if (!_nodeHasSpecies(node, superCat)) continue;
      if (node.name.toLowerCase().contains(query) ||
          (node.category != null && node.category!.toLowerCase().contains(query))) {
        return node;
      }
      final sub = _searchInNodes(node.children, query, superCat);
      if (sub != null) return sub;
    }
    return null;
  }

  void _navigateToMatch(TaxonomyNode node, String superCat) {
    final path = _pathToNode(_root!.children, node);
    if (path == null) return;
    final pathSet = path.toSet();
    final descendants = <TaxonomyNode>{};
    _collectDescendants(node, descendants);
    _expandedNodes.addAll(path);
    _expandedNodes.removeWhere((n) => !pathSet.contains(n) && !descendants.contains(n));
    _selectedNode = node;
  }

  void _onNodeTap(TaxonomyNode node, String superCat) {
    setState(() {
      final hasVisibleChildren = node.children.any((c) => _nodeHasSpecies(c, superCat));
      if (hasVisibleChildren) {
        if (_expandedNodes.contains(node)) {
          _expandedNodes.remove(node);
          if (_selectedNode != null && _isDescendant(node, _selectedNode!)) {
            _selectedNode = node;
          }
        } else {
          _expandedNodes.add(node);
        }
      }
      _selectedNode = node;

      // Collapse nodes that are neither on the path to the selected node
      // nor descendants of it.
      if (_root != null) {
        final path = _pathToNode(_root!.children, node);
        if (path != null) {
          final pathSet = path.toSet();
          final descendants = <TaxonomyNode>{};
          _collectDescendants(node, descendants);
          _expandedNodes.removeWhere((n) => !pathSet.contains(n) && !descendants.contains(n));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final superCat = appState.selectedSuperCat;

    final treeItems = _loading || _root == null ? <_TreeItem>[] : _buildVisibleItems(_root!.children, 0, superCat);

    final speciesItems = _loading ? <_SpeciesItem>[] : _buildSpeciesList(superCat);
    final letterIndexMap = _computeLetterIndex(speciesItems);
    final ids = speciesItems.map((s) => s.species.id).toList();

    return Scaffold(
      appBar: _TaxonomyAppBar(onBack: () => context.canPop() ? context.pop() : context.go('/')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 6, 2),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        constraints: const BoxConstraints.tightFor(height: 24),
                        hintText: 'Search taxonomy…',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 14),
                        prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 24),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                padding: EdgeInsets.zero,
                                onPressed: () => setState(() => _searchController.clear()),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 0),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 6),
                      ),
                      onChanged: (text) {
                        if (text.isEmpty || _root == null) {
                          setState(() {});
                          return;
                        }
                        final q = text.toLowerCase();
                        final match = _searchInNodes(_root!.children, q, _appState.selectedSuperCat);
                        setState(() {
                          if (match != null) _navigateToMatch(match, _appState.selectedSuperCat);
                        });
                      },
                    ),
                  ),
                ),
                // Taxonomy tree
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.30),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: treeItems.map((item) {
                        final isExpanded = _expandedNodes.contains(item.node);
                        final hasVisibleChildren = item.node.children.any((c) => _nodeHasSpecies(c, superCat));
                        final count = superCat == 'All Species'
                            ? item.node.allSpecies.length
                            : item.node.allSpecies.where((r) => r.superCat == superCat).length;
                        return _TreeNodeRow(
                          item: item,
                          isSelected: item.node == _selectedNode,
                          isExpanded: isExpanded,
                          hasChildren: hasVisibleChildren,
                          speciesCount: count,
                          onTap: () => _onNodeTap(item.node, superCat),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Count + selected node info
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${speciesItems.length} species',
                        style: const TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                      if (_selectedNode != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: _selectedNode!.name,
                                  style: TextStyle(fontSize: 14, color: Colors.blue[800], fontStyle: FontStyle.italic),
                                ),
                                if (_selectedNode!.category != null && _selectedNode!.category!.isNotEmpty) ...[
                                  TextSpan(
                                    text: ' · ',
                                    style: const TextStyle(fontSize: 14, color: Colors.black38),
                                  ),
                                  TextSpan(
                                    text: _selectedNode!.category!,
                                    style: TextStyle(fontSize: 14, color: Colors.blueGrey[600]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 8),
                // Species list
                Expanded(
                  child: speciesItems.isEmpty
                      ? const Center(
                          child: Text(
                            'Select a node to see species',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        )
                      : Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.only(right: 24, bottom: MediaQuery.paddingOf(context).bottom),
                              itemCount: speciesItems.length,
                              itemExtent: _kItemHeight,
                              itemBuilder: (context, index) {
                                final item = speciesItems[index];
                                return _SpeciesCard(
                                  item: item,
                                  onTap: () {
                                    appState.openSpecies(item.species.id, ids);
                                    context.push('/taxonomy/species/${item.species.id}');
                                  },
                                );
                              },
                            ),
                            _AlphabetSidebar(
                              availableLetters: letterIndexMap.keys.toSet(),
                              onLetterTap: (l) => _scrollToLetter(l, letterIndexMap),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// AppBar
// -----------------------------------------------------------------------------

class _TaxonomyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBack;
  const _TaxonomyAppBar({required this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      titleSpacing: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [_SuperCatDropdown(), SizedBox(width: 2), _RegionDropdown()],
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
      onChanged: (v) {
        final s = context.read<AppState>();
        s.setRegion(v);
        context.replace('/taxonomy?region=$v&supercat=${Uri.encodeComponent(s.selectedSuperCat)}');
      },
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
      onChanged: (v) {
        final s = context.read<AppState>();
        s.setSuperCat(v);
        context.replace('/taxonomy?region=${s.selectedRegion}&supercat=${Uri.encodeComponent(v)}');
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Tree node row
// -----------------------------------------------------------------------------

class _TreeNodeRow extends StatelessWidget {
  final _TreeItem item;
  final bool isSelected;
  final bool isExpanded;
  final bool hasChildren;
  final int speciesCount;
  final VoidCallback onTap;

  const _TreeNodeRow({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.hasChildren,
    required this.speciesCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final node = item.node;
    final isGenus = node.rank == 'Genus';
    final nameColor = isSelected ? Colors.blue[800]! : Colors.black87;
    final metaColor = Colors.grey[500]!;
    final categoryColor = Colors.blueGrey[600]!;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : null,
          border: isSelected
              ? const Border(left: BorderSide(color: Colors.blue, width: 3))
              : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
        ),
        padding: EdgeInsets.only(left: 2.0 + item.depth * 10.0, right: 6, top: 2, bottom: 2),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: hasChildren
                  ? Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: isSelected ? Colors.blue[700] : Colors.grey[600],
                    )
                  : Icon(Icons.circle, size: 6, color: Colors.grey[400]),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: node.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: nameColor,
                      ),
                    ),
                    if (node.rank.isNotEmpty)
                      TextSpan(
                        text: ' (${node.rank})',
                        style: TextStyle(fontSize: 10, color: metaColor, fontWeight: FontWeight.normal),
                      ),
                    if (node.category != null && node.category!.isNotEmpty)
                      TextSpan(
                        text: ' ${node.category}',
                        style: TextStyle(
                          fontSize: 12,
                          color: categoryColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    TextSpan(
                      text: ' ($speciesCount)',
                      style: TextStyle(fontSize: 11, color: metaColor, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Species card (matches search screen style)
// -----------------------------------------------------------------------------

class _SpeciesCard extends StatelessWidget {
  final _SpeciesItem item;
  final VoidCallback onTap;

  const _SpeciesCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final species = item.species;
    final thumbId = species.thumbs.isNotEmpty ? species.thumbs.first : 1;
    const sciMode = true;

    final String primaryText;
    final bool primaryIsItalic;
    if (sciMode && species.sciName.isNotEmpty) {
      primaryText = species.sciName;
      primaryIsItalic = true;
    } else if (sciMode) {
      primaryText = item.familyName ?? item.orderName ?? species.name;
      primaryIsItalic = true;
    } else {
      primaryText = species.name;
      primaryIsItalic = false;
    }

    final String? secondaryText;
    final bool secondaryIsItalic;
    if (sciMode) {
      secondaryText = species.name.isNotEmpty ? species.name : null;
      secondaryIsItalic = false;
    } else if (species.sciName.isNotEmpty) {
      secondaryText = species.sciName;
      secondaryIsItalic = true;
    } else {
      secondaryText = item.familyName ?? item.orderName;
      secondaryIsItalic = true;
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
              height: _kItemHeight,
              child: Image.asset(
                pixPath(species.id, thumbId),
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
                    Text(
                      primaryText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontStyle: primaryIsItalic ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondaryText != null && secondaryText.isNotEmpty)
                      Text(
                        secondaryText,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: secondaryIsItalic ? FontStyle.italic : FontStyle.normal,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (item.categoryLabel != null && item.categoryLabel!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.categoryLabel!,
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
        children: _kAlphabetLetters.map((letter) {
          final available = availableLetters.contains(letter);
          return Expanded(
            child: GestureDetector(
              onTap: available ? () => onLetterTap(letter) : null,
              child: Center(
                child: Text(
                  letter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: available ? Colors.blue[700] : Colors.grey[400],
                    height: 1.0,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
