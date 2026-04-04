import 'package:flutter/material.dart';
import 'dart:async';
import 'package:gest_stock/newVersion/caisier/homeCaisier.dart';
import 'package:gest_stock/newVersion/contact/contact_list_page.dart';
import 'package:gest_stock/newVersion/detailProduct.dart';
import 'package:gest_stock/newVersion/vendeur/historique.dart';
import 'package:gest_stock/newVersion/vendeur/updateImageUrl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gest_stock/newVersion/menu/app_menu_sheet.dart';

// --- Imports des widgets, constantes et services ---
import 'constants.dart';
import 'widgets/header_section.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/search_bar_section.dart';
import 'widgets/product_grid.dart';
import 'services/produit_service.dart';

class HomePageVendeur extends StatefulWidget {
  @override
  _HomePageVendeurState createState() => _HomePageVendeurState();
}

class _HomePageVendeurState extends State<HomePageVendeur> {
  final ProduitService _produitService = ProduitService();
  
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  TextEditingController _searchController = TextEditingController();
  StreamSubscription? _productsSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    _productsSubscription?.cancel();
    _productsSubscription = _produitService.getProductsStream().listen((products) {
      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = List.from(_allProducts);
          _isLoading = false;
        });
      }
    });
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_allProducts);
      } else {
        _filteredProducts = _allProducts
            .where((product) =>
                product['nom'].toString().toLowerCase().contains(query.toLowerCase()) ||
                product['gamme'].toString().toLowerCase().contains(query.toLowerCase()) ||
                product['type'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
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
              if (barcode.barcodes.isNotEmpty &&
                  barcode.barcodes.first.rawValue != null) {
                String scannedCode = barcode.barcodes.first.rawValue!;
                print("Code-barres détecté : $scannedCode");

                setState(() {
                  _filteredProducts = _allProducts
                      .where((product) => product['code_barre'] == scannedCode)
                      .toList();
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
        child: _isLoading 
            ? Center(child: CircularProgressIndicator(color: AppColors.accentColor))
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        HeaderSection(
                          title: 'Vendeur',
                          subtitle: 'Gérez vos ventes facilement',
                          actions: [
                            HeaderAction(
                              icon: Icons.payments_outlined, 
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AccueilCaissierPage())),
                              color: AppColors.priceColor
                            ),
                            HeaderAction(
                              icon: Icons.contacts_outlined, 
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ContactsListPage()))
                            ),
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
                              title: 'Vente', 
                              icon: Icons.add_shopping_cart, 
                              onTap: () => Navigator.pushNamed(context, '/vente'),
                              color: AppColors.priceColor
                            ),
                            QuickActionData(
                              title: 'Historique', 
                              icon: Icons.history, 
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HistoriquePage()))
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Produits',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor),
                        ),
                        const SizedBox(height: 16),

                        SearchBarSection(
                          controller: _searchController,
                          onChanged: _filterProducts,
                          onScanPressed: _scanBarcode,
                        ),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverProductGrid(
                      products: _filteredProducts,
                      onProductTap: (produit) => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DetailProduitPage(produit: produit)),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }
}
