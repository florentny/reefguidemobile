import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      appBar: AppBar(backgroundColor: Colors.blue[900], foregroundColor: Colors.white, elevation: 0),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 2, 24, 24),
                child: Text(
                  "Florent's guide to the marine life of the tropical reefs",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset('asset/img/photo1.jpg', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset('asset/img/photo2.jpg', fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const _SelectorsRow(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final s = context.read<AppState>();
                  context.push(
                    '/browse?region=${s.selectedRegion}'
                    '&supercat=${Uri.encodeComponent(s.selectedSuperCat)}',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[900],
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                child: const Text('Browse by categories'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[900],
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white54),
                  ),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  elevation: 0,
                ),
                child: const Text('Search by species name'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/taxonomy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[900],
                  padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white54),
                  ),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  elevation: 0,
                ),
                child: const Text('Browse by taxonomy'),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '\u00a9 2026 Florent Charpin - https://reefguide.org',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorsRow extends StatelessWidget {
  const _SelectorsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _RadioColumn<String>(
                values: AppState.superCats,
                labelOf: AppState.superCatLabel,
                selected: context.watch<AppState>().selectedSuperCat,
                onChanged: (v) => context.read<AppState>().setSuperCat(v),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _RadioColumn<int>(
                values: List.generate(regionNames.length, (i) => i),
                labelOf: (i) => regionNames[i],
                selected: context.watch<AppState>().selectedRegion,
                onChanged: (v) => context.read<AppState>().setRegion(v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioColumn<T> extends StatelessWidget {
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  const _RadioColumn({required this.values, required this.labelOf, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...values.map((v) {
            final isSelected = v == selected;
            return InkWell(
              onTap: () => onChanged(v),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.white : Colors.white54, width: 2),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labelOf(v),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
