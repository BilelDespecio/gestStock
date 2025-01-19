import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoriquePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Nombre d'onglets
      child: Scaffold(
        appBar: AppBar(
          title: Text('Historique'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Approvisionnements'),
              Tab(text: 'Déstockages'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Historique des approvisionnements
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('approvisionnements').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Aucun approvisionnement trouvé.'));
                }

                final approvisionnements = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: approvisionnements.length,
                  itemBuilder: (context, index) {
                    final data = approvisionnements[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['produit_id'] ?? 'Produit inconnu'),
                      subtitle: Text(
                        'Quantité : ${data['quantite']} | Fournisseur : ${data['fournisseur']}',
                      ),
                      trailing: Text(
                        data['date'] != null ? data['date'].toDate().toString() : '',
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  },
                );
              },
            ),
            // Historique des déstockages
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('destockages').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Aucun déstockage trouvé.'));
                }

                final destockages = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: destockages.length,
                  itemBuilder: (context, index) {
                    final data = destockages[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['produit_id'] ?? 'Produit inconnu'),
                      subtitle: Text(
                        'Quantité : ${data['quantite']} | Motif : ${data['motif']}',
                      ),
                      trailing: Text(
                        data['date'] != null ? data['date'].toDate().toString() : '',
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
