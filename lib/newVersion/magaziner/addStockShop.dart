import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChargerBoutiquePage extends StatefulWidget {
  @override
  _ChargerBoutiquePageState createState() => _ChargerBoutiquePageState();
}

class _ChargerBoutiquePageState extends State<ChargerBoutiquePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('stock').get();

      setState(() {
        _products = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'nom': data['nom'] ?? data['name'] ?? 'Sans nom',
            'gamme': data['gamme'] ?? '',
            'imageUrl': data['imageUrl'] ?? '',
            'type': data['type'] ?? '',
            'poids': data['poids'] ?? '',
            // Utilisez le bon nom de champ selon votre Firestore
            'quantiteDisponible': data['quantiteDisponible'] ?? data['quantite'] ?? 0,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Erreur chargement produits: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des produits')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showProductSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher produit',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) => setModalState(() => _searchQuery = value.toLowerCase()),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _products.isEmpty
                        ? const Center(child: Text('Aucun produit disponible'))
                        : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        if (!product['nom'].toLowerCase().contains(_searchQuery) ) {
                        return const SizedBox.shrink();
                        }
                        return ListTile(
                        onTap: () {
                          setState(() => _selectedProduct = product);
                          Navigator.pop(context);
                        },
                        leading: CircleAvatar(
                        radius: 25,
                        backgroundImage: product['imageUrl'] != null &&
                        product['imageUrl'].isNotEmpty
                        ? NetworkImage(product['imageUrl'])
                            : const AssetImage('assets/images/logo.png') as ImageProvider,
                        ),
                        title: Text(product['nom']),
                        subtitle: Text('Gamme: ${product['gamme']}'),
                        trailing: Text('${product['quantiteDisponible']} disponibles'),
                        );
                      },
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

  Future<void> _chargerProduit() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit')),
      );
      return;
    }

    final quantite = int.tryParse(_quantityController.text);
    if (quantite == null || quantite <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une quantité valide')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final stockRef = FirebaseFirestore.instance
          .collection('stock')
          .doc(_selectedProduct!['id']);

      final boutiqueRef = FirebaseFirestore.instance.collection('stockBoutique');

      // Transaction pour garantir la cohérence des données
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(stockRef);
        if (!doc.exists) throw Exception('Produit introuvable en stock');

        final stockDisponible = (doc['quantiteDisponible'] ?? doc['quantite'] ?? 0) as int;
        if (quantite > stockDisponible) {
          throw Exception('Stock insuffisant ($stockDisponible disponibles)');
        }

        // Ajout en boutique
        transaction.set(
          boutiqueRef.doc(),
          {
            'produitId': _selectedProduct!['id'],
            'nom': _selectedProduct!['nom'],
            'gamme': _selectedProduct!['gamme'],
            'poids': _selectedProduct!['poids'],
            'imageUrl': _selectedProduct!['imageUrl'],
            'type': _selectedProduct!['type'],
            'quantite': quantite,
            'dateAjout': FieldValue.serverTimestamp(),
          },
        );

        // Mise à jour du stock
        transaction.update(
          stockRef,
          {'quantiteDisponible': stockDisponible - quantite},
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit chargé avec succès!')),
      );

      // Réinitialisation
      _quantityController.clear();
      _selectedProduct = null;
      await _fetchProducts(); // Rafraîchir les données
    } catch (e) {
      debugPrint('Erreur chargement produit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Charger Boutique'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => _showProductSelector(context),
              child: const Text('Sélectionner un produit'),
            ),
            const SizedBox(height: 20),
            if (_selectedProduct != null) ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: _selectedProduct!['imageUrl'] != null &&
                        _selectedProduct!['imageUrl'].isNotEmpty
                        ? NetworkImage(_selectedProduct!['imageUrl'])
                        : const AssetImage('assets/images/logo.png') as ImageProvider,
                  ),
                  title: Text(_selectedProduct!['nom']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gamme: ${_selectedProduct!['gamme']}'),
                      Text('Type: ${_selectedProduct!['type']}'),
                      Text('Poids: ${_selectedProduct!['poids']}'),
                      Text('Disponible: ${_selectedProduct!['quantiteDisponible']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantité à charger',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _chargerProduit,
                icon: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.save),
                label: const Text('Charger en boutique'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}