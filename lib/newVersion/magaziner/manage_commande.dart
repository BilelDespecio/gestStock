import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../vendeur/constants.dart';
import '../vendeur/widgets/header_section.dart';
import 'detail_commande.dart';
import 'valider_commande.dart';

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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: HeaderSection(
                title: 'Commandes',
                subtitle: 'Suivi et validation des entrées',
              ),
            ),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.secondaryTextColor,
                tabs: const [
                  Tab(text: 'En Cours'),
                  Tab(text: 'Validées'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  CommandesList(status: 'en cours'),
                  CommandesList(status: 'validée'),
                ],
              ),
            ),
          ],
        ),
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
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return  Center(child: CircularProgressIndicator(color: AppColors.accentColor));
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('Aucune commande ${status}', style:  TextStyle(color: AppColors.secondaryTextColor)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            return _CommandeCard(doc: doc, status: status);
          },
        );
      },
    );
  }
}

class _CommandeCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String status;

  const _CommandeCard({required this.doc, required this.status});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final DateTime date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final String formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(date);
    final bool isEnCours = status == 'en cours';
    final int totalArticles = (data['totalArticles'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isEnCours ? Colors.orange : Colors.green).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEnCours ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
                    color: isEnCours ? Colors.orange : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(formattedDate, style:  TextStyle(color: AppColors.secondaryTextColor, fontSize: 12)),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                     Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.secondaryTextColor),
                    const SizedBox(width: 6),
                    Text('$totalArticles articles', style:  TextStyle(fontSize: 13, color: AppColors.primaryTextColor)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon:  Icon(Icons.visibility_outlined, color: AppColors.accentColor),
                      onPressed: () => _navigateToDetails(context),
                    ),
                    if (isEnCours)
                      const SizedBox(width: 8),
                    if (isEnCours)
                      ElevatedButton(
                        onPressed: () => _navigateToValidation(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('VALIDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final bool isEnCours = status == 'en cours';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isEnCours ? Colors.orange : Colors.green).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isEnCours ? 'EN COURS' : 'VALIDÉE',
        style: TextStyle(
          color: isEnCours ? Colors.orange : Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final bool isValidated = status == 'validée';

    double? fraisAnnexes = isValidated ? (data['fraisAnnexes'] as num?)?.toDouble() : 0.0;
    double? totalQuantite = (data['totalArticles'] as num?)?.toDouble();
    double? prixRevientTotal = isValidated ? (data['prixRevientTotal'] as num?)?.toDouble() : 0.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsCommandePage(
          commandId: doc.id,
          articles: data['articles'] ?? [],
          date: data['date'] ?? Timestamp.now(),
          statut: data['statut'] ?? status,
          fraisAnnexes: fraisAnnexes ?? 0.0,
          totalQuantite: totalQuantite ?? 0.0,
          prixRevientTotal: prixRevientTotal ?? 0.0,
          prixVenteMarche: 0.0,
        ),
      ),
    );
  }

  void _navigateToValidation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ValiderCommandePage(
          commandId: doc.id,
          articles: doc['articles'],
        ),
      ),
    );
  }
}
