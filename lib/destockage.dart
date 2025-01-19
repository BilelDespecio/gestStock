import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class DestockagePage extends StatefulWidget {
  @override
  _DestockagePageState createState() => _DestockagePageState();
}

class _DestockagePageState extends State<DestockagePage> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String? _selectedProductId;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('produits').get();
      final products = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'nom': doc.data()['nom'],
          'quantite': doc.data()['quantite'],
          'seuil_critique': doc.data()['seuil_critique'] ?? 0, // Seuil critique
        };
      }).toList();

      setState(() {
        _products = products;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des produits : $e')),
      );
    }
  }

  Future<void> _logDestockage(
      String productId, int quantity, String reason) async {
    try {
      final destockageRef =
          FirebaseFirestore.instance.collection('destockages').doc();
      await destockageRef.set({
        'produit_id': productId,
        'quantite': quantity,
        'raison': reason,
        'date': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
      );
    }
  }

  Future<void> _sendStockAlertEmail(String productName, int stock) async {
    // Configure le serveur SMTP
    final smtpServer = gmail('hounganbilel@gmail.com', 'hvus tjei rhyn qvxd');
    final message = Message()
      ..from = const Address('hounganbilel@gmail.com', 'Gest Stock')
      ..recipients.add('despecio6@gmail.com') // Ajoutez l'email du destinataire
      ..subject = 'Alerte : Stock Critique pour $productName'
      ..text = 'Le stock du produit "$productName" est critique.\n'
          'Quantité actuelle : $stock.\n'
          'Veuillez prendre les mesures nécessaires.';

    try {
      final sendReport = await send(message, smtpServer);
      print('Email envoyé : ${sendReport.toString()}');
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'email : $e');
    }
  }

  Future<void> _removeStock() async {
    try {
      if (_selectedProductId == null || _selectedProductId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner un produit.')),
        );
        return;
      }

      final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
      final reason = _reasonController.text.trim();

      if (quantity <= 0 || reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer une quantité valide.')),
        );
        return;
      }

      final docRef =
          FirebaseFirestore.instance.collection('produits').doc(_selectedProductId);
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final currentQuantity = snapshot.data()?['quantite'] ?? 0;
        final productName = snapshot.data()?['nom'] ?? 'Produit inconnu';
        final seuil_critique = snapshot.data()?['seuil_critique'] ?? 0;

        if (currentQuantity >= quantity) {
          // Met à jour le stock
          await docRef.update({
            'quantite': FieldValue.increment(-quantity),
          });

          // Enregistre le déstockage
          await _logDestockage(_selectedProductId!, quantity, reason);

          // Vérifie si le stock est critique
          final newQuantity = currentQuantity - quantity;
          if (newQuantity <= seuil_critique) {
            await _sendStockAlertEmail(productName, newQuantity);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Déstockage effectué avec succès.')),
          );
          _quantityController.clear();
          _reasonController.clear();
          setState(() {
            _selectedProductId = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock insuffisant.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit introuvable.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Déstockage')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              decoration: const InputDecoration(
                labelText: 'Sélectionnez un produit',
                border: OutlineInputBorder(),
              ),
              items: _products.map((product) {
                return DropdownMenuItem<String>(
                  value: product['id'],
                  child: Text('${product['nom']} (Stock: ${product['quantite']})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantité',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison du déstockage',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _removeStock,
              child: const Text('Retirer du stock'),
            ),
          ],
        ),
      ),
    );
  }
}
