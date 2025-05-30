import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart'; // Ajoutez cette ligne

class VentePage extends StatefulWidget {
  @override
  _VentePageState createState() => _VentePageState();
}

class _VentePageState extends State<VentePage> {
  late List<Map<String, dynamic>> _articlesSelectionnes = [];
  double _montantTotal = 0.0;
  String _searchQuery = "";

  // Génère un identifiant pour la vente (à adapter selon ta logique)
  Future<String> _genererIdVente() async {
    QuerySnapshot ventesValidees = await FirebaseFirestore.instance
        .collection('ventes')
        .where('statut', whereIn: ['validé', 'en attente']).get();
    int numeroVente = ventesValidees.docs.length + 1;
    String date = DateTime.now().toIso8601String().split('T')[0];
    return 'VET$numeroVente-$date';
  }

  void _ajouterArticle(Map<String, dynamic> article, int quantite) {
    try {
      // Conversion sécurisée avec gestion de null
      double prixUnitaire =
          (article['prixVenteUnitaire'] ?? article['pvp'] ?? 0.0).toDouble();

      setState(() {
        double prixTotal = prixUnitaire * quantite;
        _articlesSelectionnes.add({
          'id': article['id']?.toString() ?? '',
          'nom': article['nom']?.toString() ?? 'Article inconnu',
          'quantite': quantite,
          'prixUnitaire': prixUnitaire,
          'prixTotal': prixTotal,
          // Conserver la référence du prix utilisé
          'prixReference':
              article.containsKey('prixDecide') ? 'prixDecide' : 'pvp',
        });
        _calculerMontantTotal();
      });
    } catch (e) {
      print("Erreur lors de l'ajout d'article: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout du produit')),
      );
    }
  }

  void _supprimerArticle(int index) {
    setState(() {
      _articlesSelectionnes.removeAt(index);
      _calculerMontantTotal();
    });
  }

  void _calculerMontantTotal() {
    _montantTotal = _articlesSelectionnes.fold(
        0.0, (sum, item) => sum + (item['prixTotal'] as num).toDouble());
  }

  void _soumettreVente() async {
    if (_articlesSelectionnes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajoutez des articles à la vente')),
      );
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous devez être connecté')),
      );
      return;
    }

    String venteId = await _genererIdVente();

    try {
      // Récupérer les infos complètes du vendeur
      DocumentSnapshot vendeurDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      await FirebaseFirestore.instance.collection('ventes').doc(venteId).set({
        'id': venteId,
        'articles': _articlesSelectionnes,
        'montantTotal': _montantTotal,
        'statut': 'en attente',
        'date': Timestamp.now(),
        'vendeurId': user.uid,
        'vendeurNom':
            vendeurDoc['name'] ?? user.displayName ?? 'Vendeur inconnu',
        'vendeurEmail': user.email,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vente enregistrée avec succès !')),
      );

      setState(() {
        _articlesSelectionnes.clear();
        _montantTotal = 0.0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de l\'enregistrement: ${e.toString()}')),
      );
    }
  }

  // Scanner un code-barres
  void _scannerCodeBarres() async {
    final currentContext = context;

    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text("Scanner un Code-Barres"),
        content: SizedBox(
          height: 300,
          child: MobileScanner(
            onDetect: (barcode) async {
              if (barcode.barcodes.isNotEmpty && barcode.barcodes.first.rawValue != null) {
                String scannedCode = barcode.barcodes.first.rawValue!;
                Navigator.of(context).pop(); // Fermer le scanner

                try {
                  // 1. D'abord chercher dans produits par code-barre
                  QuerySnapshot produitsResult = await FirebaseFirestore.instance
                      .collection('produits')
                      .where('code_barre', isEqualTo: scannedCode)
                      .get();

                  if (produitsResult.docs.isNotEmpty) {
                    String nomProduit = produitsResult.docs.first['nom'];

                    // 2. Puis chercher dans stockBoutique par nom
                    QuerySnapshot stockResult = await FirebaseFirestore.instance
                        .collection('stockBoutique')
                        .where('nom', isEqualTo: nomProduit)
                        .get();

                    if (stockResult.docs.isNotEmpty) {
                      Map<String, dynamic> produitStock =
                      stockResult.docs.first.data() as Map<String, dynamic>;

                      if (currentContext.mounted) {
                        _showQuantiteDialog(
                          produitStock,
                          (produitStock['pvp'] ?? 0.0).toDouble(),
                          (produitStock['quantiteDisponible'] ?? 0).toInt(),
                        );
                      }
                    } else {
                      if (currentContext.mounted) {
                        ScaffoldMessenger.of(currentContext).showSnackBar(
                          SnackBar(content: Text('Produit non trouvé en stock')),
                        );
                      }
                    }
                  } else {
                    if (currentContext.mounted) {
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(content: Text('Code-barre non reconnu')),
                      );
                    }
                  }
                } catch (e) {
                  if (currentContext.mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(content: Text('Erreur: ${e.toString()}')),
                    );
                  }
                }
              }
            },
          ),
        ),
      ),
    );
  }

 // Fonction pour suspendre une vente
