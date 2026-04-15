import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:go_router/go_router.dart';

import '../providers/app_state.dart';
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

const List<String> _regionNames = [
  'Worldwide',
  'Caribbean',
  'Pacific',
  'South Florida',
  'Hawaii',
  'Eastern Pacific',
  'French Polynesia',
];

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ReefAppBar(),
      drawer: const _AppDrawer(),
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
        items: List.generate(_regionNames.length, (i) {
          return DropdownMenuItem<int>(
            alignment: AlignmentDirectional.centerEnd,
            value: i,
            child: Text(_regionNames[i], textAlign: TextAlign.right),
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
// Drawer
// -----------------------------------------------------------------------------

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[700]),
            child: const Text(
              'reefguide.org',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context); // close drawer
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context); // close drawer
              context.push('/info');
            },
          ),
        ],
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
