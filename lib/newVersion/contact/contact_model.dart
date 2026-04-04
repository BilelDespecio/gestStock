import 'package:cloud_firestore/cloud_firestore.dart';

class ClientContact {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String email;
  final String? entreprise;
  final String? notes;
  final DateTime dateAjout;
  final List<String> canauxCommunication; // SMS, Email, WhatsApp, etc.
  final bool consentementPub;
  final String? photoUrl; // Nouveau champ pour le futur

  ClientContact({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.email,
    this.entreprise,
    this.notes,
    required this.dateAjout,
    this.canauxCommunication = const [],
    required this.consentementPub,
    this.photoUrl,
  });

  factory ClientContact.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return ClientContact(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      telephone: data['telephone'] ?? '',
      email: data['email'] ?? '',
      entreprise: data['entreprise'],
      notes: data['notes'],
      dateAjout: (data['dateAjout'] as Timestamp?)?.toDate() ?? DateTime.now(),
      canauxCommunication: List<String>.from(data['canauxCommunication'] ?? []),
      consentementPub: data['consentementPub'] ?? false,
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'entreprise': entreprise,
      'notes': notes,
      'dateAjout': Timestamp.fromDate(dateAjout),
      'canauxCommunication': canauxCommunication,
      'consentementPub': consentementPub,
      'photoUrl': photoUrl,
      'searchKeywords': [
        nom.toLowerCase(),
        prenom.toLowerCase(),
        telephone.replaceAll(RegExp(r'[^0-9]'), ''),
      ],
    };
  }

  String get nomComplet => '$prenom $nom';
  String get initiales => (prenom.isNotEmpty ? prenom[0] : '') + (nom.isNotEmpty ? nom[0] : '');
}