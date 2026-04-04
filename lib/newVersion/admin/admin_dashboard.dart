import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/detailProduct.dart';
import 'package:gest_stock/newVersion/vendeur/constants.dart';
import 'package:gest_stock/newVersion/vendeur/services/produit_service.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/header_section.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/product_grid.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/quick_actions_section.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/search_bar_section.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gest_stock/newVersion/menu/app_menu_sheet.dart';

class HomePageAdmin extends StatefulWidget {
  @override
  _HomePageAdminState createState() => _HomePageAdminState();
}

class _HomePageAdminState extends State<HomePageAdmin> {
  final ProduitService _produitService = ProduitService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
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
                      title: 'Administration',
                      subtitle: 'Supervision globale du système',
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

                    QuickActionsSection(
                      actions: [
                        QuickActionData(
                          title: 'Produit', 
                          icon: Icons.add_shopping_cart_rounded, 
                          onTap: () => Navigator.pushNamed(context, '/addProduct'),
                          color: AppColors.accentColor
                        ),
                        QuickActionData(
                          title: 'Utilisateur', 
                          icon: Icons.person_add_alt_1_outlined, 
                          onTap: () => Navigator.pushNamed(context, '/addAccount'),
                          color: Colors.indigo
                        ),
                        QuickActionData(
                          title: 'Stats', 
                          icon: Icons.analytics_outlined, 
                          onTap: () => Navigator.pushNamed(context, '/stats'),
                          color: AppColors.priceColor
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
                      'Aperçu de l\'Inventaire',
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
                    return SliverToBoxAdapter(
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accentColor)),
                    );
                  }
                  
                  _allProducts = snapshot.data ?? [];
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
