import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChargerBoutiquePage extends StatefulWidget {
  @override
  _ChargerBoutiquePageState createState() => _ChargerBoutiquePageState();
}

class _ChargerBoutiquePageState extends State<ChargerBoutiquePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];
  Map<String, TextEditingController> _quantityControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityControllers.forEach((key, controller) => controller.dispose());
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
          final productId = doc.id;

          // Initialiser un contrôleur de quantité pour chaque produit
          _quantityControllers[productId] = TextEditingController(text: '0');

          return {
            'id': productId,
            'nom': data['nom'] ?? data['name'] ?? 'Sans nom',
            'gamme': data['gamme'] ?? '',
            'type': data['type'] ?? '',
            'poids': data['poids'] ?? '',
            'quantiteDisponible':
                data['quantiteDisponible'] ?? data['quantite'] ?? 0,
            'pvp': data['pvp'] ?? 0,
            // Ajoutez tous les autres champs nécessaires
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

  Future<void> _chargerBoutique() async {
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final stockBoutiqueRef =
          FirebaseFirestore.instance.collection('stockBoutique');

      for (var product in _products) {
        final productId = product['id'];
        final quantite =
            int.tryParse(_quantityControllers[productId]!.text) ?? 0;

        if (quantite > 0) {
          // Vérifier le stock disponible
          if (quantite > product['quantiteDisponible']) {
            throw Exception('Stock insuffisant pour ${product['nom']}');
          }

          // Copie complète du produit avec la nouvelle quantité
          final productCopy = Map<String, dynamic>.from(product);
          productCopy['quantite'] = quantite;
          productCopy['dateAjout'] = FieldValue.serverTimestamp();
          productCopy['quantiteDisponible'] = quantite; // Pour la boutique

          print(productId);
          // Ajouter à la boutique
          batch.set(stockBoutiqueRef.doc(productId), productCopy);

          // Mettre à jour le stock principal
          final stockRef =
              FirebaseFirestore.instance.collection('stock').doc(productId);
          batch.update(stockRef,
              {'quantiteDisponible': FieldValue.increment(-quantite)});
        }
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Boutique chargée avec succès!')),
      );

      // Réinitialiser les quantités
      _quantityControllers.forEach((key, controller) => controller.text = '0');
    } catch (e) {
      debugPrint('Erreur chargement boutique: $e');
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchProducts,
          ),
        ],
      ),
      body: _isLoading && _products.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher un produit',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final productName =
                          product['nom'].toString().toLowerCase();

                      if (!productName.contains(_searchQuery)) {
                        return SizedBox.shrink();
                      }

                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              /*CircleAvatar(
                                radius: 30,
                                backgroundImage: product['imageUrl'] != null && 
                                    product['imageUrl'].isNotEmpty
                                    ? NetworkImage(product['imageUrl'])
                                    : AssetImage('assets/images/logo.png') as ImageProvider,
                              ),*/
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['gamme'],
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(product['nom']),
                                    Text(
                                        'Dispo: ${product['quantiteDisponible']}, ${product['poids']}'),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller:
                                      _quantityControllers[product['id']],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Qté',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _chargerBoutique,
                    icon: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Icon(Icons.shopping_cart),
                    label: Text('Charger la boutique'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
/*
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
}*/
