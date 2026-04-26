import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: Colors.blue[700],
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 40),
            child: const Text(
              'Florent\'s Reef Guide',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search species'),
            onTap: () {
              Navigator.pop(context);
              context.push('/search');
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Browse the taxonomy tree'),
            onTap: () {
              Navigator.pop(context);
              context.push('/taxonomy');
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact'),
            onTap: () async {
              Navigator.pop(context);
              final uri = Uri(scheme: 'mailto', path: 'mobile@reefguide.org');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.computer_outlined),
            title: const Text('Desktop Version'),
            onTap: () async {
              Navigator.pop(context);
              final uri = Uri.parse('https://reefguide.org');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              context.push('/info');
            },
          ),
        ],
      ),
    );
  }
}
