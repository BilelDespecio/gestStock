import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class StatistiquesPage extends StatefulWidget {
  @override
  _StatistiquesPageState createState() => _StatistiquesPageState();
}

class _StatistiquesPageState extends State<StatistiquesPage> {
  String _selectedFilter = 'Mois'; // Filtre par défaut
  int _totalProduits = 0;
  int _stockCritique = 0;
  int _stockAlerte = 0;
  int _totalNbrVente = 0;
  double _totalVentes = 0.0;
  int _totalNbrCommande = 0;
  List<FlSpot> _salesData = [];
  final TextEditingController _tauxController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData(); // Charger les données au démarrage
    _fetchTauxConversion(); // Charger le taux initial
  }

  Future<void> _fetchData() async {
    try {
      // 🔹 Récupérer le nombre total de produits
      var produitsSnapshot =
          await FirebaseFirestore.instance.collection('stock').get();
      int totalProduits = produitsSnapshot.docs.length;

      // 🔹 Récupérer les produits en stock critique et alerte
      int stockCritique = 0;
      int stockAlerte = 0;
      for (var doc in produitsSnapshot.docs) {
        int stock = doc['quantiteDisponible'];
        if (stock < 50) {
          stockCritique++;
        } else if (stock < 100) {
          stockAlerte++;
        }
      }

      // 🔹 Récupérer les ventes en fonction du filtre sélectionné
      double totalVentes = 0.0;
      List<FlSpot> salesData = [];

      var ventesSnapshot =
          await FirebaseFirestore.instance.collection('ventes').get();
      int totalNbrVente = ventesSnapshot.docs.length;
      for (var doc in ventesSnapshot.docs) {
        Timestamp dateVente = doc['date'];
        double montant = doc['montantTotal'].toDouble();

        DateTime venteDate = dateVente.toDate();
        DateTime now = DateTime.now();

        bool isValid = false;
        if (_selectedFilter == 'Jour' &&
            venteDate.day == now.day &&
            venteDate.month == now.month &&
            venteDate.year == now.year) {
          isValid = true;
        } else if (_selectedFilter == 'Mois' &&
            venteDate.month == now.month &&
            venteDate.year == now.year) {
          isValid = true;
        } else if (_selectedFilter == 'Année' && venteDate.year == now.year) {
          isValid = true;
        }

        if (isValid) {
          totalVentes += montant;
          salesData.add(FlSpot(venteDate.day.toDouble(), montant));
        }
      }

      var commandesSnapshot =
          await FirebaseFirestore.instance.collection('commandes').get();
      int totalNbrCommande = commandesSnapshot.docs.length;

      // Mettre à jour l'état
      setState(() {
        _totalProduits = totalProduits;
        _stockCritique = stockCritique;
        _stockAlerte = stockAlerte;
        _totalVentes = totalVentes;
        _salesData = salesData;
        _totalNbrVente = totalNbrVente;
        _totalNbrCommande = totalNbrCommande;
      });
    } catch (e) {
      print("Erreur lors de la récupération des données: $e");
    }
  }

  /// Récupère le taux de conversion depuis Firestore
  Future<void> _fetchTauxConversion() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('taux_conversion')
          .doc('NGN_XOF')
          .get();

      if (doc.exists) {
        setState(() {
          _tauxController.text = doc['NGN_XOF'].toString();
        });
      }
    } catch (e) {
      print("Erreur de récupération du taux : $e");
    }
  }

  /// Met à jour le taux de conversion dans Firestore
  Future<void> _updateTauxConversion() async {
    setState(() {
      _isLoading = true;
    });

    try {
      double newTaux = double.tryParse(_tauxController.text) ?? 0.0;

      await FirebaseFirestore.instance
          .collection('taux_conversion')
          .doc('NGN_XOF')
          .update({'NGN_XOF': newTaux});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Taux mis à jour avec succès !")),
      );
    } catch (e) {
      print("Erreur de mise à jour : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour")),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: const Color.fromARGB(
            255, 255, 255, 255), // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // 🔹 Filtre de période
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text(
                  "Filtrer par :",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedFilter,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedFilter = newValue;
                        _fetchData(); // Recharger les données avec le nouveau filtre
                      });
                    }
                  },
                  items: <String>['Jour', 'Mois', 'Année']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                SizedBox(width: 50),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: TextFormField(
                      controller: _tauxController,
                      decoration: InputDecoration(
                        labelText: "Taux de conversion NGN → XOF",
                        labelStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                IconButton(
                    onPressed: _isLoading ? null : _updateTauxConversion,
                    icon: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Icon(Icons.update, color: Colors.blueAccent,))
              ],
            ),
            const SizedBox(height: 10),

            // 🔹 Affichage des statistiques

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: _buildStatCard('Total Produits',
                        _totalProduits.toString(), Colors.blue)),
                GestureDetector(
                    onTap: () {},
                    child: _buildStatCard('Stock Critique',
                        _stockCritique.toString(), Colors.red)),
                GestureDetector(
                    onTap: () {},
                    child: _buildStatCard('Stock Alerte',
                        _stockAlerte.toString(), Colors.orange)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/historique');
                    },
                    child: _buildStatCard(
                        'Total ventes', _totalNbrVente.toString(), Colors.red)),
                GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/gererCommandes');
                    },
                    child: _buildStatCard('Total Commandes',
                        _totalNbrCommande.toString(), Colors.orange)),
                GestureDetector(
                    onTap: () {},
                    child: _buildStatCard('Montant Ventes',
                        '${_totalVentes.toInt()} FCFA', Colors.green)),
              ],
            ),

            const SizedBox(height: 10),

            // 🔹 Graphique des ventes
            const Text(
              "Évolution des Ventes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Expanded(child: _buildSalesChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _salesData,
            isCurved: false,
            color: Colors.blue,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true),
          ),
        ],
      ),
    );
  }
}
