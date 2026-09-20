import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

/// One search box that matches driver name, PE, token, chassis, contract,
/// pump name, pump attendant name ("Prepared By"), or the record's date,
/// and shows every matching receipt row across every fuel record stored
/// in Firestore.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _service = FirestoreService.instance;
  final _df = DateFormat('dd/MM/yyyy');
  List<ReceiptSearchResult>? _results;
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _service.searchReceiptItems(_controller.text);
      setState(() => _results = results);
    } catch (e) {
      setState(() {
        _results = [];
        _error = 'Search failed: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
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
                labelText:
                    'Driver / PE / Token / Chassis / Contract / Pump Name / Prepared By / Date',
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
            if (!_loading && _error != null)
              Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (!_loading && _error == null && _results != null)
              Expanded(
                child: _results!.isEmpty
                    ? const Center(child: Text('No results found.'))
                    : ListView.separated(
                        itemCount: _results!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final result = _results![i];
                          final r = result.item;
                          final preparedBy = result.preparedByName.isEmpty
                              ? '-'
                              : result.preparedByName;
                          return ListTile(
                            title: Text('${r.driver} • ${r.token}'),
                            isThreeLine: true,
                            subtitle: Text(
                              'PE: ${r.pe} | Chassis: ${r.chassisNo} | Qty: ${r.qty} | Contract: ${r.contract}\n'
                              'Pump: ${result.pumpName} | Prepared By: $preparedBy | Date: ${_df.format(result.recordDate)}',
                            ),
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
