import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference ventesCollection =
  FirebaseFirestore.instance.collection('ventes');

  Stream<QuerySnapshot> getVentes() {
    return ventesCollection.snapshots();
  }

  Future<void> validerVente(String venteId, String numeroWhatsApp) async {
    await ventesCollection.doc(venteId).update({
      'statut': 'validé',
      'client': numeroWhatsApp,
      'dateValidation': Timestamp.now(),
      'destockage': false,
    });
  }
}
