import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/admin/add_product.dart';
import 'package:gest_stock/newVersion/zoomImage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DetailProduitPage extends StatefulWidget {
    final Map<String, dynamic> produit;
    
  const DetailProduitPage({Key? key, required this.produit}) : super(key: key);

  @override
  State<DetailProduitPage> createState() => _DetailProduitPageState();
}

class _DetailProduitPageState extends State<DetailProduitPage> {

 bool _isAuthorized = false;
    late String imageUrl;
    late String nomProduit;
    late double prix;
    late int quantite;
    late int seuilCritique;
    late int seuilAlerte;
    late String description;
    late String type;
    late String poids;
    late String gamme;

    late String stockStatus;
    late Color stockColor;

  @override
  void initState() {
    super.initState();
    imageUrl = widget.produit['image'] ?? '';
    nomProduit = widget.produit['nom'] ?? 'Nom inconnu';
    prix = widget.produit['prixVente']?.toDouble() ?? 0;
    quantite = widget.produit['quantiteDisponible'] ?? 0;
    seuilCritique = widget.produit['seuil_critique'] ?? 0;
    seuilAlerte = widget.produit['seuil_alerte'] ?? 0;
    description = widget.produit['description'] ?? "Aucune description disponible.";
    type = widget.produit['type'] ?? "Type inconnu";
    poids = widget.produit['poids'] ?? ' Poids inconnu';
    gamme = widget.produit['gamme'] ?? 'Gamme inconnue';

    stockStatus = "En stock";
    stockColor = Colors.green;
    if (quantite <= seuilCritique) {
      stockStatus = "Stock Critique";
      stockColor = Colors.red;
    } else if (quantite <= seuilAlerte) {
      stockStatus = "Stock Alerte";
      stockColor = Colors.orange;
    }

    _checkUserRole();
  }
  
    void _confirmerSuppression(BuildContext context, String produitId) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Confirmation"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fermer la boîte de dialogue
                },
                child: Text("Annuler"),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('produits')
                      .doc(produitId)
                      .delete();

                  // Fermer la boîte de dialogue
                  Navigator.of(context).pop();

                  // Fermer la page actuelle pour revenir à la liste des produits
                  Navigator.of(context).pop();
                },
                child: Text("Supprimer", style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );
    }

     // Vérifie le rôle de l'utilisateur
  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'] ?? ''; // Récupérer le rôle

        // Vérifier si l'utilisateur est admin ou user
        if (role == "admin" || role == "user") {
          setState(() {
            _isAuthorized = true;
          });
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération du rôle : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
        final String nomProduit = widget.produit['nom'] ?? 'Nom inconnu';
     return Scaffold(
      appBar: AppBar(
        title: Text(nomProduit),
        //backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
        actions: _isAuthorized
            ? [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AjouterProduitPage(produitId: nomProduit),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _confirmerSuppression(context, nomProduit);
                  },
                ),
              ]
            : [],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Affichage de l'image du produit
            if (imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageZoomPage(
                          imageUrl: imageUrl, tag: widget.produit['nom']),
                    ),
                  );
                },
                child: Hero(
                  tag: widget.produit['nom'], // Animation fluide
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_not_supported, size: 200),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 250,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 100, color: Colors.grey),
              ),
            // Détails du produit
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gamme,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                  Text(
                    nomProduit,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$prix FCFA",
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text("Stock : $quantite unités",
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Chip(
                        label: Text(stockStatus,
                            style: const TextStyle(color: Colors.white)),
                        backgroundColor: stockColor,
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    children: [
                      Text(" $type ", style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Text(" $poids ", style: const TextStyle(fontSize: 16))
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Description :",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Bouton d'action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Action à définir (ex: ajouter au panier)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Cette fonctionnalité est en mise à jour")),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text("Ajouter au panier"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  
  }
}