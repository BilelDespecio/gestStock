import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Requête de base triée par date (du plus récent)
  Query get ventesQuery => _firestore.collection('ventes')
      .orderBy('date', descending: true);

  /// Récupère toutes les ventes triées
  Stream<QuerySnapshot> getVentes() {
    return ventesQuery.snapshots();
  }

  /// Valide une vente avec toutes les infos nécessaires
  Future<void> validerVente(
    String venteId, 
    String numeroWhatsApp, 
    String factureUrl
  ) async {
    await _firestore.collection('ventes').doc(venteId).update({
      'statut': 'validé',
      'client': numeroWhatsApp,
      'factureUrl': factureUrl,
      'dateValidation': FieldValue.serverTimestamp(), // Préférable à Timestamp.now()
      'destockage': false,
    });
  }
}