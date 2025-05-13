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

class ExpenseScreen extends StatefulWidget {
  @override
  _ExpenseScreenState createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

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

  Future<void> _deleteExpense(String docId,String title) async {
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

                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final docId = doc.id;
                      return ListTile(
                        title: Text(data['title']),
                        subtitle: Text('${data['amount']} ₺'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline),
                          color: Colors.grey[700],
                          onPressed: () => _deleteExpense(docId,data['title']),
                        ),
                      );
                    }).toList(),
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
