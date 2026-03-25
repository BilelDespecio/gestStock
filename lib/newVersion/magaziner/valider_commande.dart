import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:gest_stock/newVersion/magaziner/convertXof.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

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
  double _margeBeneficiaire = 0.45; // Marge bénéficiaire de 20%
  double _prixVenteMarche = 0.0;
  List<TextEditingController> _prixTotalControllers = [];
  List<TextEditingController> _prixVenteMarcheControllers = [];
  List<TextEditingController> _quantiteControllers = [];

  // List pour stocker les données calculées pour chaque article
  List<Map<String, dynamic>> _validatedArticles = [];
  bool isLoading = false; // Indicateur de chargement

 @override
void initState() {
  super.initState();
  
  // Initialiser avec les valeurs existantes ou des valeurs par défaut réalistes
  _prixVenteMarche = 0.0;

  for (var article in widget.articles) {
    // Calcul des prix unitaires initiaux
    double prixTotal = (article['prixTotal'] ?? 0).toDouble();
    double quantite = (article['quantity'] ?? 1).toDouble();
    
    _validatedArticles.add({
      'id': article['id']?.toString() ?? '',
      'name': article['name']?.toString() ?? 'Article inconnu',
      'prixTotal': prixTotal,
      'poids': (article['poids'] ?? 0).toString(),
      'quantity': quantite,
      'gamme': article['gamme']?.toString(),
      'type': article['type']?.toString(),
      // Calcul des valeurs initiales
      'prixRevientUnitaire': prixTotal / quantite,
      'prixVenteUnitaire': (prixTotal * 1.3) / quantite,
      'prixVenteMarche': _prixVenteMarche,
      'prixTotalAchat': prixTotal,
      'prixVenteTotal': prixTotal * 1.3,
      'Pvp': _calculerPVP(prixTotal: prixTotal, quantity: quantite),
    });

    // Initialisation des contrôleurs
    _prixTotalControllers.add(TextEditingController(text: prixTotal.toStringAsFixed(2)));
    _prixVenteMarcheControllers.add(TextEditingController(text: _prixVenteMarche.toStringAsFixed(2)));
    _quantiteControllers.add(TextEditingController(text: quantite.toStringAsFixed(0)));
  }
}
  /*
  void _validerCommande() async {
    setState(() {
      isLoading = true;
    });

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('taux_conversion')
          .doc('NGN_XOF')
          .get();

      double tauxNGNtoXOF =
          ((doc.data() as Map<String, dynamic>?)?['NGN_XOF'] as num?)?.toDouble() ?? 0.4;

      if (_formKey.currentState!.validate()) {
        _formKey.currentState!.save();

        for (int i = 0; i < _validatedArticles.length; i++) {
          double prixTotalNGN =
              double.tryParse(_prixTotalControllers[i].text) ?? 0.0;
          double prixTotalXOF = prixTotalNGN * tauxNGNtoXOF;
          _validatedArticles[i]['prixTotal'] = prixTotalXOF;
        }

        List<String> alertesProduits = [];

        _validatedArticles.forEach((article) {
          double prixTotal = (article['prixTotal'] as num).toDouble();
          double quantity = (article['quantity'] as num).toDouble();
          double pvm = (article['prixVenteMarche'] as num).toDouble();

          double prixVenteTotal = prixTotal * 1.45;
          double prixVentePrevisionnel = prixVenteTotal / quantity;
          double prixVentePrevisionnelArrondi = prixVentePrevisionnel.ceilToDouble();
          double diff = (pvm - prixVentePrevisionnelArrondi).abs();

          double tolerance = 0;
          if (pvm < 1000) {
            tolerance = 50;
          } else if (pvm < 5000) {
            tolerance = 100;
          } else if (pvm < 8000) {
            tolerance = 150;
          } else if (pvm < 10000) {
            tolerance = 200;
          } else if (pvm < 20000) {
            tolerance = 500;
          }

          if (diff > tolerance) {
            alertesProduits.add(
              "${article['name']} → PVM: ${pvm.toInt()} FCFA, PVP: ${prixVentePrevisionnelArrondi.toInt()} FCFA, "
              "Tolérance: $tolerance FCFA, Différence: $diff FCFA",
            );
          }

          article['prixVenteTotal'] = prixVenteTotal;
          article['Pvp'] = prixVentePrevisionnelArrondi;
        });

        if (alertesProduits.isNotEmpty) {
          await envoyerEmail(alertesProduits);
        }

        await FirebaseFirestore.instance
            .collection('commandes')
            .doc(widget.commandId)
            .update({
          'statut': 'validée',
          'articles': _validatedArticles,
          'fraisAnnexes': _fraisAnnexes,
          'margeBeneficiaire': _margeBeneficiaire,
          'dateValidation': FieldValue.serverTimestamp(),
          'totalArticles': // la somme des quantites, pour le stock
              _validatedArticles.fold(0, (sum, article) {
            return (sum as int) + (article['quantity'] as num).toInt();
          }),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Commande validée avec succès!')),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur : ${e.toString()}')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }
  */
