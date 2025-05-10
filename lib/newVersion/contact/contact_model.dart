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
  });

  factory ClientContact.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return ClientContact(
      id: doc.id,
      nom: data['nom'],
      prenom: data['prenom'],
      telephone: data['telephone'],
      email: data['email'],
      entreprise: data['entreprise'],
      notes: data['notes'],
      dateAjout: data['dateAjout'].toDate(),
      canauxCommunication: List<String>.from(data['canauxCommunication'] ?? []),
      consentementPub: data['consentementPub'] ?? false,
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
      'tags': [], // Pour segmentation future
    };
  }
}