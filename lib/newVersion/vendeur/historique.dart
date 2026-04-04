import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

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
      if (mounted) {
        setState(() {
          _userId = user.uid;
          _userRole = userDoc.data()?['role']; // 'admin' ou 'vendeur' etc.
        });
      }
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
            colorScheme:  ColorScheme.light(
              primary: AppColors.accentColor,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return  Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentColor)),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.cardColor,
          iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
          title:  Text('Historique des ventes', style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold)),
          elevation: 1,
          actions: [
            IconButton(
              icon: Icon(Icons.calendar_today_outlined, color: _selectedDate != null ? AppColors.accentColor : AppColors.secondaryTextColor),
              onPressed: () => _selectDate(context),
              tooltip: 'Filtrer par date',
            ),
            if (_selectedDate != null)
              IconButton(
                icon:  Icon(Icons.clear, color: AppColors.criticalColor),
                onPressed: () => setState(() => _selectedDate = null),
                tooltip: 'Supprimer le filtre',
              ),
          ],
          bottom:  TabBar(
            labelColor: AppColors.accentColor,
            unselectedLabelColor: AppColors.secondaryTextColor,
            indicatorColor: AppColors.accentColor,
            indicatorWeight: 3,
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
    Query baseQuery = _firestore.collection('ventes')
        .where('statut', isEqualTo: statut)
        .orderBy('date', descending: true);

    if (_userRole != 'admin' && _userId != null) {
      baseQuery = baseQuery.where('vendeurId', isEqualTo: _userId);
    }

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
          return  Center(child: CircularProgressIndicator(color: AppColors.accentColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}', style:  TextStyle(color: AppColors.criticalColor)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 64, color: AppColors.secondaryTextColor.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  _selectedDate != null
                      ? 'Aucune vente $statut le ${_dateFormat.format(_selectedDate!)}'
                      : 'Aucune vente $statut',
                  style:  TextStyle(fontSize: 16, color: AppColors.secondaryTextColor),
                ),
                if (_selectedDate != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedDate = null),
                    icon:  Icon(Icons.refresh, color: AppColors.accentColor),
                    label:  Text('Réinitialiser le filtre', style: TextStyle(color: AppColors.accentColor)),
                  ),
              ],
            ),
          );
        }

        final ventes = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: ventes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = ventes[index].data() as Map<String, dynamic>;
            final date = data['date']?.toDate();
            final num total = data['montantTotal'] ?? 0;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  'Vente #${data['id']}',
                  style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTextColor),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${total.toStringAsFixed(0)} FCFA', 
                      style:  TextStyle(fontWeight: FontWeight.w600, color: AppColors.priceColor)
                    ),
                    if (date != null) Text(_dateFormat.format(date), style: TextStyle(fontSize: 12, color: AppColors.secondaryTextColor)),
                    if (_userRole == 'admin' && data['vendeurNom'] != null)
                      Text('Vendeur: ${data['vendeurNom']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
                trailing: Container(
                  decoration:  BoxDecoration(color: AppColors.backgroundColor, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(8),
                  child:  Icon(Icons.chevron_right, color: AppColors.accentColor),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VenteDetailPage(data: data)),
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
    final num total = data['montantTotal'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title:  Text('Détails de la vente', style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardColor,
        iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumé Box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItem('ID Transaction', data['id']?.toString() ?? ''),
                  const Divider(height: 24, color: Colors.black12),
                  _buildDetailItem('Statut', data['statut']?.toString() ?? ''),
                  const Divider(height: 24, color: Colors.black12),
                  _buildDetailItem('Montant Total', '${total.toStringAsFixed(0)} FCFA', isHighlight: true),
                  const Divider(height: 24, color: Colors.black12),
                  if (date != null) _buildDetailItem('Date', _dateFormat.format(date)),
                  if (data['vendeurNom'] != null) ...[
                    const Divider(height: 24, color: Colors.black12),
                    _buildDetailItem('Vendeur', data['vendeurNom']),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 32),

             Text(
              'Articles achetés:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor),
            ),
            const SizedBox(height: 12),

            ...articles.map((article) {
              final num pTotal = article['prixTotal'] ?? 0;
              final num pUnit = article['prixUnitaire'] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(article['nom']?.toString() ?? 'Article', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${article['quantite']} x ${pUnit.toStringAsFixed(0)} FCFA', style:  TextStyle(color: AppColors.secondaryTextColor)),
                  trailing: Text(
                    '${pTotal.toStringAsFixed(0)} FCFA',
                    style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.priceColor, fontSize: 16),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:  TextStyle(fontSize: 13, color: AppColors.secondaryTextColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 20 : 16,
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
            color: isHighlight ? AppColors.priceColor : AppColors.primaryTextColor,
          ),
        ),
      ],
    );
  }
}