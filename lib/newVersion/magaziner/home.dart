import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/detailProduct.dart';
import 'package:gest_stock/newVersion/vendeur/constants.dart';
import 'package:gest_stock/newVersion/vendeur/services/produit_service.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/header_section.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/product_grid.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/quick_actions_section.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/search_bar_section.dart';
import 'package:gest_stock/newVersion/magaziner/addStockShop.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gest_stock/newVersion/menu/app_menu_sheet.dart';

class HomePageMagazinier extends StatefulWidget {
  @override
  _HomePageMagazinierState createState() => _HomePageMagazinierState();
}

class _HomePageMagazinierState extends State<HomePageMagazinier> {
  final ProduitService _produitService = ProduitService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
  }

  Future<int> _getCount(String collection) async {
    final snapshot = await FirebaseFirestore.instance.collection(collection).get();
    return snapshot.size;
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredProducts = List.from(_allProducts);
      } else {
        _filteredProducts = _allProducts.where((product) {
          return product['nom'].toLowerCase().contains(_searchQuery) ||
                 product['gamme'].toLowerCase().contains(_searchQuery) ||
                 product['type'].toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _scanBarcode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Scanner un Code-Barres"),
        content: SizedBox(
          height: 300,
          child: MobileScanner(
            onDetect: (barcode) {
              if (barcode.barcodes.isNotEmpty && barcode.barcodes.first.rawValue != null) {
                String scannedCode = barcode.barcodes.first.rawValue!;
                setState(() {
                  _searchController.text = scannedCode;
                  _filterProducts(scannedCode);
                });
                Navigator.pop(context);
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
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    HeaderSection(
                      title: 'Espace Magasinier',
                      subtitle: 'Gérez le stock de l\'entrepôt',
                      actions: [
                        HeaderAction(
                          icon: Icons.menu,
                          onPressed: () {
                            showAppMenuSheet(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats Section
                    FutureBuilder(
                      future: Future.wait([
                        _getCount('produits'),
                        _getCount('commandes'),
                        _getCount('destockages'),
                      ]),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox(height: 80);
                        final data = snapshot.data as List<int>;
                        return Row(
                          children: [
                            _StatTile(label: 'Produits', value: '${data[0]}', color: AppColors.accentColor),
                            const SizedBox(width: 12),
                            _StatTile(label: 'Entrées', value: '${data[1]}', color: Colors.green),
                            const SizedBox(width: 12),
                            _StatTile(label: 'Sorties', value: '${data[2]}', color: AppColors.criticalColor),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 24),

                    QuickActionsSection(
                      actions: [
                        QuickActionData(
                          title: 'Commande', 
                          icon: Icons.add_shopping_cart, 
                          onTap: () => Navigator.pushNamed(context, '/orderForm')
                        ),
                        QuickActionData(
                          title: 'Gérer', 
                          icon: Icons.list_alt, 
                          onTap: () => Navigator.pushNamed(context, '/gererCommandes')
                        ),
                        QuickActionData(
                          title: 'Stock', 
                          icon: Icons.inventory_2_outlined, 
                          onTap: () => Navigator.pushNamed(context, '/chargerBoutique')
                        ),
                        QuickActionData(
                          title: 'Produit', 
                          icon: Icons.add_box_outlined, 
                          onTap: () => Navigator.pushNamed(context, '/addProduct')
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SearchBarSection(
                      controller: _searchController, 
                      onChanged: _filterProducts, 
                      onScanPressed: _scanBarcode
                    ),
                    const SizedBox(height: 24),

                    /*const Text(
                      'Inventaire Magasin',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor),
                    ),*/
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _produitService.getProductsStream(isMagasin: true),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return  SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator(color: AppColors.accentColor)),
                    );
                  }
                  
                  _allProducts = snapshot.data ?? [];
                  // Appliquer le filtre actuel
                  if (_searchQuery.isEmpty) {
                    _filteredProducts = List.from(_allProducts);
                  } else {
                    _filteredProducts = _allProducts.where((p) => 
                      p['nom'].toLowerCase().contains(_searchQuery) ||
                      p['gamme'].toLowerCase().contains(_searchQuery)
                    ).toList();
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverProductGrid(
                      products: _filteredProducts, 
                      onProductTap: (product) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DetailProduitPage(produit: product))
                        );
                      }
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style:  TextStyle(fontSize: 11, color: AppColors.secondaryTextColor)),
          ],
        ),
      ),
    );
  }
}
