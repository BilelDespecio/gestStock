import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/magaziner/detail_commande.dart';
import 'package:gest_stock/newVersion/magaziner/valider_commande.dart';

class GestionCommandesPage extends StatefulWidget {
  @override
  _GestionCommandesPageState createState() => _GestionCommandesPageState();
}

class _GestionCommandesPageState extends State<GestionCommandesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gérer les Commandes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'En Cours'),
            Tab(text: 'Validées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CommandesList(status: 'en cours'),
          CommandesList(status: 'validée'),
        ],
      ),
    );
  }
}

class CommandesList extends StatelessWidget {
  final String status;

  CommandesList({required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('commandes')
          .where('statut', isEqualTo: status)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Aucune commande $status'));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            return ListTile(
              title: Text('Commande: ${doc.id}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nombre d\'articles: ${doc['totalArticles']}'),
                  Text('Date: ${_formatDate(doc['date'])}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.info_outline),
                    onPressed: () {
                      // Définir les variables conditionnelles en fonction du statut
                      double? fraisAnnexes = (status == 'validée')
                          ? doc['fraisAnnexes']?.toDouble()
                          : null;
                      double? totalQuantite = (status == 'validée')
                          ? doc['totalArticles']?.toDouble()
                          : null;
                      double? prixRevientTotal = (status == 'validée')
                          ? doc['prixRevientTotal']?.toDouble()
                          : null;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsCommandePage(
                            commandId: doc.id,
                            articles: doc['articles'],
                            date: doc['date'],
                            statut: doc['statut'],
                            fraisAnnexes:
                                fraisAnnexes ?? 0.0, // Utiliser 0.0 si null
                            totalQuantite:
                                totalQuantite ?? 0.0, // Utiliser 0.0 si null
                            prixRevientTotal:
                                prixRevientTotal ?? 0.0, // Utiliser 0.0 si null
                          ),
                        ),
                      );
                    },
                  ),
                  if (status == 'en cours')
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ValiderCommandePage(
                              commandId: doc.id,
                              articles: doc['articles'],
                            ),
                          ),
                        );
                      },
                      child: Text('Valider'),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