/*
  Future<void> _validerCommande({
  required String commandId,
  required List<Map<String, dynamic>> articles,
  required double fraisAnnexes,
  required double margeBeneficiaire,
  required BuildContext context,
}) async {
  try {
    // 1. Conversion devise
    final taux = await _getTauxConversionNGNtoXOF();
    
    // 2. Calcul des prix
    final articlesAvecPrix = _calculerPrixArticles(
      articles: articles,
      tauxConversion: taux,
    );

    // 3. Vérification des écarts
    final alertes = _verifierEcartsPrix(articlesAvecPrix);
    if (alertes.isNotEmpty) {
      await _envoyerAlertesEmail(alertes);
    }

    // 4. Mise à jour BDD
    await _mettreAJourCommande(
      commandId: commandId,
      articles: articlesAvecPrix,
      fraisAnnexes: fraisAnnexes,
      margeBeneficiaire: margeBeneficiaire,
    );

    await _mettreAJourStock(
      widget.commandId,
      _validatedArticles,
    );

    // 5. Notification succès
    _afficherNotification(context, '✅ Commande validée avec succès');
    
  } catch (e) {
    _afficherNotification(context, '❌ Erreur: ${e.toString()}');
    rethrow;
  }
}
*/

Future<void> _validerCommande({required String commandId, required List<Map<String, dynamic>> articles, required double fraisAnnexes, required double margeBeneficiaire, required BuildContext context}) async {
  setState(() => isLoading = true);
  
  try {
    // 1. Récupération du taux de conversion
    final taux = await _getTauxConversionNGNtoXOF();

    // 2. Calcul des nouveaux prix pour chaque article
    for (int i = 0; i < _validatedArticles.length; i++) {
      double prixTotalNGN = double.tryParse(_prixTotalControllers[i].text) ?? 0.0;
      double prixTotalXOF = prixTotalNGN * taux;
      double quantite = double.tryParse(_quantiteControllers[i].text) ?? 1.0;
      
      // Calcul des prix unitaires
      double prixRevientUnitaire = prixTotalXOF / quantite;
      double prixVenteUnitaire = (prixTotalXOF * 1.45) / quantite;
      
      // Mise à jour de l'article
      _validatedArticles[i] = {
        ..._validatedArticles[i],
        'prixTotal': prixTotalXOF,
        'prixRevientUnitaire': prixRevientUnitaire,
        'prixVenteUnitaire': prixVenteUnitaire,
        'Pvp': _calculerPVP(prixTotal: prixTotalXOF, quantity: quantite),
        'prixVenteMarche': double.tryParse(_prixVenteMarcheControllers[i].text) ?? 0.0,
      };
    }

    // 3. Vérification des écarts
    final alertes = _verifierEcartsPrix(_validatedArticles);
    if (alertes.isNotEmpty) await _envoyerAlertesEmail(alertes);

    // 4. Mise à jour du stock
    await _mettreAJourStock(widget.commandId, _validatedArticles);
    
    // 5. Mise à jour de la commande
    await FirebaseFirestore.instance
        .collection('commandes')
        .doc(widget.commandId)
        .update({
          'statut': 'validée',
          'articles': _validatedArticles,
          'fraisAnnexes': _fraisAnnexes,
          'margeBeneficiaire': _margeBeneficiaire,
          'dateValidation': FieldValue.serverTimestamp(),
          'totalArticles': _validatedArticles.fold<int>(0, (sum, article) => sum + (article['quantity'] as num).toInt()),
        });

    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Commande validée avec succès!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Erreur: ${e.toString()}')),
    );
    rethrow;
  } finally {
    setState(() => isLoading = false);
  }
}

  Future<double> _getTauxConversionNGNtoXOF() async {
  final doc = await FirebaseFirestore.instance
      .collection('taux_conversion')
      .doc('NGN_XOF')
      .get();
  return (doc.data()?['NGN_XOF'] as num?)?.toDouble() ?? 0.4;
}

