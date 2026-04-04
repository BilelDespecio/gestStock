import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gest_stock/newVersion/menu/theme_controller.dart';
import 'package:gest_stock/newVersion/vendeur/constants.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/header_section.dart';
import 'package:gest_stock/newVersion/caisier/pdf_service.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class StatistiquesPage extends StatefulWidget {
  @override
  _StatistiquesPageState createState() => _StatistiquesPageState();
}

class _StatistiquesPageState extends State<StatistiquesPage> {
  final PdfService _pdfService = PdfService();
  String _selectedFilter = 'Mois';
  bool _isDataLoading = true;

  // Compteurs généraux
  int _totalProduits = 0;
  int _totalNbrCommande = 0;
  int _totalNbrVenteValid = 0;
  double _totalVentesValid = 0.0;

  // Stocks Alertes (Magasin)
  int _magasinCritique = 0;
  int _magasinAlerte = 0;

  // Stocks Alertes (Boutique)
  int _boutiqueCritique = 0;
  int _boutiqueAlerte = 0;

  // Graphique
  List<FlSpot> _salesData = [];

  // Taux de conversion (NGN_XOF)
  final TextEditingController _tauxController = TextEditingController();
  bool _isTauxLoading = false;

  // Constante pour le statut des ventes
  static const String STATUS_VALIDE = "validé";

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchTauxConversion();
  }

  /// Fonction principale de récupération des données
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isDataLoading = true);

    try {
      await Future.wait([
        _fetchProduitsAndStocks(),
        _fetchCommandesStats(),
        _fetchValidatedSalesStats(),
      ]);
    } catch (e) {
      debugPrint("Erreur Globale Stats: $e");
    } finally {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  /// 1. Logique des produits et des alertes de stock (Magasin & Boutique)
  Future<void> _fetchProduitsAndStocks() async {
    try {
      // Récupération parallèle des 3 collections
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('produits').get(),
        FirebaseFirestore.instance.collection('stock').get(),
        FirebaseFirestore.instance.collection('stockBoutique').get(),
      ]);

      final produitsDocs = results[0].docs;
      final stockDocs = results[1].docs;
      final stockBoutiqueDocs = results[2].docs;

      // Mapping par nom (normalisé) pour une recherche rapide
      final Map<String, int> magasinStockMap = {
        for (var doc in stockDocs)
          doc['nom'].toString().trim().toLowerCase():
              (doc['quantiteDisponible'] ?? 0) as int
      };

      final Map<String, int> boutiqueStockMap = {
        for (var doc in stockBoutiqueDocs)
          doc['nom'].toString().trim().toLowerCase():
              (doc['quantiteDisponible'] ?? 0) as int
      };

      int magCritique = 0;
      int magAlerte = 0;
      int boutCritique = 0;
      int boutAlerte = 0;

      for (var prodDoc in produitsDocs) {
        final data = prodDoc.data() as Map<String, dynamic>;
        final String nom = data['nom'].toString().trim().toLowerCase();
        final int seuilCritique = data['seuil_critique'] ?? 0;
        final int seuilAlerte = data['seuil_alerte'] ?? 0;

        // --- Comparaison Magasin ---
        final int qteMagasin = magasinStockMap[nom] ?? 0;
        if (qteMagasin <= seuilCritique) {
          magCritique++;
        } else if (qteMagasin <= seuilAlerte) {
          magAlerte++;
        }

        // --- Comparaison Boutique ---
        final int qteBoutique = boutiqueStockMap[nom] ?? 0;
        if (qteBoutique <= seuilCritique) {
          boutCritique++;
        } else if (qteBoutique <= seuilAlerte) {
          boutAlerte++;
        }
      }

      if (mounted) {
        setState(() {
          _totalProduits = produitsDocs.length;
          _magasinCritique = magCritique;
          _magasinAlerte = magAlerte;
          _boutiqueCritique = boutCritique;
          _boutiqueAlerte = boutAlerte;
        });
      }
    } catch (e) {
      debugPrint("Erreur Produits/Stocks: $e");
    }
  }

  /// 2. Statistiques des Commandes
  Future<void> _fetchCommandesStats() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('commandes').get();
      if (mounted) {
        setState(() => _totalNbrCommande = snapshot.docs.length);
      }
    } catch (e) {
      debugPrint("Erreur Commandes: $e");
    }
  }

  /// 3. Statistiques des Ventes Validées & Graphique
  Future<void> _fetchValidatedSalesStats() async {
    try {
      DateTime now = DateTime.now();
      DateTime start;

      final allVentes =
          await FirebaseFirestore.instance.collection('ventes').limit(5).get();
      for (var doc in allVentes.docs) {
        debugPrint("Doc vente ${doc.id} -> statut = ${doc.data()['statut']}");
        debugPrint("VENTE ${doc.id} => ${doc.data()}");
      }

      // Définition de la période selon le filtre
      if (_selectedFilter == 'Jour') {
        start = DateTime(now.year, now.month, now.day);
      } else if (_selectedFilter == 'Mois') {
        start = DateTime(now.year, now.month, 1);
      } else {
        start = DateTime(now.year, 1, 1);
      }

      // ⚠️ Note : Nécessite un index composite (statut, date)
      final ventesQuery = await FirebaseFirestore.instance
          .collection('ventes')
          .where('statut', isEqualTo: STATUS_VALIDE)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('date', descending: false)
          .get();

      double totalCA = 0.0;
      Map<int, double> aggregatedData = {};

      for (var doc in ventesQuery.docs) {
        final data = doc.data();
        double montant = (data['montantTotal'] ?? 0).toDouble();
        totalCA += montant;

        DateTime date = (data['date'] as Timestamp).toDate();
        int key;

        // Clé d'agrégation pour le graphique
        if (_selectedFilter == 'Jour') {
          key = date.hour; // 0-23
        } else if (_selectedFilter == 'Mois') {
          key = date.day; // 1-31
        } else {
          key = date.month; // 1-12
        }

        aggregatedData[key] = (aggregatedData[key] ?? 0) + montant;
      }

      // Préparation des points du graphique
      List<FlSpot> spots = [];
      aggregatedData.forEach((key, value) {
        spots.add(FlSpot(key.toDouble(), value));
      });
      spots.sort((a, b) => a.x.compareTo(b.x));

      if (spots.isEmpty) spots.add(const FlSpot(0, 0));

      if (mounted) {
        setState(() {
          _totalNbrVenteValid = ventesQuery.docs.length;
          _totalVentesValid = totalCA;
          _salesData = spots;
        });
      }
    } catch (e) {
      debugPrint("Erreur Ventes/Graphique: $e");
    }
  }

  Future<void> _fetchTauxConversion() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('taux_conversion')
          .doc('NGN_XOF')
          .get();
      if (doc.exists && mounted) {
        _tauxController.text = doc['NGN_XOF'].toString();
      }
    } catch (e) {
      debugPrint("Erreur Taux: $e");
    }
  }

  Future<void> _updateTauxConversion() async {
    if (_tauxController.text.isEmpty) return;
    setState(() => _isTauxLoading = true);
    try {
      double newTaux = double.tryParse(_tauxController.text) ?? 0.0;
      await FirebaseFirestore.instance
          .collection('taux_conversion')
          .doc('NGN_XOF')
          .set({'NGN_XOF': newTaux});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(
            content: Text("Taux mis à jour !"),
            backgroundColor: AppColors.priceColor));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(
            content: Text("Erreur de mise à jour"),
            backgroundColor: AppColors.criticalColor));
    } finally {
      if (mounted) setState(() => _isTauxLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    final file = await _pdfService.genererRapportStatistiques(
      periode: _selectedFilter,
      totalProduits: _totalProduits,
      stockCritique: _magasinCritique + _boutiqueCritique,
      stockAlerte: _magasinAlerte + _boutiqueAlerte,
      totalNbrVente: _totalNbrVenteValid,
      totalNbrCommande: _totalNbrCommande,
      totalVentes: _totalVentesValid,
      tauxNGN: _tauxController.text,
    );

    if (file != null) {
      await Printing.layoutPdf(
          onLayout: (format) async => file.readAsBytesSync());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          body: SafeArea(
            child: _isDataLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.accentColor))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
                          _buildOverviewGrid(),
                          const SizedBox(height: 24),
                          _buildRevenueCard(),
                          const SizedBox(height: 32),
                          _buildStockSection(
                            title: "Stock Magasin",
                            critique: _magasinCritique,
                            alerte: _magasinAlerte,
                            headerIcon: Icons.warehouse_rounded,
                          ),
                          const SizedBox(height: 24),
                          _buildStockSection(
                            title: "Stock Boutique",
                            critique: _boutiqueCritique,
                            alerte: _boutiqueAlerte,
                            headerIcon: Icons.storefront_rounded,
                            accentColor: Colors.teal,
                          ),
                          const SizedBox(height: 32),
                          _buildSalesChart(),
                          const SizedBox(height: 24),
                          _buildConfigCard(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeaderSection(
          title: 'Dashboard Admin',
          subtitle: 'Analyse des performances réelles',
          actions: [
            HeaderAction(
              icon: Icons.picture_as_pdf_outlined,
              onPressed: _exportPdf,
              color: AppColors.criticalColor,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Période d\'analyse',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.primaryTextColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentColor),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedFilter = val);
                      _fetchData();
                    }
                  },
                  items: ['Jour', 'Mois', 'Année']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Grille des 3 indicateurs principaux
  Widget _buildOverviewGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _buildStatCard('Produits', '$_totalProduits', Icons.inventory_2_rounded,
            AppColors.accentColor),
        _buildStatCard('Commandes', '$_totalNbrCommande',
            Icons.local_shipping_rounded, Colors.indigo),
        _buildStatCard('Ventes', '$_totalNbrVenteValid', Icons.verified_rounded,
            AppColors.priceColor),
      ],
    );
  }

  /// Carte Premium pour le Chiffre d'Affaires
  Widget _buildRevenueCard() {
    final currencyFormat = NumberFormat('#,###', 'fr_FR');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentColor, AppColors.accentColor.withBlue(255)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.accentColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white.withOpacity(0.15), size: 100),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chiffre d\'Affaires Validé',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currencyFormat.format(_totalVentesValid),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  const Text('FCFA',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  "Période : $_selectedFilter",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section des alertes de stock (Magasin ou Boutique)
  Widget _buildStockSection({
    required String title,
    required int critique,
    required int alerte,
    required IconData headerIcon,
    Color? accentColor,
  }) {
    final Color effectiveAccentColor = accentColor ?? AppColors.accentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(headerIcon, color: effectiveAccentColor, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style:  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSmallStatCard(
                'Critique',
                '$critique',
                Icons.warning_amber_rounded,
                AppColors.criticalColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallStatCard(
                'À surveiller',
                '$alerte',
                Icons.notification_important_rounded,
                AppColors.alertColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Graphique FL Chart
  Widget _buildSalesChart() {
    String xLabel;
    if (_selectedFilter == 'Jour') {
      xLabel = "Heures (0h - 23h)";
    } else if (_selectedFilter == 'Mois') {
      xLabel = "Jours (1 - 31)";
    } else {
      xLabel = "Mois (1 - 12)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Évolution des Ventes (Validées)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(xLabel,
            style:  TextStyle(
                color: AppColors.secondaryTextColor, fontSize: 12)),
        const SizedBox(height: 20),
        Container(
          height: 280,
          padding: const EdgeInsets.fromLTRB(10, 24, 24, 12),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval:
                    _totalVentesValid > 0 ? _totalVentesValid / 5 : 1000,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 &&
                          _salesData.length > 1 &&
                          _salesData.first.x != 0) return const SizedBox();
                      return Text(
                        value.toInt().toString(),
                        style:  TextStyle(
                            fontSize: 10,
                            color: AppColors.secondaryTextColor,
                            fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox();
                      return Text(
                        NumberFormat.compact().format(value),
                        style:  TextStyle(
                            fontSize: 10, color: AppColors.secondaryTextColor),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _salesData,
                  isCurved: true,
                  color: AppColors.accentColor,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: AppColors.accentColor,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentColor.withOpacity(0.2),
                        AppColors.accentColor.withOpacity(0.0)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => AppColors.primaryTextColor,
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      return LineTooltipItem(
                        '${NumberFormat('#,###').format(barSpot.y)} FCFA',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Carte statistique standard de la grille
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(value,
              style:  TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryTextColor)),
          Text(title,
              style:  TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryTextColor,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Petite carte pour les alertes de stock
  Widget _buildSmallStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: color)),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.7))),
            ],
          ),
          Icon(icon, color: color.withOpacity(0.4), size: 28),
        ],
      ),
    );
  }

  /// Carte de configuration du taux
  Widget _buildConfigCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accentColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child:  Icon(Icons.currency_exchange_rounded,
                color: AppColors.accentColor),
          ),
          const SizedBox(width: 16),
           Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Taux NGN → XOF',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryTextColor,
                        fontWeight: FontWeight.bold)),
                Text('Conversion automatique',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _tauxController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style:  TextStyle(
                  fontWeight: FontWeight.w900, color: AppColors.accentColor),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isTauxLoading ? null : _updateTauxConversion,
            icon: _isTauxLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                :  Icon(Icons.check_circle_rounded,
                    color: AppColors.priceColor, size: 28),
          )
        ],
      ),
    );
  }
}
