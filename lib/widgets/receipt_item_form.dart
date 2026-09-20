import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../models/receipt_item.dart';
import 'signature_field.dart';

/// Inline form for one row of the "Receipt Information" table
/// (PE, Driver, Token, Chassis No, Qty, Signature, Contract).
/// Calls [onSave] with a new ReceiptItem and clears itself so the
/// officer can immediately enter the next PE's row, matching the
/// wireframe note: "after being save it should allow again input
/// section... for another PE".
class ReceiptItemForm extends StatefulWidget {
  final void Function(ReceiptItem item) onSave;
  const ReceiptItemForm({super.key, required this.onSave});

  @override
  State<ReceiptItemForm> createState() => _ReceiptItemFormState();
}

class _ReceiptItemFormState extends State<ReceiptItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _pe = TextEditingController();
  final _driver = TextEditingController();
  final _token = TextEditingController();
  final _chassisNo = TextEditingController();
  final _qty = TextEditingController();
  final _signature = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _contract = TextEditingController();

  @override
  void dispose() {
    for (final c in [_pe, _driver, _token, _chassisNo, _qty, _contract]) {
      c.dispose();
    }
    _signature.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final sig = await SignatureField.exportBase64(_signature);
    if (sig == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign before saving this row.')),
      );
      return;
    }

    widget.onSave(ReceiptItem(
      id: '', // Firestore assigns the real id on add()
      pe: _pe.text.trim(),
      driver: _driver.text.trim(),
      token: _token.text.trim(),
      chassisNo: _chassisNo.text.trim(),
      qty: double.parse(_qty.text.trim()),
      signature: sig,
      contract: _contract.text.trim(),
      createdAt: DateTime.now(),
    ));
    for (final c in [_pe, _driver, _token, _chassisNo, _qty, _contract]) {
      c.clear();
    }
    _signature.clear();
    setState(() {}); // refresh so the form visually resets
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _field(_pe, 'PE')),
                const SizedBox(width: 8),
                Expanded(child: _field(_driver, 'Driver')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field(_token, 'Token')),
                const SizedBox(width: 8),
                Expanded(child: _field(_chassisNo, 'Chassis No')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _field(_qty, 'Qty',
                      keyboardType: TextInputType.number, isNumber: true),
                ),
                const SizedBox(width: 8),
                Expanded(child: _field(_contract, 'Contract')),
              ]),
              const SizedBox(height: 8),
              SignatureField(controller: _signature, label: 'Signature'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {TextInputType? keyboardType, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (isNumber && double.tryParse(v.trim()) == null) return 'Invalid number';
        return null;
      },
    );
  }
}
