import 'package:cloud_firestore/cloud_firestore.dart';

class ProduitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getProductsStream({bool isMagasin = false}) {
    return _firestore
        .collection('produits')
        .snapshots()
        .asyncMap((produitSnapshot) async {
      
      // Récupérer le stock principal (magasin)
      final stockSnapshot = await _firestore.collection('stock').get();
      Map<String, dynamic> stockMap = {};
      for (var doc in stockSnapshot.docs) {
        final data = doc.data();
        if (data['nom'] != null) {
          stockMap[data['nom']] = data;
        }
      }

      // Récupérer le stock boutique si nécessaire
      Map<String, dynamic> stockBoutiqueMap = {};
      if (!isMagasin) {
        final stockBoutiqueSnapshot = await _firestore.collection('stockBoutique').get();
        for (var doc in stockBoutiqueSnapshot.docs) {
          final data = doc.data();
          if (data['nom'] != null) {
            stockBoutiqueMap[data['nom']] = data;
          }
        }
      }

      List<Map<String, dynamic>> products = produitSnapshot.docs.map((prodDoc) {
        var produitData = prodDoc.data();
        String produitNom = produitData['nom'];

        var stockData = stockMap[produitNom];
        double pvp = stockData?['pvp']?.toDouble() ?? 0.0;
        int quantiteMagasin = stockData?['quantiteDisponible'] ?? 0;

        int quantiteAffichage = quantiteMagasin;
        if (!isMagasin) {
          var stockBoutiqueData = stockBoutiqueMap[produitNom];
          quantiteAffichage = stockBoutiqueData?['quantite'] ?? 0;
        }

        return {
          'id': prodDoc.id,
          'gamme': produitData['gamme'],
          'nom': produitNom,
          'prixVente': pvp,
          'quantiteDisponible': quantiteAffichage,
          'image': produitData['imageUrl'] ?? '',
          'seuil_critique': produitData['seuil_critique'] ?? 0,
          'seuil_alerte': produitData['seuil_alerte'] ?? 0,
          'code_barre': produitData['code_barre'] ?? '',
          'type': produitData['type'] ?? '',
          'poids': produitData['poids'] ?? 0,
          'description': produitData['description'] ?? '',
          'prixDecide': produitData['prixDecide'],
          'poidsProduit': produitData['quantite'],
          'unite': produitData['unite'] ?? '',
        };
      }).toList();

      return products;
    });
  }
}
