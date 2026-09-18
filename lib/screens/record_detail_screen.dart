import 'package:flutter/material.dart';
import '../models/fuel_record.dart';
import '../models/receipt_item.dart';
import '../services/firestore_service.dart';

/// Read-only view. Per the wireframe's note, editing/deleting is only
/// allowed from the "Fuel Record" (Start a Record) section, not here.
class RecordDetailScreen extends StatelessWidget {
  final FuelRecord record;
  const RecordDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService.instance;
    return Scaffold(
      appBar: AppBar(title: Text(record.pumpName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Prepared By', record.preparedByName),
            _row('Signature', record.preparedBySignature),
            _row('Opening Meter Reading', record.openingMeterReading.toString()),
            _row('Closing Meter Reading', record.closingMeterReading.toString()),
            _row('Opening Balance', record.openingBalance?.toString() ?? '-'),
            _row('Closing Balance', record.closingBalance?.toString() ?? '-'),
            const Divider(height: 32),
            Text('Receipt Information',
                style: Theme.of(context).textTheme.titleMedium),
            StreamBuilder<List<ReceiptItem>>(
              stream: service.watchReceiptItems(record.id),
              builder: (context, snap) {
                final items = snap.data ?? [];
                if (items.isEmpty) return const Text('Hakuna receipt.');
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('PE')),
                      DataColumn(label: Text('Driver')),
                      DataColumn(label: Text('Token')),
                      DataColumn(label: Text('Chassis')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Sign')),
                      DataColumn(label: Text('Contract')),
                    ],
                    rows: items
                        .map((i) => DataRow(cells: [
                              DataCell(Text(i.pe)),
                              DataCell(Text(i.driver)),
                              DataCell(Text(i.token)),
                              DataCell(Text(i.chassisNo)),
                              DataCell(Text(i.qty.toString())),
                              DataCell(Text(i.signature)),
                              DataCell(Text(i.contract)),
                            ]))
                        .toList(),
                  ),
                );
              },
            ),
            const Divider(height: 32),
            _row('Total Quantity Sold', record.totalQuantitySold?.toString() ?? '-'),
            _row('Status', record.submitted ? 'Submitted' : 'Draft (local, not yet uploaded)'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 170, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
