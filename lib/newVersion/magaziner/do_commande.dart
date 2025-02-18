import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';  // Ajoutez cette importation pour formater la date

class OrderForm extends StatefulWidget {
  @override
  _OrderFormState createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _items = [];

  String? _selectedProductId;
  List<Map<String, dynamic>> _products = [];
  int _itemQuantity = 1;

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
          'code_barre': doc.data()['code_barre']
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

  void _addItem() {
    if (_formKey.currentState!.validate()) {
      if (_selectedProductId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner un produit')),
        );
        return;
      }

      final selectedProduct = _products.firstWhere((prod) => prod['id'] == _selectedProductId);

      setState(() {
        _items.add({
          'id': _selectedProductId,
          'name': selectedProduct['nom'],
          'quantity': _itemQuantity,
          'code_barre': selectedProduct['code_barre']
        });
        _selectedProductId = null;
        _itemQuantity = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Article ajouté : $_itemQuantity x ${selectedProduct['nom']}')),
      );
    }
  }

Future<void> _saveOrderToFirestore() async {
  try {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajoutez au moins un article à la commande.')),
      );
      return;
    }

    // Obtenir le nombre total de commandes existantes pour incrémenter le numéro
    final snapshot = await FirebaseFirestore.instance.collection('commandes').get();
    int orderNumber = snapshot.size + 1; // Le numéro de la commande

     // Obtenir la date au format yyyyMMdd
    String formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());


    // Générer un identifiant personnalisé basé sur le numéro de commande et le timestamp
    String orderId = 'CMD-$orderNumber-$formattedDate';

    // Calcul du nombre total d'articles
    int totalQuantity = _items.fold(0, (sum, item) => sum + (item['quantity'] as int));


    await FirebaseFirestore.instance.collection('commandes').doc(orderId).set({
      'id': orderId,
      'articles': _items,
      'totalArticles': totalQuantity,  // Ajout du nombre total d'articles
      'date': Timestamp.now(),
      'statut': 'en cours',  // Statut initial de la commande
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Commande enregistrée avec succès!')),
    );

    setState(() {
      _items.clear();
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur lors de l\'enregistrement: ${e.toString()}')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer une commande'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
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
                validator: (value) => value == null ? 'Veuillez choisir un produit' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                initialValue: _itemQuantity.toString(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une quantité';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Veuillez entrer une quantité valide';
                  }
                  return null;
                },
                onSaved: (value) {
                  _itemQuantity = int.parse(value!);
                },
                onChanged: (value) {
                  if (int.tryParse(value) != null) {
                    _itemQuantity = int.parse(value);
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addItem,
                child: Text('Ajouter un article'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(Icons.shopping_cart),
                      title: Text('${_items[index]['name']}'),
                      subtitle: Text('Quantité: ${_items[index]['quantity']}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _items.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _saveOrderToFirestore,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('Passer la commande'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
