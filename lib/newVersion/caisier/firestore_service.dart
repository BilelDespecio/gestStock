import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference ventesCollection =
      FirebaseFirestore.instance.collection('ventes');

  /// Récupère toutes les ventes en temps réel
  Stream<QuerySnapshot> getVentes() {
    return ventesCollection.snapshots();
  }

  /// Valide la vente et met à jour le Firestore avec le numéro WhatsApp et la date de validation
  Future<void> validerVente(
      String venteId, String numeroWhatsApp, String factureUrl) async {
    await ventesCollection.doc(venteId).update({
      'statut': 'validé',
      'client': numeroWhatsApp,
      'factureUrl': factureUrl, // Ajout du lien de la facture
      'dateValidation': Timestamp.now(),
      'destockage': false, // On peut gérer le stock plus tard
    });
  }
}
