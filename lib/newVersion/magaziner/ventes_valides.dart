import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/magaziner/details_ventes_page.dart';

class VentesValideesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ventes Validées')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('ventes')
            .where('statut', isEqualTo: 'validé')
            .where('destockage', isEqualTo: false)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement des ventes.'));
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Aucune vente validée trouvée.'));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return Card(
                margin: EdgeInsets.all(10),
                child: ListTile(
                  title: Text('Vente ID: ${doc.id}'),
                  subtitle: Text('Montant: ${doc['montantTotal']} FCFA'),
                  trailing: Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailVentePage(vente: doc),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}



