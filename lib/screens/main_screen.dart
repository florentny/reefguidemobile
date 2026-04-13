import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/category_list.dart';
import '../widgets/region_drawer.dart';
import '../widgets/species_list.dart';

const List<String> _superCats = [
  'Fish',
  'Invertebrates',
  'Sponges',
  'Corals',
  'Algae',
  'Mammals',
];

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ReefAppBar(),
      drawer: const RegionDrawer(),
      body: const _MainBody(),
    );
  }
}

// -----------------------------------------------------------------------------
// AppBar implemented as a PreferredSizeWidget
// -----------------------------------------------------------------------------

class _ReefAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      leading: Builder(
        builder: (innerContext) => IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Select region',
          onPressed: () => Scaffold.of(innerContext).openDrawer(),
        ),
      ),
      title: const _SuperCatDropdown(),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Info',
          // No-op as specified
          onPressed: () {},
        ),
      ],
    );
  }
}

class _SuperCatDropdown extends StatelessWidget {
  const _SuperCatDropdown();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: appState.selectedSuperCat,
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        dropdownColor: Colors.blue[700],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        items: _superCats.map((cat) {
          return DropdownMenuItem<String>(
            value: cat,
            child: Text(cat),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            context.read<AppState>().setSuperCat(value);
          }
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Two-column body
// -----------------------------------------------------------------------------

class _MainBody extends StatelessWidget {
  const _MainBody();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT PANEL — fixed 160px category list
        const SizedBox(
          width: 160,
          child: CategoryList(),
        ),
        // Vertical divider
        const VerticalDivider(width: 1, thickness: 1),
        // RIGHT PANEL — species list fills remaining space
        const Expanded(child: SpeciesList()),
      ],
    );
  }
}
