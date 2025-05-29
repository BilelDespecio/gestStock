import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/detailProduct.dart';
import 'package:gest_stock/newVersion/magaziner/addStockShop.dart';
import 'package:gest_stock/newVersion/magaziner/updateStockPvp.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomePageMagazinier extends StatefulWidget {
  @override
  _HomePageMagazinierState createState() => _HomePageMagazinierState();
}

class _HomePageMagazinierState extends State<HomePageMagazinier> {
  late Future<int> _productCountFuture;
  late Stream<List<Map<String, dynamic>>> _productsStream;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<int> _getProductCount() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('produits').get();
    return snapshot.size;
  }

  Future<int> _getApprovisionnementCount() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('commandes').get();
    return snapshot.size;
  }

  Future<int> _getDestockageCount() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('destockages').get();
    return snapshot.size;
  }

  void _loadData() {
    _getProductsStream().listen((products) {
      setState(() {
        _allProducts = products;
        _filteredProducts =
            List.from(_allProducts); // Initialiser avec tous les produits
      });
    });
  }

  Stream<List<Map<String, dynamic>>> _getProductsStream() {
    return FirebaseFirestore.instance
        .collection('produits')
        .snapshots()
        .asyncMap((produitSnapshot) async {
      final stockSnapshot =
          await FirebaseFirestore.instance.collection('stock').get();

      Map<String, dynamic> stockMap = {
        for (var stock in stockSnapshot.docs) stock['nom']: stock.data()
      };

      List<Map<String, dynamic>> products = produitSnapshot.docs.map((prodDoc) {
        var produitData = prodDoc.data();
        String produitNom = produitData['nom'];

        var stockData = stockMap[produitNom];
        int quantiteDisponible = stockData?['quantiteDisponible'] ?? 0;
        double prixVente = stockData?['pvp']?.toDouble() ?? 0.0;

        return {
          'id': prodDoc.id,
          'gamme': produitData['gamme'],
          'nom': produitNom,
          'prixVente': prixVente,
          'quantiteDisponible': quantiteDisponible,
          'image': produitData['imageUrl'] ?? '',
          'seuil_critique': produitData['seuil_critique'] ?? 0,
          'seuil_alerte': produitData['seuil_alerte'] ?? 0,
          'code_barre': produitData['code_barre'] ?? '',
          'type': produitData['type'] ?? '',
          'poids': produitData['poids'] ?? 0,
          'description': produitData['description'] ?? '',
          'prixDecide': produitData['prixDecide'] ?? null,
          'poidsProduit': produitData['quantite'] ?? null,
          'unite': produitData['unite'] ?? '',
        };
      }).toList();

      return products;
    });
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_allProducts);
      } else {
        _filteredProducts = _allProducts
            .where((product) =>
                product['nom'].toLowerCase().contains(query.toLowerCase()) ||
                product['gamme'].toLowerCase().contains(query.toLowerCase()) ||
                product['type'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _scanBarcode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Scanner un Code-Barres"),
        content: SizedBox(
          height: 300,
          child: MobileScanner(
            onDetect: (barcode) {
              if (barcode.barcodes.isNotEmpty &&
                  barcode.barcodes.first.rawValue != null) {
                String scannedCode = barcode.barcodes.first.rawValue!;
                print("Code-barres détecté : $scannedCode");

                setState(() {
                  _filteredProducts = _allProducts
                      .where((product) => product['code_barre'] == scannedCode)
                      .toList();
                });

                Navigator.pop(context); // Ferme le scanner après détection
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil Magasinier'),
        backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: () {
              // Logique pour rediriger sur chager stockBoutique
              Navigator.pushNamed(context, '/chargerBoutique');
            },
          ),
          IconButton(
            icon: const Icon(Icons.update),
            onPressed: () async {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminToolsPage()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            /*const Text(
              'Statistiques',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),*/
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
                      title: 'Entrées',
                      value: approvisionnementCount.toString(),
                      color: Colors.green,
                    ),
                    _StatCard(
                      title: 'Sorties',
                      value: destockageCount.toString(),
                      color: Colors.red,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/orderForm');
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_shopping_cart,
                          size: 20,
                          color: Colors.white,
                        ), // Icône de panier
                        const SizedBox(height: 2),
                        const Text('Commande', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/gererCommandes');
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.list,
                          size: 20,
                          color: Colors.white,
                        ), // Icône de liste
                        const SizedBox(height: 2),
                        const Text('Gérer', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/ventesValidees');
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Colors.white,
                        ), // Icône de validation
                        const SizedBox(height: 2),
                        const Text('Validées', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/ventesEffectuees');
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store,
                          size: 20,
                          color: Colors.white,
                        ), // Icône de boutique
                        const SizedBox(height: 2),
                        const Text('Stock', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/addProduct');
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store,
                          size: 20,
                          color: Colors.white,
                        ), // Icône de boutique
                        const SizedBox(height: 2),
                        const Text('Produit', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            /*const Text(
              'Produits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),*/
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, // Fond gris clair
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        border: InputBorder.none,
                        prefixIcon:
                            Icon(Icons.search, color: Colors.blueAccent),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      ),
                      onChanged: _filterProducts,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent, // Couleur du bouton QR
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.qr_code_scanner,
                        color: Colors.white, size: 28),
                    onPressed: _scanBarcode,
                    tooltip: "Scanner un QR Code",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(child: Text('Aucun produit trouvé.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(8.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10.0,
                        mainAxisSpacing: 10.0,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final produit = _filteredProducts[index];
                        final id = produit['id'];
                        final int quantite = produit['quantiteDisponible'];
                        final double prix = produit['prixVente'];
                        final String imageUrl = produit['image'] ?? '';
                        print(
                            'URL de l\'image : $imageUrl'); // Vérifier la valeur de l'URL
                        final int seuilCritique = produit['seuil_critique'];
                        final int seuilAlerte = produit['seuil_alerte'];
                        // Vérifier si prixDecide est null ou non défini
                        final int? prixDecide = produit['prixDecide'] != null
                            ? (produit['prixDecide'])
                            : null;


                        final String? newPoids = produit['poidsProduit'] != null
                            ? ('${produit['poidsProduit'].toInt()} ${produit['unite']}')
                            : null;

                        // Déterminer le message et la couleur du ruban
                        String? rubanText;
                        Color rubanColor = Colors.transparent;
                        if (quantite <= seuilCritique) {
                          rubanText = "Stock Critique";
                          rubanColor = Colors.red;
                        } else if (quantite <= seuilAlerte) {
                          rubanText = "Stock Alerte";
                          rubanColor = Colors.orange;
                        }

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailProduitPage(produit: produit),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                elevation: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (imageUrl.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                          topRight: Radius.circular(10),
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Center(
                                                  child:
                                                      CircularProgressIndicator()),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                  Icons.image_not_supported,
                                                  size: 120),
                                        ),
                                      )
                                    else
                                      Container(
                                        height: 100,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(Icons.image,
                                              size: 60, color: Colors.grey),
                                        ),
                                      ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(5, 0, 5, 0),
                                      child: Text(
                                        produit['gamme'] ?? 'Nom inconnu',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(5, 0, 5, 0),
                                      child: Text(
                                        produit['nom'] ?? 'Nom inconnu',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              5, 0, 5, 0),
                                          child: Text(
                                            produit['type'] ?? 'Type',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              5, 0, 5, 0),
                                          child: Text(
                                            newPoids?.toString() ??
                                                produit['poids'],
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5.0),
                                      child: Text(
                                        'Prix: ${prixDecide?.toInt() ?? prix.toInt()} FCFA', // Affiche prixDecide si dispo, sinon pvp
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.green),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5.0),
                                      child: Text(
                                        'Quantité Stock: $quantite',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (rubanText != null)
                                Positioned(
                                  right: 4,
                                  top: 5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: rubanColor,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(10),
                                        topRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      rubanText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ), //ligne 387
                                    ),
                                  ),
                                ),
                            ],
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
