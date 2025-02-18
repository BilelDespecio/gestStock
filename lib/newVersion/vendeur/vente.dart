import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
        .where('statut', isEqualTo: 'validé')
        .get();
    int numeroVente = ventesValidees.docs.length + 1;
    String date = DateTime.now().toIso8601String().split('T')[0];
    return 'VET$numeroVente-$date';
  }

  void _ajouterArticle(Map<String, dynamic> article, int quantite) {
    setState(() {
      double prixTotal =
          (article['prixVenteUnitaire'] as num).toDouble() * quantite;
      _articlesSelectionnes.add({
        'id': article['id'],
        'nom': article['name'],
        'quantite': quantite,
        'prixUnitaire': (article['prixVenteUnitaire'] as num).toDouble(),
        'prixTotal': prixTotal,
      });
      _calculerMontantTotal();
    });
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

  // Validation finale de la vente
  void _soumettreVente() async {
    if (_articlesSelectionnes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajoutez des articles à la vente')),
      );
      return;
    }

    String venteId = await _genererIdVente();

    try {
      await FirebaseFirestore.instance.collection('ventes').doc(venteId).set({
        'id': venteId,
        'articles': _articlesSelectionnes,
        'montantTotal': _montantTotal,
        'statut': 'en attente', // ou 'validé' une fois validée
        'date': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Vente enregistrée avec succès en attente de validation !')),
      );

      setState(() {
        _articlesSelectionnes.clear();
        _montantTotal = 0.0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement de la vente')),
      );
      print("Erreur: $e");
    }
  }

 /* Future<void> _scannerCodeBarres() async {
    try {
      var scanResult = await BarcodeScanner.scan();
      String barcode = scanResult.rawContent;

      if (barcode.isNotEmpty) {
        QuerySnapshot result = await FirebaseFirestore.instance
            .collection('stock')
            .where('code_barre', isEqualTo: barcode)
            .get();

        if (result.docs.isNotEmpty) {
          Map<String, dynamic> produit =
              result.docs.first.data() as Map<String, dynamic>;
          _demanderQuantite(produit);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Produit non trouvé')),
          );
        }
      }
    } catch (e) {
      print("Erreur scan: $e");
    }
  } */
 void _scannerCodeBarres() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Scanner un Code-Barres"),
        content: SizedBox(
          height: 300,
          child: MobileScanner(
            onDetect: (barcode) async {
              if (barcode.barcodes.isNotEmpty && barcode.barcodes.first.rawValue != null) {
                String scannedCode = barcode.barcodes.first.rawValue!;
                print("Code-barres détecté : $scannedCode");

                // Rechercher le produit dans Firestore
                QuerySnapshot result = await FirebaseFirestore.instance
                    .collection('stock')
                    .where('code_barre', isEqualTo: scannedCode)
                    .get();

                if (result.docs.isNotEmpty) {
                  Map<String, dynamic> produit =
                      result.docs.first.data() as Map<String, dynamic>;

                  _demanderQuantite(produit);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Produit non trouvé')),
                  );
                }

                Navigator.pop(context); // Ferme le scanner après détection
              }
            },
          ),
        ),
      ),
    );
  }

  void _demanderQuantite(Map<String, dynamic> produit) {
    showDialog(
      context: context,
      builder: (context) {
        int quantite = 1;
        return AlertDialog(
          title: Text('Sélectionner la quantité'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Prix: ${produit['prixVenteUnitaire']} FCFA'),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantité'),
                onChanged: (value) {
                  quantite = int.tryParse(value) ?? 1;
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
                _ajouterArticle(produit, quantite);
                Navigator.pop(context);
              },
              child: Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  // Fonction pour suspendre la vente en cours
  void _suspendreVente() async {
    if (_articlesSelectionnes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajoutez des articles avant de suspendre!')),
      );
      return;
    }
    String venteId = await _genererIdVente();
    try {
      await FirebaseFirestore.instance.collection('ventes').doc(venteId).set({
        'id': venteId,
        'articles': _articlesSelectionnes,
        'montantTotal': _montantTotal,
        'statut': 'suspendue', // vente sauvegardée comme suspendue
        'date': Timestamp.now(),
      });
      setState(() {
        _articlesSelectionnes.clear();
        _montantTotal = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vente suspendue avec succès!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suspension de la vente')),
      );
      print("Erreur: $e");
    }
  }

  // Affiche la liste des ventes suspendues et permet d'en reprendre une
  void _afficherVentesSuspendues() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('ventes')
        .where('statut', isEqualTo: 'suspendue')
        .get();

    if (querySnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune vente suspendue')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Ventes Suspendues'),
          children: querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return SimpleDialogOption(
              onPressed: () {
                _reprendreVente(doc);
                Navigator.pop(context);
              },
              child: Text(
                  'Vente ${data['id']} - Montant: ${data['montantTotal']} FCFA'),
            );
          }).toList(),
        );
      },
    );
  }

  // Reprend une vente suspendue en chargeant ses articles et montant total
  void _reprendreVente(DocumentSnapshot vente) {
    setState(() {
      _articlesSelectionnes =
          List<Map<String, dynamic>>.from(vente['articles']);
      _montantTotal = (vente['montantTotal'] as num).toDouble();
    });
    // Optionnel : supprimer la vente suspendue de Firestore une fois reprise
    FirebaseFirestore.instance.collection('ventes').doc(vente.id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vente reprise. Vous pouvez continuer.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nouvelle Vente'),
        actions: [
          IconButton(
            icon: Icon(Icons.camera_alt),
            onPressed: _scannerCodeBarres,
          ),
          IconButton(
            icon: Icon(Icons.restore),
            onPressed: _afficherVentesSuspendues,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Recherche de produits
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Rechercher un produit',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('stock').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return Center(child: CircularProgressIndicator());

                  final stock = snapshot.data!.docs.where((doc) {
                    final produit = doc.data() as Map<String, dynamic>;
                    return produit['name']
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
                          title: Text(produit['name'],
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Prix: ${produit['prixVenteUnitaire']} FCFA'),
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
                                            'Prix: ${produit['prixVenteUnitaire']} FCFA'),
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
                        subtitle: Text(
                            'Prix total: ${article['prixTotal']} FCFA'),
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
}
