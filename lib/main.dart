import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harcama Listesi',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ExpenseScreen(),
    );
  }
}

enum DateFilter { all, today, thisWeek, thisMonth }

class ExpenseScreen extends StatefulWidget {
  @override
  _ExpenseScreenState createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  DateFilter _selectedFilter = DateFilter.all;

  Future<void> _addExpense() async {
    String title = _titleController.text.trim();
    String amountText = _amountController.text.trim();

    if (title.isEmpty || amountText.isEmpty) return;

    double? amount = double.tryParse(amountText);
    if (amount == null) return;

    await FirebaseFirestore.instance.collection('expenses').add({
      'title': title,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _titleController.clear();
    _amountController.clear();
  }

  Future<void> _deleteExpense(String docId, String title) async {
    bool? shouldDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Silme Onayı"),
        content: Text("“$title” harcamasını silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            child: Text("İptal"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text("Evet", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await FirebaseFirestore.instance.collection('expenses').doc(docId).delete();
    }
  }

  bool _isInSelectedDateRange(DateTime date) {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case DateFilter.today:
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case DateFilter.thisWeek:
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return date.isAfter(startOfWeek.subtract(Duration(seconds: 1))) && date.isBefore(endOfWeek);
      case DateFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case DateFilter.all:
      default:
        return true;
    }
  }

  double _calculateTotal(List<QueryDocumentSnapshot> docs) {
    double total = 0.0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'];
      final date = DateTime.tryParse(timestamp.toString());
      if (date == null) continue;
      if (_isInSelectedDateRange(date)) {
        final amount = data['amount'] ?? 0.0;
        if (amount is num) total += amount.toDouble();
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Harcamalar")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Başlık'),
            ),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Tutar (₺)'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addExpense,
              child: Text('Harcamayı Ekle'),
            ),
            Divider(),

            // Dropdown filtre
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("Filtre: "),
                DropdownButton<DateFilter>(
                  value: _selectedFilter,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedFilter = newValue!;
                    });
                  },
                  items: [
                    DropdownMenuItem(value: DateFilter.all, child: Text('Tümü')),
                    DropdownMenuItem(value: DateFilter.today, child: Text('Bugün')),
                    DropdownMenuItem(value: DateFilter.thisWeek, child: Text('Bu Hafta')),
                    DropdownMenuItem(value: DateFilter.thisMonth, child: Text('Bu Ay')),
                  ],
                ),
              ],
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('expenses')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return Center(child: CircularProgressIndicator());

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("Henüz harcama yok."));
                  }

                  final docs = snapshot.data!.docs;

                  // Tarihe göre filtrele
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['timestamp'];
                    final date = DateTime.tryParse(timestamp.toString());
                    if (date == null) return false;
                    return _isInSelectedDateRange(date);
                  }).toList();

                  final total = _calculateTotal(docs);

                  if (filteredDocs.isEmpty) {
                    return Center(child: Text("Seçilen aralıkta harcama yok."));
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Toplam: ${total.toStringAsFixed(2)} ₺",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: filteredDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final docId = doc.id;
                            return ListTile(
                              title: Text(data['title']),
                              subtitle: Text('${data['amount']} ₺'),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline),
                                color: Colors.grey[700],
                                onPressed: () => _deleteExpense(docId, data['title']),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
