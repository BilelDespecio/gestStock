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
      appBar: AppBar(title: Text('Ventes'), backgroundColor: Colors.blue.shade800, centerTitle: true, elevation: 4),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getVentes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final ventes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: ventes.length,
            itemBuilder: (context, index) {
              final vente = ventes[index].data() as Map<String, dynamic>;
              final venteId = ventes[index].id;

              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Vente #$venteId'),
                  subtitle: Text('Montant: ${vente['montantTotal']} FCFA'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetailsVentePage(venteId: venteId, vente: vente),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
