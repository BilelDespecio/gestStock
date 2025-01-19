import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<int> _productCountFuture;
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Fonction pour charger les données
  void _loadData() {
    _productCountFuture = _getProductCount();
    _productsFuture = _getProducts();
  }

  Future<int> _getProductCount() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('produits').get();
    return snapshot.size;
  }

  Future<List<Map<String, dynamic>>> _getProducts() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('produits').get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  Future<int> _getApprovisionnementCount() async {
  final snapshot = await FirebaseFirestore.instance.collection('approvisionnements').get();
  return snapshot.size;
}

Future<int> _getDestockageCount() async {
  final snapshot = await FirebaseFirestore.instance.collection('destockages').get();
  return snapshot.size;
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadData(); // Recharge les données
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Données rechargées avec succès')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /*const Text(
              'Actions rapides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/approvisionnement');
              },
              icon: const Icon(Icons.add_box),
              label: const Text('Buy'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: MediaQuery.of(context).size.width / 18),
                iconColor: Colors.green
              ),
            ),
            const SizedBox(width: 5),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/destockage');
              },
              icon: const Icon(Icons.remove_circle),
              label: const Text('Sell'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: MediaQuery.of(context).size.width / 18),
                iconColor: Colors.red
              ),
            ),
            const SizedBox(width: 5),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/historique');
              },
              icon: const Icon(Icons.history),
              label: const Text('history'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: MediaQuery.of(context).size.width / 18),
                iconColor: Colors.grey
              ),
            ),
            
              ],
            ),
            const SizedBox(height: 10,),*/
            const Text(
              'Statistiques',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            FutureBuilder(
              future: Future.wait([
                _getProductCount(),
                _getApprovisionnementCount(),
                _getDestockageCount(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Erreur de chargement des données.'));
                }
                final data = snapshot.data as List<int>;
                final productCount = data[0];
                final approvisionnementCount = data[1];
                final destockageCount = data[2];
                        
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatCard(
                      title: 'Produits',
                      value: productCount.toString(),
                      color: Colors.blue,
                    ),
                    _StatCard(
                      title: 'Approvision...',
                      value: approvisionnementCount.toString(),
                      color: Colors.green,
                    ),
                    _StatCard(
                      title: 'Déstockages',
                      value: destockageCount.toString(),
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),
           const SizedBox(height: 10),
const Text(
  'Produits',
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 10),
FutureBuilder<List<Map<String, dynamic>>>(
  future: _productsFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return const Center(
          child: Text('Erreur de chargement des produits.'));
    }
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Center(child: Text('Aucun produit trouvé.'));
    }
    final produits = snapshot.data!;
    return Expanded(
      child: ListView.builder(
        itemCount: produits.length,
        itemBuilder: (context, index) {
          final produit = produits[index];
          final int quantite = produit['quantite'] ?? 0;
          final int seuilCritique = produit['seuil_critique'] ?? 0;
          final int seuilAlerte = produit['seuil_alerte'] ?? 0;

          // Déterminer le message et la couleur du ruban
          String? rubanText;
          Color rubanColor = const Color.fromARGB(0, 107, 86, 86);
          if (quantite <= seuilCritique) {
            rubanText = "Stock Critique";
            rubanColor = Colors.red;
          } else if (quantite <= seuilAlerte) {
            rubanText = "Stock Alerte";
            rubanColor = Colors.orange;
          }

          return Stack(
            children: [
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(produit['nom'] ?? 'Nom inconnu'),
                  subtitle: Text(
                    'Prix : ${produit['prix']} | Quantité : $quantite',
                  ),
                ),
              ),
              if (rubanText != null) // Affiche le ruban uniquement si nécessaire
                Positioned(
                  right: 0,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: rubanColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        topRight: Radius.circular(10)
                      ),
                    ),
                    child: Text(
                      rubanText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  },
),
],
        ),
      ),
    );
  }
}

// Widget pour afficher une statistique
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
