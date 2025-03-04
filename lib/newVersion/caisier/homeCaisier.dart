import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gest_stock/newVersion/caisier/firestore_service.dart';
import 'details_vente_page.dart';

class AccueilCaissierPage extends StatefulWidget {
  @override
  _AccueilCaissierPageState createState() => _AccueilCaissierPageState();
}

class _AccueilCaissierPageState extends State<AccueilCaissierPage> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ventes'),
        backgroundColor: Colors.blue.shade800,
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getVentes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final ventes = snapshot.data!.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  })
              .toList();

          // Trier : D'abord les ventes en attente (statut == 'en attente'), puis les validées
          ventes.sort((a, b) {
            if (a['statut'] == 'en attente' && b['statut'] != 'en attente') {
              return -1; // En attente en haut
            }
            if (a['statut'] != 'en attente' && b['statut'] == 'en attente') {
              return 1; // Validé en bas
            }
            return 0; // Sinon, conserver l'ordre initial
          });

          return ListView.builder(
            itemCount: ventes.length,
            itemBuilder: (context, index) {
              final vente = ventes[index];
              final venteId = vente['id'];
              final montantTotal = vente['montantTotal'];
              final statut = vente['statut'];

              // Déterminer la couleur en fonction du statut
              Color statutColor = statut == 'validé' ? Colors.green.shade400 : Colors.orange.shade400;
              Icon statutIcon = statut == 'validé' ? Icon(Icons.check_circle, color: Colors.white) : Icon(Icons.hourglass_top, color: Colors.white);

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: statutColor, // Appliquer la couleur selon le statut
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: statutIcon,
                  title: Text(
                    'Vente #$venteId',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  subtitle: Text(
                    'Montant: ${montantTotal ?? 'Non défini'} FCFA',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailsVentePage(venteId: venteId, vente: vente),
                      ),
                    );
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
