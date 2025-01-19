import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class ApprovisionnementPage extends StatefulWidget {
  @override
  _ApprovisionnementPageState createState() => _ApprovisionnementPageState();
}

class _ApprovisionnementPageState extends State<ApprovisionnementPage> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();

  String? _selectedProductId;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').get();
      final products = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'nom': doc.data()['nom'],
        };
      }).toList();

      setState(() {
        _products = products;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des produits : ${e.toString()}')),
      );
    }
  }

  Future<void> _logApprovisionnement(String productId, int quantity, String supplier) async {
    try {
      final approvisionnementRef = FirebaseFirestore.instance.collection('approvisionnements').doc();
      await approvisionnementRef.set({
        'produit_id': productId,
        'quantite': quantity,
        'fournisseur': supplier,
        'date': FieldValue.serverTimestamp(),
      });

      await _sendEmail(productId, quantity, supplier); // Envoi de l'email
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement de l\'approvisionnement : ${e.toString()}')),
      );
    }
  }

  Future<void> _sendEmail(String productId, int quantity, String supplier) async {
    final smtpServer = gmail('hounganbilel@gmail.com', 'hvus tjei rhyn qvxd');
    final produit = _products.firstWhere((product) => product['id'] == productId);

    final message = Message()
      ..from = Address('hounganbilel@gmail.com', 'Gest Stock')
      ..recipients.add('despecio6@example.com') // Remplacez par l'adresse e-mail du destinataire
      ..subject = 'Nouvel Approvisionnement : ${produit['nom']}'
      ..text = 'Un nouvel approvisionnement a été ajouté :\n\n'
          'Produit : ${produit['nom']}\n'
          'Quantité : $quantity\n'
          'Fournisseur : $supplier\n'
          'Date : ${DateTime.now()}';

    try {
      await send(message, smtpServer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('E-mail envoyé avec succès.')),
      );
    } on MailerException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi de l\'e-mail : ${e.toString()}')),
      );
      for (var p in e.problems) {
        print('Problème : ${p.code}: ${p.msg}');
      }
    }
  }

  Future<void> _addStock() async {
    try {
      if (_selectedProductId == null || _selectedProductId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner un produit.')),
        );
        return;
      }

      final fournisseur = _supplierController.text.trim();
      final quantite = int.tryParse(_quantityController.text.trim()) ?? 0;

      if (fournisseur.isEmpty || quantite <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez remplir tous les champs correctement.')),
        );
        return;
      }

      final produitsCollection = FirebaseFirestore.instance.collection('produits');
      await produitsCollection.doc(_selectedProductId).update({
        'quantite': FieldValue.increment(quantite),
      });

      await _logApprovisionnement(_selectedProductId!, quantite, fournisseur);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approvisionnement ajouté avec succès.')),
      );

      _quantityController.clear();
      _supplierController.clear();
      setState(() {
        _selectedProductId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Approvisionnement')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              decoration: InputDecoration(
                labelText: 'Sélectionnez un produit',
                border: OutlineInputBorder(),
              ),
              items: _products.map((product) {
                return DropdownMenuItem<String>(
                  value: product['id'],
                  child: Text(product['nom']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                });
              },
            ),
            SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantité',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _supplierController,
              decoration: InputDecoration(
                labelText: 'Fournisseur',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addStock,
              child: Text('Ajouter au stock'),
            ),
          ],
        ),
      ),
    );
  }
}
