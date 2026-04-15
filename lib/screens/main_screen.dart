import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/category_list.dart';
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
      drawer: const AppDrawer(),
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
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [_RegionDropdown(), SizedBox(width: 16), _SuperCatDropdown()],
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

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: appState.selectedRegion,
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        dropdownColor: Colors.blue[700],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        alignment: AlignmentDirectional.centerEnd,
        items: List.generate(regionNames.length, (i) {
          return DropdownMenuItem<int>(
            alignment: AlignmentDirectional.centerEnd,
            value: i,
            child: Text(regionNames[i], textAlign: TextAlign.right),
          );
        }),
        onChanged: (value) {
          if (value != null) {
            context.read<AppState>().setRegion(value);
          }
        },
      ),
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
        alignment: AlignmentDirectional.centerEnd,
        items: _superCats.map((cat) {
          return DropdownMenuItem<String>(
            alignment: AlignmentDirectional.centerEnd,
            value: cat,
            child: Text(cat, textAlign: TextAlign.right),
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
        // LEFT PANEL — 50% width
        const Expanded(child: CategoryList()),
        // Vertical divider
        const VerticalDivider(width: 1, thickness: 1),
        // RIGHT PANEL — 50% width
        const Expanded(child: SpeciesList()),
      ],
    );
  }
}
