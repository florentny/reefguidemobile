import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/data_service.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, title: const Text('About')),
      body: FutureBuilder<AppStats>(
        future: DataService.instance.getStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Stats ──────────────────────────────────────────────────
                Text(
                  'Statistics',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Species',
                  value: stats != null ? '${stats.speciesCount}' : '—',
                  loading: stats == null,
                ),
                _StatRow(label: 'Photos', value: stats != null ? '${stats.photoCount}' : '—', loading: stats == null),
                _StatRow(
                  label: 'Categories',
                  value: stats != null ? '${stats.categoryCount}' : '—',
                  loading: stats == null,
                ),
                const SizedBox(height: 32),

                // ── Website ───────────────────────────────────────────────
                Text(
                  'Website',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                ),
                const SizedBox(height: 12),
                const Text('https://reefguide.org', style: TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 32),

                // ── Contact ───────────────────────────────────────────────
                Text(
                  'Contact',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                ),
                const SizedBox(height: 12),
                const Text('mobile@reefguide.org', style: TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 32),

                // ── Privacy Policy ────────────────────────────────────────
                Text(
                  'Privacy Policy',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://reefguide.org/privacy_policy.txt'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text(
                    'https://reefguide.org/privacy_policy.txt',
                    style: TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Copyright ──────────────────────────────────────────────
                Text(
                  'Copyright',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                ),
                const SizedBox(height: 12),
                const Text(
                  '\u00a9 2026 Florent Charpin. All rights reserved.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Text(
                  'All photographs in this application are the exclusive property of Florent Charpin, unless explicitly stated otherwise.'
                  'Unauthorized use, reproduction, distribution, or modification of any content is strictly prohibited without prior written permission from the copyright holder.',
                  style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool loading;

  const _StatRow({required this.label, required this.value, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}
