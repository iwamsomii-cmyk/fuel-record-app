import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class TokenQueueScreen extends StatefulWidget {
  const TokenQueueScreen({super.key});
  @override
  State<TokenQueueScreen> createState() => _TokenQueueScreenState();
}

class _TokenQueueScreenState extends State<TokenQueueScreen> {
  bool _busy = false;
  static const _colors = {
    'pending': Colors.orange,
    'issued': Colors.green,
    'failed': Colors.red,
    'expired': Colors.grey,
  };

  Future<void> _runNow() async {
    setState(() => _busy = true);
    String msg;
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('runNow').call();
      msg = 'Matokeo: ${r.data}';
    } catch (e) {
      msg = 'Imeshindikana: $e';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(title: const Text('GIMIS Token Queue')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _runNow,
        icon: const Icon(Icons.cloud_upload),
        label: Text(_busy ? 'Inaendelea...' : 'Issue All Pending'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tokenQueue')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Hitilafu: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!.docs.map((d) => d.data()).toList();
          int n(String k) => rows.where((x) => x['status'] == k).length;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, children: [
                for (final k in _colors.keys)
                  Chip(
                    label: Text('$k: ${n(k)}'),
                    backgroundColor: _colors[k]!.withValues(alpha: 0.15),
                  ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final x = rows[i];
                  final status = (x['status'] ?? 'pending') as String;
                  final exp = x['expiresAt'];
                  final daysLeft = exp is Timestamp
                      ? (exp.toDate().difference(DateTime.now()).inHours / 24).ceil()
                      : null;
                  final urgent = status == 'pending' && daysLeft != null && daysLeft <= 2;
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: urgent ? Colors.red : Colors.transparent),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.circle, color: _colors[status] ?? Colors.grey, size: 14),
                      title: Text('${x['token']}  ·  ${x['chassisNo']}'),
                      subtitle: Text([
                        '${x['institution'] ?? ''}',
                        if (status == 'pending' && daysLeft != null) 'Siku $daysLeft kuisha',
                        if (x['error'] != null) '⚠ ${x['error']}',
                      ].join('\n')),
                      trailing: Text(status),
                      isThreeLine: x['error'] != null,
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
