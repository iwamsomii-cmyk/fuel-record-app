import 'package:flutter/material.dart';
import '../models/fuel_record.dart';
import '../models/receipt_item.dart';
import '../services/firestore_service.dart';
import '../widgets/receipt_item_form.dart';

/// Follows the wireframe's 3-part flow for one Fuel Record:
///  1. Header (prepared by, pump name, meter readings, balances) -> Save
///  2. Repeatable Receipt Information rows -> Save each, keep adding
///  3. Total Quantity Sold + footer prepared-by -> SUBMIT (uploads to Firestore)
class StartRecordScreen extends StatefulWidget {
  const StartRecordScreen({super.key});

  @override
  State<StartRecordScreen> createState() => _StartRecordScreenState();
}

class _StartRecordScreenState extends State<StartRecordScreen> {
  final _service = FirestoreService.instance;

  // Step 1 controllers
  final _headerFormKey = GlobalKey<FormState>();
  final _pumpName = TextEditingController();
  final _preparedByName = TextEditingController();
  final _preparedBySignature = TextEditingController();
  final _openingMeter = TextEditingController();
  final _closingMeter = TextEditingController();
  final _openingBalance = TextEditingController();
  final _closingBalance = TextEditingController();

  // Step 3 controllers
  final _footerFormKey = GlobalKey<FormState>();
  final _totalQty = TextEditingController();
  final _totalPreparedByName = TextEditingController();
  final _totalPreparedBySignature = TextEditingController();

  String? _recordId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _pumpName, _preparedByName, _preparedBySignature, _openingMeter,
      _closingMeter, _openingBalance, _closingBalance, _totalQty,
      _totalPreparedByName, _totalPreparedBySignature,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveHeader() async {
    if (!_headerFormKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final record = FuelRecord(
      id: '',
      pumpName: _pumpName.text.trim(),
      preparedByName: _preparedByName.text.trim(),
      preparedBySignature: _preparedBySignature.text.trim(),
      preparedByDate: DateTime.now(), // auto-captured, per wireframe
      openingMeterReading: double.parse(_openingMeter.text.trim()),
      closingMeterReading: double.parse(_closingMeter.text.trim()),
      openingBalance: _openingBalance.text.trim().isEmpty
          ? null
          : double.tryParse(_openingBalance.text.trim()),
      closingBalance: _closingBalance.text.trim().isEmpty
          ? null
          : double.tryParse(_closingBalance.text.trim()),
      createdAt: DateTime.now(),
    );
    // This write queues locally if offline and syncs automatically later.
    final id = await _service.createRecord(record);
    setState(() {
      _recordId = id;
      _saving = false;
    });
  }

  Future<void> _submit() async {
    if (!_footerFormKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final existing = await _service.getRecord(_recordId!);
    final updated = existing!.copyWith(
      totalQuantitySold: double.parse(_totalQty.text.trim()),
      totalPreparedByName: _totalPreparedByName.text.trim(),
      totalPreparedBySignature: _totalPreparedBySignature.text.trim(),
      totalPreparedByDate: DateTime.now(),
      timeClosed: DateTime.now(),
    );
    await _service.updateRecordTotals(updated);
    await _service.submitRecord(_recordId!);
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record submitted / imepandishwa kwa server.')),
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start a Record')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Prepared By'),
            Form(
              key: _headerFormKey,
              child: Column(
                children: [
                  _textField(_pumpName, 'Pump Name', enabled: _recordId == null),
                  _textField(_preparedByName, 'Name', enabled: _recordId == null),
                  _textField(_preparedBySignature, 'Signature',
                      enabled: _recordId == null),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _textField(_openingMeter, 'Opening Meter Reading',
                          number: true, enabled: _recordId == null),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _textField(_closingMeter, 'Closing Meter Reading',
                          number: true, enabled: _recordId == null),
                    ),
                  ]),
                  Row(children: [
                    Expanded(
                      child: _textField(_openingBalance, 'Opening Balance (optional)',
                          number: true, isRequired: false, enabled: _recordId == null),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _textField(_closingBalance, 'Closing Balance (optional)',
                          number: true, isRequired: false, enabled: _recordId == null),
                    ),
                  ]),
                  if (_recordId == null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveHeader,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_recordId != null) ...[
              const Divider(height: 32),
              _sectionTitle('Receipt Information'),
              ReceiptItemForm(
                onSave: (item) => _service.addReceiptItem(_recordId!, item),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<ReceiptItem>>(
                stream: _service.watchReceiptItems(_recordId!),
                builder: (context, snap) {
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Hakuna receipt bado. Jaza fomu hapo juu.'),
                    );
                  }
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
              _sectionTitle('Total Quantity Sold'),
              Form(
                key: _footerFormKey,
                child: Column(
                  children: [
                    _textField(_totalQty, 'Total Quantity Sold', number: true),
                    _textField(_totalPreparedByName, 'Prepared By - Name'),
                    _textField(_totalPreparedBySignature, 'Prepared By - Signature'),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('SUBMIT'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool isRequired = true,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) {
          if (!isRequired) return null;
          if (v == null || v.trim().isEmpty) return 'Required / Mandatory';
          if (number && double.tryParse(v.trim()) == null) return 'Invalid number';
          return null;
        },
      ),
    );
  }
}
