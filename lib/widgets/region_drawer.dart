import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';


class RegionDrawer extends StatelessWidget {
  const RegionDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, topPadding + 20, 16, 20),
              child: Text(
                'Region',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: regionNames.length,
                itemBuilder: (context, index) {
                  final isSelected = appState.selectedRegion == index;
                  return ListTile(
                    title: Text(
                      regionNames[index],
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.blue[700] : null,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: Colors.blue[50],
                    leading: isSelected
                        ? Icon(Icons.check, color: Colors.blue[700], size: 18)
                        : const SizedBox(width: 18),
                    onTap: () {
                      context.read<AppState>().setRegion(index);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