void _suspendreVente() async {
  // Vérification des articles
  if (_articlesSelectionnes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajoutez des articles avant de suspendre!')),
    );
    return;
  }

  // Vérification de l'authentification
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Authentification requise')),
    );
    return;
  }

  // Demande du nom du client
  final clientName = await _demanderNomClient();
  if (clientName == null || clientName.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nom du client requis')),
    );
    return;
  }

  try {
    // Génération d'un ID unique pour la vente
    final venteId = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}';
    
    // Enregistrement dans Firestore
    await FirebaseFirestore.instance.collection('ventes').doc(venteId).set({
      'id': venteId,
      'client': clientName.trim(),
      'articles': _articlesSelectionnes,
      'vendeurId': user.uid,
      'vendeurNom': user.displayName ?? 'Vendeur',
      'montantTotal': _montantTotal,
      'statut': 'suspendue',
      'date': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Réinitialisation de la vente
    _reinitialiserVenteActuelle();

    // Confirmation à l'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vente suspendue pour $clientName'),
        duration: const Duration(seconds: 2),
      ),
    );

  } catch (e, stackTrace) {
    debugPrint('Erreur suspension vente: $e\n$stackTrace');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Erreur lors de la suspension'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Réessayer',
          onPressed: _suspendreVente,
        ),
      ),
    );
  }
}

// Fonction helper pour demander le nom du client
Future<String?> _demanderNomClient() async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Nom du client'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Entrez le nom du client',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
}

// Fonction helper pour réinitialiser la vente
void _reinitialiserVenteActuelle() {
  setState(() {
    _articlesSelectionnes.clear();
    _montantTotal = 0.0;
  });
}

  // Affiche la liste des ventes suspendues du vendeur connecté
void _afficherVentesSuspendues() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vous devez être connecté')),
    );
    return;
  }

  try {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('ventes')
        .where('statut', isEqualTo: 'suspendue')
        .where('vendeurId', isEqualTo: user.uid) // Filtre par vendeur
        .orderBy('date', descending: true)
        .get();

    if (querySnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune vente suspendue')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mes Ventes Suspendues'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: querySnapshot.docs.length,
              itemBuilder: (context, index) {
                final doc = querySnapshot.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['date'] as Timestamp).toDate();
                final dateFormat = DateFormat('dd/MM/yyyy HH:mm').format(date);
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('Vente ${data['id']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data['montantTotal']} FCFA'),
                        Text('Client: ${data['client'] ?? 'Non spécifié'}'),
                        Text('Date: $dateFormat'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.replay, color: Colors.blue),
                      onPressed: () {
                        _reprendreVente(doc);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur: ${e.toString()}')),
    );
    debugPrint('Erreur ventes suspendues: $e');
  }
}

// Reprend une vente suspendue en chargeant ses articles et montant total
void _reprendreVente(DocumentSnapshot vente) async {
    try {
      setState(() {
        _articlesSelectionnes =
            List<Map<String, dynamic>>.from(vente['articles']);
        _montantTotal = (vente['montantTotal'] as num).toDouble();
      });

      // Suppression de la vente suspendue après reprise
      await FirebaseFirestore.instance
          .collection('ventes')
          .doc(vente.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vente reprise avec succès.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la reprise de la vente')),
      );
      print("Erreur: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nouvelle Vente'),
        actions: [
          IconButton(
            icon: Icon(Icons.restore),
            onPressed: _afficherVentesSuspendues,
          ),
        ],
        backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Recherche de produits
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, // Fond gris clair
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        border: InputBorder.none,
                        prefixIcon:
                            Icon(Icons.search, color: Colors.blueAccent),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent, // Couleur du bouton QR
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.qr_code_scanner,
                        color: Colors.white, size: 28),
                    onPressed: _scannerCodeBarres,
                    tooltip: "Scanner un QR Code",
                  ),
                ),
              ],
            ),

