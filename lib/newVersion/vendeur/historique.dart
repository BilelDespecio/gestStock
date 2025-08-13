import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoriquePage extends StatefulWidget {
  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  DateTime? _selectedDate;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userRole;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _userId = user.uid;
        _userRole = userDoc.data()?['role']; // 'admin' ou 'vendeur'
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade800,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historique des ventes'),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context),
              tooltip: 'Filtrer par date',
            ),
            if (_selectedDate != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _selectedDate = null),
                tooltip: 'Supprimer le filtre',
              ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: const [
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
    // Construction de la requête de base selon le rôle
    Query baseQuery = _firestore.collection('ventes')
        .where('statut', isEqualTo: statut)
        .orderBy('date', descending: true);

    // Si l'utilisateur est un vendeur (et non admin), on filtre par son ID
    if (_userRole != 'admin' && _userId != null) {
      baseQuery = baseQuery.where('vendeurId', isEqualTo: _userId);
    }

    // Filtre par date si sélectionnée
    if (_selectedDate != null) {
      final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      baseQuery = baseQuery
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: baseQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedDate != null
                      ? 'Aucune vente $statut pour le ${_dateFormat.format(_selectedDate!)}'
                      : 'Aucune vente $statut',
                  style: const TextStyle(fontSize: 16),
                ),
                if (_selectedDate != null)
                  TextButton(
                    child: const Text('Réinitialiser le filtre'),
                    onPressed: () => setState(() => _selectedDate = null),
                  ),
              ],
            ),
          );
        }

        final ventes = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(8.0),
          itemCount: ventes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = ventes[index].data() as Map<String, dynamic>;
            final date = data['date']?.toDate();

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                title: Text(
                  'Vente #${data['id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: ${data['montantTotal']} FCFA'),
                    if (date != null) Text(_dateFormat.format(date)),
                    if (_userRole == 'admin' && data['vendeurNom'] != null)
                      Text('Vendeur: ${data['vendeurNom']}'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VenteDetailPage(data: data),
                  ),
                ),
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
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy à HH:mm');

  VenteDetailPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = data['date']?.toDate();
    final articles = List<Map<String, dynamic>>.from(data['articles'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la vente'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailItem('ID', data['id']?.toString() ?? ''),
            _buildDetailItem('Statut', data['statut']?.toString() ?? ''),
            _buildDetailItem('Montant Total', '${data['montantTotal']} FCFA'),
            if (date != null) _buildDetailItem('Date', _dateFormat.format(date)),
            if (data['vendeurNom'] != null) _buildDetailItem('Vendeur', data['vendeurNom']),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Articles:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            ...articles.map((article) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(article['nom']?.toString() ?? ''),
                subtitle: Text(
                  '${article['quantite']} x ${article['prixUnitaire']} FCFA',
                ),
                trailing: Text(
                  '${article['prixTotal']} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}