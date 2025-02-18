import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoriquePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Nombre d'onglets
      child: Scaffold(
        appBar: AppBar(
          title: Text('Historique des ventes'),
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'En attente'),
              Tab(text: 'Validées'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildVenteList(context, 'en attente'),
            _buildVenteList(context, 'validé'),
          ],
        ),
      ),
    );
  }

  Widget _buildVenteList(BuildContext context, String statut) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ventes')
          .where('statut', isEqualTo: statut)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'Aucune vente $statut.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          );
        }

        final ventes = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(8.0),
          itemCount: ventes.length,
          itemBuilder: (context, index) {
            final data = ventes[index].data() as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(10),
                title: Text(
                  'Vente ID: ${data['id']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Montant Total: ${data['montantTotal']} FCFA',
                  style: TextStyle(fontSize: 14),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.date_range, size: 18, color: Colors.grey),
                    SizedBox(height: 4),
                    Text(
                      data['date'] != null ? data['date'].toDate().toString().split(' ')[0] : '',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VenteDetailPage(data: data),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class VenteDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  VenteDetailPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Détails de la vente')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${data['id']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Montant Total: ${data['montantTotal']} FCFA', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Statut: ${data['statut']}', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Date: ${data['date']?.toDate().toString().split(' ')[0] ?? ''}', style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            Text('Articles:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: data['articles'].length,
                itemBuilder: (context, index) {
                  final article = data['articles'][index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      title: Text('${article['nom']}', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Quantité: ${article['quantite']} | Prix Unitaire: ${article['prixUnitaire']} FCFA'),
                      trailing: Text('Total: ${article['prixTotal']} FCFA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
