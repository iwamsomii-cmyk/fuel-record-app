import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

class TokenQueueScreen extends StatefulWidget {
  const TokenQueueScreen({super.key});
  @override
  State<TokenQueueScreen> createState() => _TokenQueueScreenState();
}

class _TokenQueueScreenState extends State<TokenQueueScreen> {
  final Set<String> _selected = {};
  bool _busy = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Ruhusa: token zilizochaguliwa zinakuwa "approved", kisha bot inaziendesha GIMIS mara moja.
  Future<void> _permit() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ruhusu token'),
        content: Text('Unaruhusu token ${ids.length} ziende GIMIS ku-issue sasa hivi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hapana')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ndiyo, ruhusu')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final who = FirebaseAuth.instance.currentUser?.email ?? '';
      final batch = db.batch();
      for (final id in ids) {
        batch.update(db.collection('tokenQueue').doc(id), {
          'status': 'approved',
          'permittedBy': who,
          'permittedAt': Timestamp.now(),
        });
      }
      await batch.commit();
      _selected.clear();
      try {
        final r = await FirebaseFunctions.instance.httpsCallable('runNow').call();
        _toast('Imeruhusiwa. Matokeo: ${r.data}');
      } catch (e) {
        _toast('Imeruhusiwa, lakini bot haijaanza: $e');
      }
    } catch (e) {
      _toast('Imeshindikana kuruhusu: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _tile(_Doc d, bool selectable) {
    final x = d.data();
    final status = (x['status'] ?? 'pending') as String;
    final exp = x['expiresAt'];
    final daysLeft = exp is Timestamp
        ? (exp.toDate().difference(DateTime.now()).inHours / 24).ceil()
        : null;
    final lines = <String>[
      '${x['institution'] ?? ''}',
      if (status == 'pending' && daysLeft != null) 'Siku $daysLeft kuisha',
      if (x['permittedBy'] != null) 'Permit: ${x['permittedBy']}',
      if (x['error'] != null) '⚠ ${x['error']}',
    ];
    final title = Text('${x['token']}  ·  ${x['chassisNo']}');
    final sub = Text(lines.join('\n'));
    if (selectable && status != 'expired') {
      return CheckboxListTile(
        value: _selected.contains(d.id),
        onChanged: (v) => setState(() {
          if (v == true) {
            _selected.add(d.id);
          } else {
            _selected.remove(d.id);
          }
        }),
        title: title,
        subtitle: sub,
        isThreeLine: lines.length > 2,
      );
    }
    return ListTile(title: title, subtitle: sub, trailing: Text(status), isThreeLine: lines.length > 2);
  }

  Widget _list(List<_Doc> docs, bool selectable) {
    if (docs.isEmpty) return const Center(child: Text('Hakuna token hapa'));
    return Column(children: [
      if (selectable)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => _selected.addAll(
                docs.where((d) => d.data()['status'] != 'expired').map((d) => d.id))),
            child: const Text('Chagua zote'),
          ),
        ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: docs.length,
          itemBuilder: (c, i) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: _tile(docs[i], selectable)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, meSnap) {
        final canPermit = meSnap.data?.data()?['canPermit'] == true;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('tokenQueue')
              .orderBy('createdAt', descending: true)
              .limit(300)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text('Hitilafu: ${snap.error}')));
            if (!snap.hasData) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
            final docs = snap.data!.docs;
            List<_Doc> by(List<String> st) => docs.where((d) => st.contains(d.data()['status'])).toList();
            final waiting = by(['pending']);
            final running = by(['approved']);
            final issued = by(['issued']);
            final follow = by(['failed', 'expired']);
            return DefaultTabController(
              length: 4,
              child: Scaffold(
                backgroundColor: const Color(0xFFF3F4F8),
                appBar: AppBar(
                  title: const Text('GIMIS Token Queue'),
                  bottom: TabBar(isScrollable: true, tabs: [
                    Tab(text: 'Zinasubiri ruhusa (${waiting.length})'),
                    Tab(text: 'Zinaendelea (${running.length})'),
                    Tab(text: 'Issued (${issued.length})'),
                    Tab(text: 'Follow-up (${follow.length})'),
                  ]),
                ),
                floatingActionButton: (canPermit && _selected.isNotEmpty)
                    ? FloatingActionButton.extended(
                        onPressed: _busy ? null : _permit,
                        icon: const Icon(Icons.verified),
                        label: Text(_busy ? 'Inaendelea...' : 'Ruhusu & Issue (${_selected.length})'),
                      )
                    : null,
                body: TabBarView(children: [
                  _list(waiting, canPermit),
                  _list(running, false),
                  _list(issued, false),
                  _list(follow, canPermit),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
