import 'package:cloud_firestore/cloud_firestore.dart';

class ProduitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getProductsStream() {
    return _firestore
        .collection('produits')
        .snapshots()
        .asyncMap((produitSnapshot) async {
      final stockSnapshot = await _firestore.collection('stock').get();

      Map<String, dynamic> stockMap = {
        for (var stock in stockSnapshot.docs) stock['nom']: stock.data()
      };

      final stockBoutiqueSnapshot = await _firestore.collection('stockBoutique').get();

      Map<String, dynamic> stockBoutiqueMap = {
        for (var stock in stockBoutiqueSnapshot.docs) stock['nom']: stock.data()
      };

      List<Map<String, dynamic>> products = produitSnapshot.docs.map((prodDoc) {
        var produitData = prodDoc.data();
        String produitNom = produitData['nom'];

        var stockData = stockMap[produitNom];
        double prixVente = stockData?['pvp']?.toDouble() ?? 0.0;

        var stockBoutiqueData = stockBoutiqueMap[produitNom];
        int quantiteBoutique = stockBoutiqueData?['quantite'] ?? 0;

        return {
          'id': prodDoc.id,
          'gamme': produitData['gamme'],
          'nom': produitNom,
          'prixVente': prixVente,
          'quantiteDisponible': quantiteBoutique,
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
