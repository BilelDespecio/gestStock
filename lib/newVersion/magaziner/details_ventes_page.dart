import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DetailVentePage extends StatelessWidget {
  final QueryDocumentSnapshot vente;

  DetailVentePage({required this.vente});

Future<void> _confirmerVente(BuildContext context) async {
  try {
    final venteRef = FirebaseFirestore.instance.collection('ventes').doc(vente.id);
    final stockRef = FirebaseFirestore.instance.collection('stock');

    List<dynamic> articles = vente['articles']; // Liste des produits de la vente

    for (var article in articles) {
      String articleId = article['nom'];  // L'identifiant correct du produit
      int quantiteDemandee = article['quantite'];

      DocumentSnapshot stockDoc = await stockRef.doc(articleId).get();

      if (stockDoc.exists) {
        int stockActuel = stockDoc['quantiteDisponible'] ?? 0;
        int nouvelleQuantite = stockActuel - quantiteDemandee;

        if (nouvelleQuantite >= 0) {
          // Mise à jour du stock
          await stockRef.doc(articleId).update({
            'quantiteDisponible': nouvelleQuantite,
            'derniereMiseAJour': FieldValue.serverTimestamp(),
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stock insuffisant pour ${article['name']}')),
          );
          return; // Arrête l'opération si un produit manque en stock
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produit non trouvé: ${article['name']}')),
        );
        return; // Arrête l'opération si un produit est introuvable
      }
    }

    // Mettre à jour le statut de la vente (destockage = true)
    await venteRef.update({'destockage': true});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vente confirmée avec succès!')),
    );

    Navigator.pop(context); // Retour à la page précédente
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur lors de la confirmation: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    bool destockage = vente['destockage'];
    String client = vente['client'];

    return Scaffold(
      appBar: AppBar(title: Text('Détail Vente ${vente.id}'), backgroundColor: Colors.blue.shade800, centerTitle: true, elevation: 4),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${vente.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if(client != '')
            Text('Client: ${client} ', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Montant: ${vente['montantTotal']} FCFA', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Statut: ${vente['statut']}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Destockage: ${destockage ? 'oui' : 'non'}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Date de validation: ${vente['dateValidation'].toDate()}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),

            // Liste des produits de la vente
            const Text('Produits:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: vente['articles'].length,
                itemBuilder: (context, index) {
                  var produit = vente['articles'][index];
                  return ListTile(
                    title: Text(produit['nom']),
                    subtitle: Text('Quantité: ${produit['quantite']}'),
                  );
                },
              
              ),
            ),

            // Bouton de confirmation de la vente si non encore confirmée
            if (!destockage)
              Center(
                child: ElevatedButton(
                  onPressed: () => _confirmerVente(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Confirmer la Vente'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
