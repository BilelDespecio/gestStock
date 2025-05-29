import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gest_stock/newVersion/caisier/homeCaisier.dart';
import 'package:gest_stock/newVersion/contact/contact_list_page.dart';
import 'package:gest_stock/newVersion/detailProduct.dart';
import 'package:gest_stock/newVersion/vendeur/historique.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomePageVendeur extends StatefulWidget {
  @override
  _HomePageVendeurState createState() => _HomePageVendeurState();
}

class _HomePageVendeurState extends State<HomePageVendeur> {
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

      final stockBoutiqueSnapshot =
          await FirebaseFirestore.instance.collection('stockBoutique').get();

      Map<String, dynamic> stockBoutiqueMap = {
        for (var stock in stockBoutiqueSnapshot.docs) stock['nom']: stock.data()
      };

      List<Map<String, dynamic>> products = produitSnapshot.docs.map((prodDoc) {
        var produitData = prodDoc.data();
        String produitNom = produitData['nom'];

        var stockData = stockMap[produitNom];
        //int quantiteDisponible = stockData?['quantiteDisponible'] ?? 0;
        double prixVente = stockData?['pvp']?.toDouble() ?? 0.0;

        var stockBoutiqueData = stockBoutiqueMap[produitNom];
        int quantiteBoutique = stockBoutiqueData?['quantite'] ?? 0;

        return {
          'id': prodDoc.id,
          'gamme': produitData['gamme'],
          'nom': produitNom,
          'prixVente': prixVente,
          'quantiteDisponible': quantiteBoutique,
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
        title: const Text('Tableau de bord'),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AccueilCaissierPage()));
              },
              
              icon: Icon(Icons.paid_outlined)),
          IconButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ContactsListPage()));
              },
              icon: Icon(Icons.contact_phone_outlined)),
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
        backgroundColor: Colors.white, // Bleu foncé pour un aspect pro

        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => HistoriquePage()));
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('history'),
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: MediaQuery.of(context).size.width / 18),
                      iconColor: Colors.grey),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/vente');
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Faire une vente'),
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: MediaQuery.of(context).size.width / 18),
                      iconColor: Colors.grey),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Produits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
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
