import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChargerBoutiquePage extends StatefulWidget {
  @override
  _ChargerBoutiquePageState createState() => _ChargerBoutiquePageState();
}

class _ChargerBoutiquePageState extends State<ChargerBoutiquePage> {
  TextEditingController _searchController = TextEditingController();
  TextEditingController _quantityController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  // Fonction pour récupérer les produits existants
  Future<void> _fetchProducts() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('stock').get();

      setState(() {
        _products = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'nom': data['name'] ?? '',
            'gamme': data['gamme'] ?? '',
            'imageUrl': data['imageUrl'] ?? '',
            'type': data['type'] ?? '',
            'poids': data['poids'] ?? '',
            'quantite': data['quantite'] ?? 0,
          };
        }).toList();
      });
    } catch (e) {
      print('Erreur lors du chargement des produits: $e');
    }
  }

  // Fonction pour ouvrir le BottomSheet de sélection
  void _showProductSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher produit',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: _products.isEmpty
                        ? Center(child: CircularProgressIndicator())
                        : ListView(
                            children: _products
                                .where((product) =>
                                    product['nom']
                                        .toLowerCase()
                                        .contains(_searchQuery) ||
                                    product['gamme']
                                        .toLowerCase()
                                        .contains(_searchQuery))
                                .map((product) {
                              return ListTile(
                                onTap: () {
                                  setState(() {
                                    _selectedProduct = product;
                                  });
                                  Navigator.pop(context);
                                },
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: product['imageUrl'] != null &&
                                          product['imageUrl'].isNotEmpty
                                      ? NetworkImage(product['imageUrl'])
                                      : AssetImage('assets/images/logo.png')
                                          as ImageProvider,
                                ),
                                title: Text(product['nom']),
                                subtitle: Text('Gamme: ${product['gamme']}'),
                                trailing: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      product['type'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      product['poids'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Fonction pour charger en boutique
  Future<void> _chargerProduit() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un produit')),
      );
      return;
    }

    int? quantite = int.tryParse(_quantityController.text);
    if (quantite == null || quantite <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez entrer une quantité valide')),
      );
      return;
    }

    try {
      final stockRef = FirebaseFirestore.instance.collection('stock').doc(_selectedProduct!['id']);
      final boutiqueRef = FirebaseFirestore.instance.collection('stockBoutique');

      // Récupérer les infos actuelles du stock
      DocumentSnapshot stockDoc = await stockRef.get();
      int stockDisponible = (stockDoc['quantite'] ?? 0);

      if (quantite > stockDisponible) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock insuffisant (${stockDisponible} disponibles)')),
        );
        return;
      }

      // Ajouter dans stockBoutique
      await boutiqueRef.add({
        'nom': _selectedProduct!['nom'],
        'gamme': _selectedProduct!['gamme'],
        'poids': _selectedProduct!['poids'],
        'imageUrl': _selectedProduct!['imageUrl'],
        'type': _selectedProduct!['type'],
        'quantite': quantite,
        'dateAjout': Timestamp.now(),
      });

      // Déduire du stock initial
      await stockRef.update({
        'quantite': stockDisponible - quantite,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit chargé avec succès dans la boutique!')),
      );

      // Réinitialiser
      setState(() {
        _selectedProduct = null;
        _quantityController.clear();
      });
    } catch (e) {
      print('Erreur lors du chargement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement du produit')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Charger Boutique'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Bouton pour ouvrir la sélection
            ElevatedButton(
              onPressed: () {
                _showProductSelector(context);
              },
              child: Text('Choisir un produit'),
            ),
            SizedBox(height: 20),
            // Affichage du produit sélectionné
            if (_selectedProduct != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: _selectedProduct!['imageUrl'] != null &&
                                _selectedProduct!['imageUrl'].isNotEmpty
                            ? NetworkImage(_selectedProduct!['imageUrl'])
                            : AssetImage('assets/images/logo.png') as ImageProvider,
                      ),
                      title: Text(_selectedProduct!['nom']),
                      subtitle: Text(
                          'Gamme: ${_selectedProduct!['gamme']} - Type: ${_selectedProduct!['type']} - Poids: ${_selectedProduct!['poids']}'),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantité à charger',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _chargerProduit,
                    icon: Icon(Icons.save),
                    label: Text('Charger en Boutique'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
