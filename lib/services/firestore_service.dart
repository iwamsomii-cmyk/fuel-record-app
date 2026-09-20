import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/fuel_record.dart';
import '../models/receipt_item.dart';

/// One receipt item plus the parent fuel record's context, so search
/// results can show (and be matched against) the pump name, the pump
/// attendant's name ("Prepared By"), and the record's date - not just
/// the receipt row's own fields.
class ReceiptSearchResult {
  final ReceiptItem item;
  final String pumpName;
  final String preparedByName;
  final DateTime recordDate;

  ReceiptSearchResult({
    required this.item,
    required this.pumpName,
    required this.preparedByName,
    required this.recordDate,
  });
}

/// Single place that talks to Firestore.
///
/// Offline behaviour: cloud_firestore caches writes locally by default on
/// Android/iOS. If the device has no internet when .set()/.add() is called,
/// the write is queued locally and Firestore syncs it automatically the
/// next time connectivity comes back - this covers the wireframe's
/// "data should stay there even if device turns off" requirement without
/// any extra code. We just make the persistence setting explicit below.
class FirestoreService {
  FirestoreService._internal() {
    _db.settings = const Settings(persistenceEnabled: true);
  }
  static final FirestoreService instance = FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  CollectionReference<Map<String, dynamic>> get _records =>
      _db.collection('fuelRecords');

  CollectionReference<Map<String, dynamic>> _receiptItems(String recordId) =>
      _records.doc(recordId).collection('receiptItems');

  // ---------- Fuel record (header) ----------

  Future<String> createRecord(FuelRecord record) async {
    final ref = await _records.add(record.toMap());
    return ref.id;
  }

  Future<void> updateRecordTotals(FuelRecord record) async {
    await _records.doc(record.id).update(record.toMap());
  }

  Future<void> submitRecord(String recordId) async {
    await _records.doc(recordId).update({'submitted': true});
  }

  Stream<List<FuelRecord>> watchAllRecords() {
    return _records
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FuelRecord.fromMap(d.id, d.data()))
            .toList());
  }

  Future<FuelRecord?> getRecord(String recordId) async {
    final doc = await _records.doc(recordId).get();
    if (!doc.exists) return null;
    return FuelRecord.fromMap(doc.id, doc.data()!);
  }

  // ---------- Receipt items (repeatable table rows) ----------

  Future<void> addReceiptItem(String recordId, ReceiptItem item) async {
    await _receiptItems(recordId).add(item.toMap());
  }

  Stream<List<ReceiptItem>> watchReceiptItems(String recordId) {
    return _receiptItems(recordId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReceiptItem.fromMap(d.id, d.data()))
            .toList());
  }

  // ---------- Search ----------
  //
  // One search box matches on driver name, PE, token, contract, chassis
  // number, pump name, the pump attendant's name ("Prepared By"), or the
  // record's date. Firestore has no native case-insensitive / partial-text
  // search, so instead of a `where` query per field (which also needs a
  // composite index for every field, and silently hangs the UI forever if
  // that index doesn't exist), we pull every receipt item once and filter
  // client-side. Fine at this scale (a few pumps, a few hundred rows/day).
  //
  // Pump name, attendant name, and date all live on the parent fuel
  // record, not on the receipt item itself, so we also build a quick
  // recordId -> FuelRecord lookup to search and display those too.
  Future<List<ReceiptSearchResult>> searchReceiptItems(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final itemsSnap = await _db.collectionGroup('receiptItems').get();
    final recordsSnap = await _records.get();

    final recordsById = <String, FuelRecord>{
      for (final doc in recordsSnap.docs)
        doc.id: FuelRecord.fromMap(doc.id, doc.data()),
    };

    final results = <ReceiptSearchResult>[];
    for (final doc in itemsSnap.docs) {
      final item = ReceiptItem.fromMap(doc.id, doc.data());
      final recordId = doc.reference.parent.parent?.id;
      final record = recordsById[recordId];

      final pumpName = record?.pumpName ?? '';
      final preparedByName = record?.totalPreparedByName ?? '';
      final recordDate = record?.preparedByDate;
      final totalPreparedByDate = record?.totalPreparedByDate;

      final haystack = [
        item.driver,
        item.pe,
        item.token,
        item.chassisNo,
        item.contract,
        pumpName,
        preparedByName,
        recordDate != null ? _dateFormat.format(recordDate) : '',
        totalPreparedByDate != null
            ? _dateFormat.format(totalPreparedByDate)
            : '',
      ].join(' ').toLowerCase();

      if (haystack.contains(q)) {
        results.add(ReceiptSearchResult(
          item: item,
          pumpName: pumpName,
          preparedByName: preparedByName,
          recordDate: recordDate ?? item.createdAt,
        ));
      }
    }
    return results;
  }
}