List<Map<String, dynamic>> _calculerPrixArticles({
  required List<Map<String, dynamic>> articles,
  required double tauxConversion,
}) {
  return articles.map((article) {
    // Conversion XOF
    final prixTotalXOF = (article['prixTotal'] as num).toDouble() * tauxConversion;

    // Calcul PVP (Marge 45% + arrondi multiple de 25)
    final pvp = _calculerPVP(
      prixTotal: prixTotalXOF,
      quantity: (article['quantity'] as num).toDouble(),
    );

    return {
      ...article,
      'prixTotal': prixTotalXOF,
      'prixVenteTotal': prixTotalXOF * 1.3,
      'Pvp': pvp,
    };
  }).toList();
}

  double _calculerPVP({required double prixTotal, required double quantity}) {
  double pvpBase = (prixTotal * 1.45) / quantity;
  return (pvpBase % 25 == 0) ? pvpBase : (pvpBase / 25).ceil() * 25;
}

  List<String> _verifierEcartsPrix(List<Map<String, dynamic>> articles) {
    final List<String> alertes = [];

    for (final article in articles) {
      try {
        // Vérification et conversion sécurisée des valeurs
        final pvm = (article['prixVenteMarche'] as num?)?.toDouble();
        final pvp = (article['Pvp'] as num?)?.toDouble();
        final nomArticle = article['name']?.toString() ?? 'Article sans nom';

        // Si une des valeurs est null, on passe à l'article suivant
        if (pvm == null || pvp == null) {
          debugPrint('Données manquantes pour $nomArticle - PVM: $pvm, PVP: $pvp');
          continue;
        }

        // Calcul de la différence
        final diff = (pvm - pvp).abs();
        final tolerance = _calculerTolerance(pvm);

        if (diff > tolerance) {
          alertes.add(
            "$nomArticle → PVM: ${pvm.toInt()} FCFA, PVP: ${pvp.toInt()} FCFA, "
                "Tolérance: ${tolerance.toInt()} FCFA, Différence: ${diff.toStringAsFixed(2)} FCFA\n",
          );
        }
      } catch (e) {
        debugPrint('Erreur lors de la vérification des écarts: $e');
      }
    }

    return alertes;
  }

  double _calculerTolerance(double pvm) {
    if (pvm < 1000) return 50;
    if (pvm < 5000) return 100;
    if (pvm < 8000) return 150;
    if (pvm < 10000) return 200;
    if (pvm < 20000) return 500;
    return 1000; // Valeur par défaut pour les prix élevés
  }

  Future<void> _mettreAJourCommande({
    required String commandId,
    required List<Map<String, dynamic>> articles,
    required double fraisAnnexes,
    required double margeBeneficiaire,
  }) async {
    await FirebaseFirestore.instance.collection('commandes').doc(commandId).update({
      'statut': 'validée',
      'articles': articles,
      'fraisAnnexes': fraisAnnexes,
      'margeBeneficiaire': margeBeneficiaire,
      'dateValidation': FieldValue.serverTimestamp(),
      'totalArticles': articles.fold(0, (sum, article) {
        return (sum as int) + (article['quantity'] as num).toInt();
      }),
    });
  }

  Future<void> _envoyerAlertesEmail(List<String> alertesProduits) async {
  String username = 'hounganbilel@gmail.com';
  String password = 'rabv cjiz haoj vswm';

  final smtpServer = gmail(username, password);

  final message = Message()
    ..from = Address(username, 'SusCosmétics Alertes')
    ..recipients.add('losema1@yahoo.fr') // Remplace avec l'email de l'admin
    ..subject = '🚨 Alerte sur des écarts de prix !'
    ..text = "Attention, certains produits dépassent la tolérance :\n\n" +
        alertesProduits.join("\n");

  try {
    await send(message, smtpServer);
    print('📧 Email envoyé avec succès!');
  } catch (e) {
    print('❌ Erreur lors de l\'envoi de l\'email: $e');
  }
}
/*
  Future<void> _mettreAJourStock(
      String commandId, List<dynamic> articles) async {
    try {
      CollectionReference stockRef =
          FirebaseFirestore.instance.collection('stock');

      for (var article in articles) {
        // Vérification et assignation sécurisée des valeurs avec des valeurs par défaut si null
        String articleId = (article['id'] ?? '').toString(); // S'assurer que c'est une String non vide
        String name = (article['name'] ?? 'Article inconnu').toString();
        int pvp = (article['Pvp'] ?? 0).toInt();
        int quantiteAjoutee = (article['quantity'] ?? 0).toInt();
        int prixRevient = (article['prixRevientUnitaire'] ?? 0).toInt();
        int prixVente = (article['prixVenteUnitaire'] ?? 0).toInt();

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
            'pvp': pvp,
            'prixRevientUnitaire': prixRevient,
            'prixVenteUnitaire': prixVente,
          });

          print(
              "Stock mis à jour pour l'article: $name (Quantité ajoutée: $quantiteAjoutee)");
        } else {
          // Ajouter un nouvel article dans le stock
          await stockRef.doc(articleId).set({
            'nom': name,
            'quantiteDisponible': quantiteAjoutee,
            'prixRevientUnitaire': prixRevient,
            'prixVenteUnitaire': prixVente,
            'derniereMiseAJour': FieldValue.serverTimestamp(),
            'prixVenteMarche': article['prixVenteMarche'],
            'pvp': pvp
          });

          print("Nouvel article ajouté au stock: $name");
        }
      }

      print("Stock mis à jour avec succès pour la commande $commandId");
    } catch (e) {
      print("Erreur lors de la mise à jour du stock: $e");
    }
  }
*/

