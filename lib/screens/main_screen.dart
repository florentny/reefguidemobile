import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/appbar_dropdown.dart';
import '../widgets/category_list.dart';
import '../widgets/species_list.dart';


class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _ReefAppBar(), drawer: const AppDrawer(), body: const _MainBody());
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
      labelOf: (v) => v,
      onChanged: (v) => context.read<AppState>().setSuperCat(v),
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
