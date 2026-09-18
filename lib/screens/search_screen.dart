import 'package:flutter/material.dart';
import '../models/receipt_item.dart';
import '../services/firestore_service.dart';

/// Matches the wireframe: enter driver name, PE, token, contact/contract
/// or chassis number, and see all matching receipt rows across every
/// fuel record stored in Firestore.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _service = FirestoreService.instance;
  List<ReceiptItem>? _results;
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    final results = await _service.searchReceiptItems(_controller.text);
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Driver name / PE / Token / Chassis / Contract',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _results != null)
              Expanded(
                child: _results!.isEmpty
                    ? const Center(child: Text('Hakuna matokeo.'))
                    : ListView.separated(
                        itemCount: _results!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _results![i];
                          return ListTile(
                            title: Text('${r.driver} • ${r.token}'),
                            subtitle: Text(
                                'PE: ${r.pe} | Chassis: ${r.chassisNo} | Qty: ${r.qty} | Contract: ${r.contract}'),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
