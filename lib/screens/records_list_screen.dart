import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fuel_record.dart';
import '../services/firestore_service.dart';
import 'record_detail_screen.dart';

class RecordsListScreen extends StatefulWidget {
  const RecordsListScreen({super.key});

  @override
  State<RecordsListScreen> createState() => _RecordsListScreenState();
}

class _RecordsListScreenState extends State<RecordsListScreen> {
  final _service = FirestoreService.instance;
  final _df = DateFormat('dd/MM/yyyy HH:mm');
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Record List')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by pump name or pump attendant name',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<FuelRecord>>(
              stream: _service.watchAllRecords(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var records = snap.data ?? [];
                if (_query.isNotEmpty) {
                  final q = _query.toLowerCase();
                  records = records
                      .where((r) =>
                          r.pumpName.toLowerCase().contains(q) ||
                          (r.totalPreparedByName ?? '')
                              .toLowerCase()
                              .contains(q))
                      .toList();
                }
                if (records.isEmpty) {
                  return Center(
                    child: Text(_query.isEmpty
                        ? 'No records yet.'
                        : 'No records found matching "$_query".'),
                  );
                }
                return ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = records[i];
                    final attendant = r.totalPreparedByName;
                    final subtitle = (attendant == null || attendant.isEmpty)
                        ? _df.format(r.preparedByDate)
                        : '${_df.format(r.preparedByDate)} • Prepared by: $attendant';
                    return ListTile(
                      leading: Icon(
                        r.submitted ? Icons.cloud_done : Icons.cloud_off,
                        color: r.submitted ? Colors.green : Colors.orange,
                      ),
                      title: Text(r.pumpName),
                      subtitle: Text(subtitle),
                      trailing: Text(r.submitted ? 'Submitted' : 'Draft'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RecordDetailScreen(record: r)),
                      ),
                    );
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