/*
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('stock').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return Center(child: CircularProgressIndicator());

                  final stock = snapshot.data!.docs.where((doc) {
                    final produit = doc.data() as Map<String, dynamic>;
                    return produit['nom']
                        .toLowerCase()
                        .contains(_searchQuery);
                  }).toList();

                  return ListView.builder(
                    itemCount: stock.length,
                    itemBuilder: (context, index) {
                      final produit = stock[index].data() as Map<String, dynamic>;

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text('${produit['gamme']} ${produit['nom']} ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Prix: ${produit['pvp']} FCFA'),
                          trailing: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  int quantite = 1;
                                  return AlertDialog(
                                    title: Text('Sélectionner la quantité'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            'Prix: ${produit['pvp']} FCFA'),
                                        Text(
                                            'Stock disponible: ${produit['quantiteDisponible']}'),
                                        TextField(
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                              labelText: 'Quantité'),
                                          onChanged: (value) {
                                            quantite = int.tryParse(value) ?? 1;
                                          },
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        child: Text('Annuler'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          if (quantite >
                                              produit['quantiteDisponible']) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Stock insuffisant ! Disponible : ${produit['quantiteDisponible']}')),
                                            );
                                          } else {
                                            _ajouterArticle(produit, quantite);
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: Text('Ajouter'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            icon: Icon(Icons.add_shopping_cart),
                            label: Text('Ajouter'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
*/

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('stockBoutique')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final stock = snapshot.data!.docs.where((doc) {
                    final produit = doc.data() as Map<String, dynamic>;
                    final nomProduit = produit['nom']?.toString() ?? '';
                    final gammeProduit = produit['gamme']?.toString() ??
                        ''; // Supposons que le champ s'appelle 'gamme'

                    final searchLower = _searchQuery.toLowerCase();

                    return nomProduit.toLowerCase().contains(searchLower) ||
                        gammeProduit.toLowerCase().contains(searchLower);
                  }).toList();

                  return ListView.builder(
                    itemCount: stock.length,
                    itemBuilder: (context, index) {
                      final produitStock =
                          stock[index].data() as Map<String, dynamic>;
                      final productId = stock[index].id;

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('produits')
                            .doc(productId)
                            .get(),
                        builder: (context, produitSnapshot) {
                          if (produitSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ListTile(
                              title: Text('Chargement...'),
                              leading: CircularProgressIndicator(),
                            );
                          }

                          // Gestion sécurisée du prix
                          final prixStock =
                              (produitStock['pvp'] ?? 0.0).toDouble();
                          final prixDecide =
                              produitSnapshot.data?.exists == true
                                  ? (produitSnapshot.data!
                                          as Map<String, dynamic>)['prixDecide']
                                      ?.toDouble()
                                  : null;

                          // Détermine le prix à utiliser (prixDecide prioritaire s'il existe)
                          final prixAAfficher = prixDecide ?? prixStock;
                          final prixPourCalcul = prixDecide ?? prixStock;

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(
                                '${produitStock['gamme'] ?? ''} ${produitStock['nom'] ?? ''}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                  'Prix: ${prixAAfficher.toStringAsFixed(2)} FCFA'),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _showQuantiteDialog(
                                    produitStock,
                                    prixPourCalcul,
                                    (produitStock['quantiteDisponible'] ?? 0)
                                        .toInt()),
                                icon: Icon(Icons.add_shopping_cart),
                                label: Text('Ajouter'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Divider(),

            // Résumé de la vente
            if (_articlesSelectionnes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Résumé de la vente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _articlesSelectionnes.length,
                  itemBuilder: (context, index) {
                    final article = _articlesSelectionnes[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title:
                            Text('${article['nom']} x${article['quantite']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Prix total: ${article['prixTotal'].toStringAsFixed(2)} FCFA'),
                            Text(
                              '(${article['prixReference'] == 'prixDecide' ? 'Prix spécial' : 'Prix standard'})',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _supprimerArticle(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Montant total: $_montantTotal FCFA',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // Boutons pour valider ou suspendre la vente
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _soumettreVente,
                    icon: Icon(Icons.check),
                    label: Text('Valider la vente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _suspendreVente,
                    icon: Icon(Icons.pause),
                    label: Text('Suspendre la vente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showQuantiteDialog(Map<String, dynamic> produit, double prixPourCalcul,
      int stockDisponible) {
    int quantite = 1;
    final prixAAfficher = prixPourCalcul.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Sélectionner la quantité'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${produit['gamme']} ${produit['nom']}'),
                Text('Prix: $prixAAfficher FCFA'),
                Text('Stock disponible: $stockDisponible'),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Quantité'),
                  onChanged: (value) {
                    setState(() {
                      quantite = int.tryParse(value) ?? 1;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  if (quantite > stockDisponible) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Stock insuffisant! Disponible: $stockDisponible'),
                      ),
                    );
                  } else {
                    // On crée une copie du produit avec le bon prix
                    final produitAvecPrix = {
                      ...produit,
                      'pvp': prixPourCalcul,
                      'prixVenteUnitaire': prixPourCalcul,
                    };
                    _ajouterArticle(produitAvecPrix, quantite);
                    Navigator.pop(context);
                  }
                },
                child: Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }
}
