import 'package:flutter/material.dart';

class DetailProduitPage extends StatelessWidget {
  final Map<String, dynamic> produit;

  const DetailProduitPage({Key? key, required this.produit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    final String imageUrl = produit['image'] ?? '';
    final String nomProduit = produit['nom'] ?? 'Nom inconnu';
    final double prix = produit['prixVente']?.toDouble() ?? 0;
    final int quantite = produit['quantiteDisponible'] ?? 0;
    final int seuilCritique = produit['seuil_critique'] ?? 0;
    final int seuilAlerte = produit['seuil_alerte'] ?? 0;
    final String description = produit['description'] ?? "Aucune description disponible.";
    final String type = produit['type'] ?? "Type inconnu";
    final String poids = produit['poids'] ?? ' Poids inconnu';
    final String gamme = produit['gamme'] ?? 'Gamme inconnue';

    // Déterminer l'état du stock
    String stockStatus = "En stock";
    Color stockColor = Colors.green;
    if (quantite <= seuilCritique) {
      stockStatus = "Stock Critique";
      stockColor = Colors.red;
    } else if (quantite <= seuilAlerte) {
      stockStatus = "Stock Alerte";
      stockColor = Colors.orange;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(nomProduit),
         backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Affichage de l'image du produit
            if (imageUrl.isNotEmpty)
              Hero(
                tag: produit['nom'], // Animation fluide
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  Text(
                    nomProduit,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$prix FCFA",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text("Stock : $quantite unités", style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Chip(
                        label: Text(stockStatus, style: const TextStyle(color: Colors.white)),
                        backgroundColor: stockColor,
                      ),
                    ],
                  ),
                  SizedBox(height: 5,),
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
                          const SnackBar(content: Text("Cette fonctionnalité est en mise à jour")),
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
