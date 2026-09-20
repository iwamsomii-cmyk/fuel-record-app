import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fuel_record.dart';
import '../models/receipt_item.dart';
import '../services/firestore_service.dart';
import '../widgets/signature_field.dart';

/// Read-only view. Per the wireframe's note, editing/deleting is only
/// allowed from the "Fuel Record" (Start a Record) section, not here.
class RecordDetailScreen extends StatelessWidget {
  final FuelRecord record;
  const RecordDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService.instance;
    final df = DateFormat('dd/MM/yyyy');
    // Time is auto-captured from the device clock at the moment each
    // action happens (record started, each receipt saved, record
    // submitted) - never typed in manually. Devices used for this app
    // are set to Tanzania (Dar es Salaam / EAT), so this already reflects
    // Dar es Salaam local time.
    final tf = DateFormat('HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(record.pumpName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Date', df.format(record.preparedByDate)),
            _row('Time', tf.format(record.createdAt)),
            _row('Opening Meter Reading', record.openingMeterReading.toString()),
            _row('Closing Meter Reading', record.closingMeterReading?.toString() ?? '-'),
            _row('Opening Balance', record.openingBalance?.toString() ?? '-'),
            _row('Closing Balance', record.closingBalance?.toString() ?? '-'),
            const Divider(height: 32),
            Text('Receipt Information',
                style: Theme.of(context).textTheme.titleMedium),
            StreamBuilder<List<ReceiptItem>>(
              stream: service.watchReceiptItems(record.id),
              builder: (context, snap) {
                final items = snap.data ?? [];
                if (items.isEmpty) return const Text('No receipts.');
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
                      DataColumn(label: Text('Time')),
                    ],
                    rows: items
                        .map((i) => DataRow(cells: [
                              DataCell(Text(i.pe)),
                              DataCell(Text(i.driver)),
                              DataCell(Text(i.token)),
                              DataCell(Text(i.chassisNo)),
                              DataCell(Text(i.qty.toString())),
                              DataCell(SignatureField.thumbnail(i.signature)),
                              DataCell(Text(i.contract)),
                              DataCell(Text(tf.format(i.createdAt))),
                            ]))
                        .toList(),
                  ),
                );
              },
            ),
            const Divider(height: 32),
            _row('Total Quantity Sold', record.totalQuantitySold?.toString() ?? '-'),
            _row('Prepared By', record.totalPreparedByName ?? '-'),
            _row(
              'Time',
              record.totalPreparedByDate != null
                  ? tf.format(record.totalPreparedByDate!)
                  : '-',
            ),
            if (record.totalPreparedBySignature != null &&
                record.totalPreparedBySignature!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 170,
                        child: Text('Signature',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    SignatureField.thumbnail(record.totalPreparedBySignature!, height: 48),
                  ],
                ),
              ),
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
