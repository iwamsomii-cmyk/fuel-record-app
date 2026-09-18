import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fuel_record.dart';
import '../services/firestore_service.dart';
import 'record_detail_screen.dart';

class RecordsListScreen extends StatelessWidget {
  const RecordsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService.instance;
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Record List')),
      body: StreamBuilder<List<FuelRecord>>(
        stream: service.watchAllRecords(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snap.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text('Hakuna record bado.'));
          }
          return ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = records[i];
              return ListTile(
                leading: Icon(
                  r.submitted ? Icons.cloud_done : Icons.cloud_off,
                  color: r.submitted ? Colors.green : Colors.orange,
                ),
                title: Text(r.pumpName),
                subtitle: Text(
                    '${r.preparedByName} • ${df.format(r.preparedByDate)}'),
                trailing: Text(r.submitted ? 'Submitted' : 'Draft'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RecordDetailScreen(record: r)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
