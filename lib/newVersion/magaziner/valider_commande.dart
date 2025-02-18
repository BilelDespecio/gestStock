import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class ValiderCommandePage extends StatefulWidget {
  final String commandId;
  final List<dynamic> articles;

  ValiderCommandePage({required this.commandId, required this.articles});

  @override
  _ValiderCommandePageState createState() => _ValiderCommandePageState();
}

class _ValiderCommandePageState extends State<ValiderCommandePage> {
  final _formKey = GlobalKey<FormState>();
  double _fraisAnnexes = 0.0;
  double _margeBeneficiaire = 0.20; // Marge bénéficiaire de 20%

  // List pour stocker les données calculées pour chaque article
  List<Map<String, dynamic>> _validatedArticles = [];

  @override
  void initState() {
    super.initState();
    // Initialiser les articles avec les données par défaut
    widget.articles.forEach((article) {
      _validatedArticles.add({
        'id': article['name'],
        'name': article['name'],
        'prixTotal': article['prixTotal'],
        'quantite': article['quantite'],
        'prixRevientUnitaire': 0.0,
        'prixVenteUnitaire': 0.0,
      });
    });
  }

void _validerCommande() async {
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();

    // Calcul du prix de revient total
    double prixRevientTotal = 0.0;
    _validatedArticles.forEach((article) {
      prixRevientTotal += article['prixTotal'];
    });

    // Ajout des frais annexes au prix de revient total
    prixRevientTotal += _fraisAnnexes;

    // Calcul du prix de revient unitaire et du prix de vente
    double totalQuantite = _validatedArticles.fold(0.0, (total, article) {
      return total + (article['quantite'] as num).toDouble();
    });

    

    _validatedArticles.forEach((article) {
      double prixRevientUnitaire = (article['prixTotal'] as num).toDouble() / 
                                   (article['quantite'] as num).toDouble() + 
                                   (_fraisAnnexes / totalQuantite);

    // arrondir du prix de reviens unitaire à l'entier supérieur
    double prixRevientUnitaireArrondi = prixRevientUnitaire.ceilToDouble();

      article['prixRevientUnitaire'] = prixRevientUnitaireArrondi;

      double prixVenteUnitaire = prixRevientUnitaireArrondi * (1 + _margeBeneficiaire);

       // arrondir du prix de vente unitaire à l'entier supérieur
      double prixVenteUnitaireArrondi = prixVenteUnitaire.ceilToDouble();
      
      article['prixVenteUnitaire'] = prixVenteUnitaireArrondi;

    });

   

    // Mise à jour de Firestore avec les informations calculées
    await FirebaseFirestore.instance.collection('commandes').doc(widget.commandId).update({
      'statut': 'validée',
      'articles': _validatedArticles,
      'prixRevientTotal': prixRevientTotal,
      'fraisAnnexes': _fraisAnnexes,
    });

    // Appel de la fonction pour mettre à jour le stock après validation de la commande
    await mettreAJourStock(widget.commandId, _validatedArticles);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Commande validée avec succès!')),
    );

    Navigator.pop(context);
  }
}


Future<void> mettreAJourStock(String commandId, List<dynamic> articles) async {
  try {
    CollectionReference stockRef = FirebaseFirestore.instance.collection('stock');

    for (var article in articles) {
      // Vérification et assignation sécurisée des valeurs avec des valeurs par défaut si null
      String articleId = (article['id'] ?? '').toString();  // S'assurer que c'est une String non vide
      String name = (article['name'] ?? 'Article inconnu').toString();
      int quantiteAjoutee = (article['quantite'] ?? 0) as int;
      double prixRevient = (article['prixRevientUnitaire'] ?? 0.0).toDouble();
      double prixVente = (article['prixVenteUnitaire'] ?? 0.0).toDouble();

      if (articleId.isEmpty) {
        print("L'article ne contient pas d'ID valide. Ignoré.");
        continue; // Ignore cet article et passe au suivant
      }

      // Vérification de l'existence de l'article dans le stock
      DocumentSnapshot stockDoc = await stockRef.doc(articleId).get();

      if (stockDoc.exists) {
        // Mise à jour de la quantité si l'article existe déjà
        int quantiteExistante = (stockDoc['quantiteDisponible'] ?? 0) as int;

        await stockRef.doc(articleId).update({
          'quantiteDisponible': quantiteExistante + quantiteAjoutee,
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        print("Stock mis à jour pour l'article: $name (Quantité ajoutée: $quantiteAjoutee)");
      } else {
        // Ajouter un nouvel article dans le stock
        await stockRef.doc(articleId).set({
          'name': name,
          'quantiteDisponible': quantiteAjoutee,
          'prixRevientUnitaire': prixRevient,
          'prixVenteUnitaire': prixVente,
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        print("Nouvel article ajouté au stock: $name");
      }
    }

    print("Stock mis à jour avec succès pour la commande $commandId");

  } catch (e) {
    print("Erreur lors de la mise à jour du stock: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Validation de la commande')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _validatedArticles.length,
                  itemBuilder: (context, index) {
                    return Card(
                      child: ListTile(
                        title: Text('${_validatedArticles[index]['name']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              initialValue: _validatedArticles[index]['prixTotal'].toString(),
                              decoration: InputDecoration(labelText: 'Prix total d\'achat'),
                              keyboardType: TextInputType.number,
                              onSaved: (value) {
                                if (value != null && value.isNotEmpty) {
                                  _validatedArticles[index]['prixTotal'] = double.parse(value);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Entrez un prix valide';
                                return null;
                              },
                            ),
                            TextFormField(
                              initialValue: _validatedArticles[index]['quantite'].toString(),
                              decoration: InputDecoration(labelText: 'Quantité'),
                              keyboardType: TextInputType.number,
                              onSaved: (value) {
                                if (value != null && value.isNotEmpty) {
                                  _validatedArticles[index]['quantite'] = int.parse(value);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty || int.tryParse(value) == null) {
                                  return 'Entrez une quantité valide';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Frais annexes totaux'),
                keyboardType: TextInputType.number,
                onSaved: (value) {
                  if (value != null && value.isNotEmpty) {
                    _fraisAnnexes = double.parse(value);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Entrez des frais annexes valides';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _validerCommande,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('Confirmer la validation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
