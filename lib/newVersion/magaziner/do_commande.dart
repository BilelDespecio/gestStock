import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/magaziner/dropStyle.dart';
import 'package:intl/intl.dart';

class OrderForm extends StatefulWidget {
  @override
  _OrderFormState createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _productNames = []; // Liste des noms de produits
  String? _selectedProductId; // Produit sélectionné
  List<Map<String, dynamic>> _items = [];
  int _itemQuantity = 1;

  List<Map<String, dynamic>> _suspendedOrders = [];
  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool isLoading = false; // Indicateur de chargement

  void _showProductSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(5, 20, 5, 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Champ de recherche
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher un produit',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                  SizedBox(height: 10),

                  // Liste des produits filtrés
                  Expanded(
                    child: ListView(
                      children: _productNames
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
                              _selectedProductId = product['id'];
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
                            backgroundColor: Colors.grey[200],
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['gamme'],
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    product['nom'],
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              SizedBox(width: 5),
                              Column(
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
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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

  /// Récupération et tri des produits (par gamme puis par nom)
  Future<void> _fetchProducts() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('produits').get();
      final products = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'nom': doc['nom'],
          'code_barre': doc['code_barre'],
          'gamme': doc['gamme'],
          'type': doc['type'],
          'poids': doc['poids'],
          'imageUrl': doc['imageUrl']
        };
      }).toList();

      // **Trier d'abord par gamme, puis par nom**
      products.sort((a, b) {
        int gammeCompare = a['gamme'].compareTo(b['gamme']);
        if (gammeCompare != 0) return gammeCompare;
        return a['nom'].compareTo(b['nom']);
      });

      setState(() {
        _productNames = products;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Erreur lors du chargement des produits : ${e.toString()}')),
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

      final selectedProduct =
          _productNames.firstWhere((prod) => prod['id'] == _selectedProductId);

      setState(() {
        _items.add({
          'id': '${selectedProduct['gamme']}_${_selectedProductId}',
          'name': selectedProduct['nom'],
          'quantity': _itemQuantity,
          'code_barre': selectedProduct['code_barre'],
          'gamme': selectedProduct['gamme'],
          'type': selectedProduct['type'],
          'poids': selectedProduct['poids'],
        });
        _selectedProductId = null;
        _itemQuantity = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Article ajouté : $_itemQuantity x ${selectedProduct['nom']}')),
      );
    }
  }

  Future<void> _saveOrderToFirestore() async {
    setState(() {
      isLoading = true; // Activer le loader
    });
    try {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ajoutez au moins un article à la commande.')),
        );
        return;
      }

      // Obtenir le nombre total de commandes existantes pour incrémenter le numéro
      final snapshot =
          await FirebaseFirestore.instance.collection('commandes').get();
      int orderNumber = snapshot.size + 1; // Le numéro de la commande

      // Obtenir la date au format yyyyMMdd
      String formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());

      // Générer un identifiant personnalisé basé sur le numéro de commande et le timestamp
      String orderId = 'CMD-$orderNumber-$formattedDate';

      // Calcul du nombre total d'articles
      int totalQuantity =
          _items.fold(0, (sum, item) => sum + (item['quantity'] as int));

      await FirebaseFirestore.instance
          .collection('commandes')
          .doc(orderId)
          .set({
        'id': orderId,
        'articles': _items,
        'totalArticles': totalQuantity, // Ajout du nombre total d'articles
        'date': Timestamp.now(),
        'statut': 'en cours', // Statut initial de la commande
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commande enregistrée avec succès!')),
      );

      setState(() {
        _items.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de l\'enregistrement: ${e.toString()}')),
      );
    }finally {
      setState(() {
        isLoading = false; // Désactiver le loader après traitement
      });
    }
  }

 /// **Suspendre la commande en cours**
  Future<void> _suspendreCommande() async {
    try {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucun article à suspendre.')),
        );
        return;
      }

      String orderId = 'SUSP-${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance
          .collection('commandes')
          .doc(orderId)
          .set({
        'id': orderId,
        'articles': _items,
        'totalArticles':
            _items.fold(0, (sum, item) => sum + (item['quantity'] as int)),
        'date': Timestamp.now(),
        'statut': 'suspendue',
      });

      setState(() {
        _items.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commande suspendue avec succès.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de la suspension : ${e.toString()}')),
      );
    }
  }

  /// **Récupérer les commandes suspendues**
  Future<void> _fetchSuspendedOrders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('commandes')
          .where('statut', isEqualTo: 'suspendue')
          .get();

      setState(() {
        _suspendedOrders = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'articles': List<Map<String, dynamic>>.from(doc['articles']),
            'totalArticles': doc['totalArticles'],
            'date': (doc['date'] as Timestamp).toDate(),
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Erreur lors du chargement des commandes suspendues : ${e.toString()}')),
      );
    }
  }

  /// **Reprendre une commande suspendue**
  void _resumeOrder(Map<String, dynamic> order) {
    setState(() {
      _items = List.from(order['articles']);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Commande reprise avec succès !')),
    );
  }

  /// **Annuler une commande suspendue**
  Future<void> _cancelSuspendedOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('commandes')
          .doc(orderId)
          .delete();

      setState(() {
        _suspendedOrders.removeWhere((order) => order['id'] == orderId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commande annulée avec succès.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de l\'annulation : ${e.toString()}')),
      );
    }
  }

  void _showSuspendedOrders(BuildContext context) async {
    await _fetchSuspendedOrders(); // Récupérer les commandes suspendues avant d'afficher

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6, // 60% de l'écran
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Commandes suspendues',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Expanded(
                child: _suspendedOrders.isEmpty
                    ? Center(child: Text('Aucune commande suspendue.'))
                    : ListView.builder(
                        itemCount: _suspendedOrders.length,
                        itemBuilder: (context, index) {
                          final order = _suspendedOrders[index];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text('Commande ${order['id']}'),
                              subtitle: Text(
                                  'Total articles: ${order['totalArticles']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.play_arrow,
                                        color: Colors.green),
                                    tooltip: 'Reprendre',
                                    onPressed: () {
                                      _resumeOrder(order);
                                      Navigator.pop(
                                          context); // Fermer le modal après action
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Annuler',
                                    onPressed: () {
                                      _cancelSuspendedOrder(order['id']);
                                      Navigator.pop(
                                          context); // Fermer le modal après action
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer une commande'),
        backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
         actions: [
          IconButton(
            icon: Icon(Icons.pause_circle_outline, color: Colors.white),
            tooltip: 'Commandes suspendues',
            onPressed: () => _showSuspendedOrders(context),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              InkWell(
                onTap: () => _showProductSelection(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Sélectionnez un produit",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _selectedProductId != null
                        ? _productNames.firstWhere(
                            (p) => p['id'] == _selectedProductId)['nom']
                        : "Aucun produit sélectionné",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                    labelText: 'Quantité', border: OutlineInputBorder()),
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
              Row(
                children: [
                  ElevatedButton(
      onPressed: isLoading ? null : _saveOrderToFirestore, // Désactiver si chargement
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save),
                SizedBox(width: 8),
                Text('Passer la commande', style: TextStyle(fontSize: 10)),
              ],
            ),
    ),
  
                   ElevatedButton.icon(
                    onPressed: _suspendreCommande,
                    icon: Icon(Icons.pause),
                    label: Text(
                      'Suspendre la vente',
                      style: TextStyle(fontSize: 10),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
