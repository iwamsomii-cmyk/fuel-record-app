import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fuel_record.dart';
import '../models/receipt_item.dart';

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
  // The wireframe wants one search box that can match on driver name, PE,
  // token, contact/contract or chassis number. Firestore doesn't do
  // cross-field full-text search, so we run one exact-match query per
  // field in parallel (collectionGroup covers every record's receiptItems
  // subcollection at once) and merge+dedupe the results client-side. Fine
  // at this scale (a few pumps, a few hundred rows/day).
  Future<List<ReceiptItem>> searchReceiptItems(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final fields = ['driver', 'pe', 'token', 'chassisNo', 'contract'];
    final futures = fields.map((field) => _db
        .collectionGroup('receiptItems')
        .where(field, isEqualTo: q)
        .get());

    final results = await Future.wait(futures);
    final seen = <String>{};
    final merged = <ReceiptItem>[];
    for (final snap in results) {
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) {
          merged.add(ReceiptItem.fromMap(doc.id, doc.data()));
        }
      }
    }
    return merged;
  }
}
