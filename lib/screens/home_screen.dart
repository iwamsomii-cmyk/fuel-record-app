import 'package:flutter/material.dart';
import 'start_record_screen.dart';
import 'records_list_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPSA Fuel Record')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _HomeTile(
              icon: Icons.add_box_outlined,
              label: 'Start a Record',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StartRecordScreen())),
            ),
            _HomeTile(
              icon: Icons.list_alt,
              label: 'View Fuel Record List',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RecordsListScreen())),
            ),
            _HomeTile(
              icon: Icons.search,
              label: 'Search',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
