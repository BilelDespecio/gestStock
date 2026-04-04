import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'constants.dart';
import 'services/produit_service.dart';

class VentePage extends StatefulWidget {
  @override
  _VentePageState createState() => _VentePageState();
}

class _VentePageState extends State<VentePage> {
  final ProduitService _produitService = ProduitService();
  StreamSubscription? _produitsSubscription;
  
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  late List<Map<String, dynamic>> _articlesSelectionnes = [];
  
  double _montantTotal = 0.0;
  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _produitsSubscription?.cancel();
    super.dispose();
  }

  void _loadData() {
    _produitsSubscription = _produitService.getProductsStream().listen((products) {
      if (mounted) {
        setState(() {
          _allProducts = products;
          _filterProducts(_searchQuery);
          _isLoading = false;
        });
      }
    });
  }

  void _filterProducts(String query) {
    _searchQuery = query.toLowerCase();
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredProducts = List.from(_allProducts);
      } else {
        _filteredProducts = _allProducts.where((product) {
          final nomProduit = product['nom']?.toString().toLowerCase() ?? '';
          final gammeProduit = product['gamme']?.toString().toLowerCase() ?? '';
          return nomProduit.contains(_searchQuery) || gammeProduit.contains(_searchQuery);
        }).toList();
      }
    });
  }

  Future<String> _genererIdVente() async {
    QuerySnapshot ventesValidees = await FirebaseFirestore.instance
        .collection('ventes')
        .where('statut', whereIn: ['validé', 'en attente']).get();
    int numeroVente = ventesValidees.docs.length + 1;
    String _currentDate = DateTime.now().toIso8601String().split('T')[0];

    return 'VET$numeroVente-$_currentDate';
  }

  void _ajouterArticleFromDialog(Map<String, dynamic> article, int quantite) {
    try {
      double prixUnitaire = (article['prixUnitaire'] ?? 0.0).toDouble();

      setState(() {
        double prixTotal = prixUnitaire * quantite;
        _articlesSelectionnes.add({
          'id': article['id']?.toString() ?? '',
          'nom': article['nom']?.toString() ?? 'Article inconnu',
          'quantite': quantite,
          'prixUnitaire': prixUnitaire,
          'prixTotal': prixTotal,
          'prixReference': article['prixReference'],
        });
        _calculerMontantTotal();
      });
    } catch (e) {
      debugPrint("Erreur lors de l'ajout d'article: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'ajout du produit')),
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

  Future<void> _soumettreVente(DateTime date) async {
    try {
      if (_articlesSelectionnes.isEmpty) {
        throw Exception("Aucun article sélectionné");
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté");
      }

      String venteId = await _genererIdVente();
      DocumentSnapshot vendeurDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      await FirebaseFirestore.instance.collection('ventes').doc(venteId).set({
        'id': venteId,
        'articles': _articlesSelectionnes,
        'montantTotal': _montantTotal,
        'statut': 'en attente',
        'date': Timestamp.fromDate(date),
        'vendeurId': user.uid,
        'vendeurNom': vendeurDoc['name'] ?? user.displayName ?? 'Vendeur inconnu',
        'vendeurEmail': user.email,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _articlesSelectionnes.clear();
        _montantTotal = 0.0;
      });

    } catch (e) {
      debugPrint("Erreur _soumettreVente: $e");
      rethrow;
    }
  }

  void _scannerCodeBarres() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Scanner un Code-Barres",
            style: TextStyle(
                color: AppColors.primaryTextColor,
                fontWeight: FontWeight.bold)),
        content: SizedBox(
          height: 300,
          child: MobileScanner(
            onDetect: (barcode) {
              if (barcode.barcodes.isNotEmpty && barcode.barcodes.first.rawValue != null) {
                String scannedCode = barcode.barcodes.first.rawValue!;
                Navigator.of(context).pop();

                try {
                  final produit = _allProducts.firstWhere(
                    (p) => p['code_barre'] == scannedCode,
                    orElse: () => <String, dynamic>{},
                  );

                  if (produit.isNotEmpty) {
                    final prixDecide = produit['prixDecide']?.toDouble();
                    final prixVente = produit['prixVente']?.toDouble() ?? 0.0;
                    final prixPourCalcul = prixDecide ?? prixVente;
                    final stockDispo = (produit['quantiteDisponible'] ?? 0).toInt();

                    if (mounted) {
                      _showQuantiteDialog(produit, prixPourCalcul, stockDispo);
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code-barre non reconnu dans le stock.')),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint("Erreur scan : $e");
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _suspendreVente() async {
    if (_articlesSelectionnes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez des articles avant de suspendre!')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentification requise')),
      );
      return;
    }

    final clientName = await _demanderNomClient();
    if (clientName == null || clientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom du client requis')),
      );
      return;
    }

    try {
      final venteId = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}';

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

      _reinitialiserVenteActuelle();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vente suspendue pour $clientName'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Erreur suspension vente: $e');
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

  Future<String?> _demanderNomClient() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Nom du client',
            style: TextStyle(
                color: AppColors.primaryTextColor,
                fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Entrez le nom du client',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: TextStyle(color: AppColors.secondaryTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _reinitialiserVenteActuelle() {
    setState(() {
      _articlesSelectionnes.clear();
      _montantTotal = 0.0;
    });
  }

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
          .where('vendeurId', isEqualTo: user.uid)
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
            title: const Text('Mes Ventes Suspendues', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    color: AppColors.cardColor,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('Vente ${data['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${data['montantTotal']} FCFA',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.priceColor)),
                          Text('Client: ${data['client'] ?? 'Non spécifié'}'),
                          Text('Date: $dateFormat',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(color: AppColors.accentColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: IconButton(
                          icon:  Icon(Icons.replay, color: AppColors.accentColor),
                          onPressed: () {
                            _reprendreVente(doc);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:  Text('Fermer', style: TextStyle(color: AppColors.secondaryTextColor)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Erreur ventes suspendues: $e');
    }
  }

  void _reprendreVente(DocumentSnapshot vente) async {
    try {
      final data = vente.data() as Map<String, dynamic>;
      setState(() {
        _articlesSelectionnes = List<Map<String, dynamic>>.from(data['articles'] ?? []);
        _montantTotal = (data['montantTotal'] as num).toDouble();
      });

      await FirebaseFirestore.instance.collection('ventes').doc(vente.id).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vente reprise, vous pouvez continuer le paiement.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la reprise de la vente')),
      );
      debugPrint("Erreur reprise vente: $e");
    }
  }

  Future<void> _confirmerEtSoumettreVente(BuildContext context) async {
    try {
      if (!mounted) return;
      final DateTime dateActuelle = DateTime.now();

      final DateTime? dateSelectionnee = await showDatePicker(
        context: context,
        initialDate: dateActuelle,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        locale: const Locale("fr", "FR"),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme:  ColorScheme.light(
                primary: AppColors.accentColor,
                onPrimary: Colors.white,
                onSurface: AppColors.primaryTextColor,
              ),
            ),
            child: child!,
          );
        },
      );

      if (dateSelectionnee == null || !mounted) return;

      final bool confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text("Confirmer la date", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text("Valider la vente pour le ${DateFormat('dd/MM/yyyy').format(dateSelectionnee)} ?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child:  Text("Annuler", style: TextStyle(color: AppColors.secondaryTextColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.priceColor),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text("Confirmer", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ) ?? false;

      if (confirm) {
        await _soumettreVente(dateSelectionnee);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Vente enregistrée pour le ${DateFormat('dd/MM/yyyy').format(dateSelectionnee)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.priceColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur dans _confirmerEtSoumettreVente: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          backgroundColor: AppColors.criticalColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showQuantiteDialog(Map<String, dynamic> produit, double prixPourCalcul, int stockDisponible) {
    int quantite = 1;
    final prixAAfficher = prixPourCalcul.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Quantité à vendre', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${produit['gamme']} ${produit['nom']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Prix unitaire: $prixAAfficher FCFA', style:  TextStyle(color: AppColors.priceColor, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('En stock: $stockDisponible', style: TextStyle(color: stockDisponible > 0 ? AppColors.accentColor : AppColors.criticalColor)),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantité',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
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
                child: Text('Annuler', style: TextStyle(color: AppColors.secondaryTextColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (quantite > stockDisponible) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stock insuffisant! Disponible: $stockDisponible'), backgroundColor: AppColors.criticalColor),
                    );
                  } else {
                    final articleToAdd = {
                      'id': produit['id'],
                      'nom': produit['nom'],
                      'prixUnitaire': prixPourCalcul,
                      'prixReference': produit['prixDecide'] != null ? 'prixDecide' : 'prixVente',
                    };
                    _ajouterArticleFromDialog(articleToAdd, quantite);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Ajouter au panier', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title:  Text('Nouvelle Vente', style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon:  Icon(Icons.history, color: AppColors.accentColor),
            tooltip: "Ventes suspendues",
            onPressed: _afficherVentesSuspendues,
          ),
        ],
        backgroundColor: AppColors.cardColor,
        iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
        centerTitle: true,
        elevation: 1,
      ),
      body: _isLoading 
        ?  Center(child: CircularProgressIndicator(color: AppColors.accentColor))
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barre de recherche
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: TextField(
                      decoration:  InputDecoration(
                        hintText: 'Rechercher un produit...',
                        hintStyle: TextStyle(color: AppColors.secondaryTextColor),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: AppColors.accentColor),
                      ),
                      onChanged: _filterProducts,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.accentColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppColors.accentColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                    ]
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
                    onPressed: _scannerCodeBarres,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Liste des produits en stock
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Text('Aucun produit disponible.',
                          style: TextStyle(
                              color: AppColors.secondaryTextColor,
                              fontSize: 16)))
                  : ListView.builder(
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final produit = _filteredProducts[index];
                    final prixDecide = produit['prixDecide']?.toDouble();
                    final prixVente = produit['prixVente']?.toDouble() ?? 0.0;
                    final prixPourCalcul = prixDecide ?? prixVente;
                    final stock = (produit['quantiteDisponible'] ?? 0).toInt();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text('${produit['gamme']} ${produit['nom']}', style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTextColor)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Stock: $stock', style: TextStyle(fontWeight: FontWeight.w600, color: stock > 0 ? AppColors.priceColor : AppColors.criticalColor)),
                            const SizedBox(height: 2),
                            Text('${prixPourCalcul.toStringAsFixed(0)} FCFA', style:  TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accentColor)),
                          ],
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(color: stock > 0 ? AppColors.accentColor.withOpacity(0.1) : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            icon: Icon(Icons.add_shopping_cart, color: stock > 0 ? AppColors.accentColor : Colors.grey),
                            onPressed: stock > 0 ? () => _showQuantiteDialog(produit, prixPourCalcul, stock) : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ),
            
            // Résumé de la commande (Panier)
            if (_articlesSelectionnes.isNotEmpty) ...[
              const Divider(height: 32, thickness: 1, color: Colors.black12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text('🛒 Panier actuel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor)),
                   Text('${_articlesSelectionnes.length} Article(s)', style:  TextStyle(fontSize: 14, color: AppColors.secondaryTextColor, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              
              // Liste du panier
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _articlesSelectionnes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (context, index) {
                    final article = _articlesSelectionnes[index];
                    return ListTile(
                      dense: true,
                      title: Text('${article['nom']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text('x${article['quantite']}', style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentColor)),
                          ),
                          const SizedBox(width: 8),
                          Text('${(article['prixTotal'] as num).toStringAsFixed(0)} FCFA', style:  TextStyle(color: AppColors.priceColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: IconButton(
                        icon:  Icon(Icons.remove_circle, color: AppColors.criticalColor),
                        onPressed: () => _supprimerArticle(index),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Total et Boutons d'Action
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total:',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryTextColor)),
                        Text('${_montantTotal.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppColors.priceColor,
                                letterSpacing: -0.5)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            onPressed: _suspendreVente,
                            icon: Icon(Icons.pause,
                                color: AppColors.alertColor, size: 20),
                            label: Text('Attente',
                                style: TextStyle(
                                    color: AppColors.alertColor,
                                    fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side:  BorderSide(color: AppColors.alertColor, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmerEtSoumettreVente(context),
                            icon: const Icon(Icons.check_circle, color: Colors.white, size: 22),
                            label: const Text('Encaisser', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.priceColor,
                              elevation: 4,
                              shadowColor: AppColors.priceColor.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
