import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import '../models/fuel_record.dart';
import '../models/receipt_item.dart';
import '../services/firestore_service.dart';
import '../widgets/receipt_item_form.dart';
import '../widgets/signature_field.dart';

/// Follows the reorganised flow for one Fuel Record:
///  1. Header (pump name, date, opening meter reading, opening balance) -> Save
///  2. Repeatable Receipt Information rows -> Save each, keep adding
///  3. Total Quantity Sold, Closing Meter Reading, Closing Balance and the
///     single Prepared By (name + signature) -> SUBMIT (uploads to Firestore)
class StartRecordScreen extends StatefulWidget {
  const StartRecordScreen({super.key});

  @override
  State<StartRecordScreen> createState() => _StartRecordScreenState();
}

class _StartRecordScreenState extends State<StartRecordScreen> {
  final _service = FirestoreService.instance;
  final _df = DateFormat('dd/MM/yyyy');

  // Step 1 controllers
  final _headerFormKey = GlobalKey<FormState>();
  final _pumpName = TextEditingController();
  final _openingMeter = TextEditingController();
  final _openingBalance = TextEditingController();
  DateTime _preparedByDate = DateTime.now();

  // Step 3 controllers
  final _footerFormKey = GlobalKey<FormState>();
  final _totalQty = TextEditingController();
  final _closingMeter = TextEditingController();
  final _closingBalance = TextEditingController();
  final _totalPreparedByName = TextEditingController();
  final _totalPreparedBySignature = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  String? _recordId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _pumpName, _openingMeter, _openingBalance,
      _totalQty, _closingMeter, _closingBalance, _totalPreparedByName,
    ]) {
      c.dispose();
    }
    _totalPreparedBySignature.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _preparedByDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _preparedByDate = picked);
    }
  }

  Future<void> _saveHeader() async {
    if (!_headerFormKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final record = FuelRecord(
      id: '',
      pumpName: _pumpName.text.trim(),
      preparedByDate: _preparedByDate,
      openingMeterReading: double.parse(_openingMeter.text.trim()),
      openingBalance: _openingBalance.text.trim().isEmpty
          ? null
          : double.tryParse(_openingBalance.text.trim()),
      createdAt: DateTime.now(),
    );
    // This write queues locally if offline and syncs automatically later.
    final id = await _service.createRecord(record);
    if (!mounted) return;
    setState(() {
      _recordId = id;
      _saving = false;
    });
  }

  Future<void> _submit() async {
    if (!_footerFormKey.currentState!.validate()) return;

    final sig = await SignatureField.exportBase64(_totalPreparedBySignature);
    if (sig == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign before submitting.')),
      );
      return;
    }

    setState(() => _saving = true);
    final existing = await _service.getRecord(_recordId!);
    final updated = existing!.copyWith(
      totalQuantitySold: double.parse(_totalQty.text.trim()),
      closingMeterReading: double.parse(_closingMeter.text.trim()),
      totalPreparedByName: _totalPreparedByName.text.trim(),
      totalPreparedBySignature: sig,
      totalPreparedByDate: DateTime.now(),
      timeClosed: DateTime.now(),
    );
    await _service.updateRecordTotals(updated);
    await _service.submitRecord(_recordId!);
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record submitted to server.')),
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
            _sectionTitle('Record Details'),
            Form(
              key: _headerFormKey,
              child: Column(
                children: [
                  _textField(_pumpName, 'Pump Name', enabled: _recordId == null),
                  _dateField(enabled: _recordId == null),
                  const SizedBox(height: 8),
                  _textField(_openingMeter, 'Opening Meter Reading',
                      number: true, enabled: _recordId == null),
                  _textField(_openingBalance, 'Opening Balance (optional)',
                      number: true, isRequired: false, enabled: _recordId == null),
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
                      child: Text('No receipts yet. Fill the form above.'),
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
                                DataCell(SignatureField.thumbnail(i.signature)),
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
                    _textField(_closingMeter, 'Closing Meter Reading', number: true),
                    _textField(_closingBalance, 'Closing Balance (optional)',
                        number: true, isRequired: false),
                    _textField(_totalPreparedByName, 'Prepared By - Name'),
                    SignatureField(
                      controller: _totalPreparedBySignature,
                      label: 'Prepared By - Signature',
                    ),
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

  Widget _dateField({bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: enabled ? _pickDate : null,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Date',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(_df.format(_preparedByDate)),
        ),
      ),
    );
  }

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