Future<void> _mettreAJourStock(String commandId, List<dynamic> articles) async {
  try {
    final stockRef = FirebaseFirestore.instance.collection('stock');

    for (var article in articles) {
      // Validation des données
      final articleId = (article['id']?.toString() ?? '').trim();
      if (articleId.isEmpty) {
        debugPrint("ID d'article vide - ignoré");
        continue;
      }

      // Conversion sécurisée des valeurs
      final data = {
        'nom': (article['name'] ?? 'Article inconnu').toString(),
        'quantiteDisponible': FieldValue.increment((article['quantity'] ?? 0).toInt()),
        'prixRevientUnitaire': (article['prixRevientUnitaire'] ?? 0).toDouble(),
        'prixVenteUnitaire': (article['prixVenteUnitaire'] ?? 0).toDouble(),
        'pvp': (article['Pvp'] ?? 0).toDouble(),
        'prixVenteMarche': (article['prixVenteMarche'] ?? 0).toDouble(),
        'derniereMiseAJour': FieldValue.serverTimestamp(),
      };

      // Mise à jour ou création
      await stockRef.doc(articleId).set(data, SetOptions(merge: true));

      debugPrint("Stock mis à jour pour l'article: ${data['nom']}");
    }

    debugPrint("Mise à jour du stock terminée pour la commande $commandId");
  } catch (e, stack) {
    debugPrint("Erreur mise à jour stock: $e\n$stack");
    rethrow;
  }
}
// Afficher une notification
void _afficherNotification(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Validation de la commande'),
        backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
      ),
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
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${_validatedArticles[index]['gamme']} ${_validatedArticles[index]['name']}'),
                            Text(
                                '${_validatedArticles[index]['type']} ${_validatedArticles[index]['poids']}'),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _prixTotalControllers[index],
                                    decoration: InputDecoration(
                                        labelText: 'Prix total d\'achat'),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _validatedArticles[index]['prixTotal'] =
                                            double.tryParse(value) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 5),
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                        _prixVenteMarcheControllers[index],
                                    decoration: InputDecoration(
                                        labelText: 'Prix de vente unitaire'),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _validatedArticles[index]
                                                ['prixVenteMarche'] =
                                            double.tryParse(value) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            TextFormField(
                              initialValue: _validatedArticles[index]
                                      ['quantity']
                                  .toString(),
                              decoration:
                                  InputDecoration(labelText: 'Quantité'),
                              keyboardType: TextInputType.number,
                              onSaved: (value) {
                                if (value != null && value.isNotEmpty) {
                                  _validatedArticles[index]['quantity'] =
                                      int.parse(value);
                                }
                              },
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty ||
                                    int.tryParse(value) == null) {
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
                  if (value == null ||
                      value.isEmpty ||
                      double.tryParse(value) == null) {
                    return 'Entrez des frais annexes valides';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await _validerCommande(
                          commandId: widget.commandId,
                          articles: _validatedArticles,
                          fraisAnnexes: _fraisAnnexes,
                          margeBeneficiaire: _margeBeneficiaire,
                          context: context,
                        );
                      }, // Désactiver si chargement
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Confirmer la validation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
