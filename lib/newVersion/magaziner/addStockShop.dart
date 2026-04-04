import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../vendeur/constants.dart';
import '../vendeur/widgets/header_section.dart';

class ChargerBoutiquePage extends StatefulWidget {
  @override
  _ChargerBoutiquePageState createState() => _ChargerBoutiquePageState();
}

class _ChargerBoutiquePageState extends State<ChargerBoutiquePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];
  Map<String, TextEditingController> _quantityControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('stock').get();

      setState(() {
        _products = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final productId = doc.id;

          _quantityControllers[productId] ??= TextEditingController(text: '0');

          return {
            'id': productId,
            'nom': data['nom'] ?? 'Sans nom',
            'gamme': data['gamme'] ?? '',
            'type': data['type'] ?? '',
            'poids': data['poids'] ?? '',
            'quantiteDisponible': data['quantiteDisponible'] ?? 0,
            'imageUrl': data['imageUrl'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erreur lors du chargement des produits'), backgroundColor: AppColors.criticalColor),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _chargerBoutique() async {
    int itemsCount = 0;
    _quantityControllers.forEach((key, controller) {
      if ((int.tryParse(controller.text) ?? 0) > 0) itemsCount++;
    });

    if (itemsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Veuillez entrer une quantité pour au moins un produit'), backgroundColor: AppColors.alertColor),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final stockBoutiqueRef = FirebaseFirestore.instance.collection('stockBoutique');

      for (var product in _products) {
        final productId = product['id'];
        final quantite = int.tryParse(_quantityControllers[productId]!.text) ?? 0;

        if (quantite > 0) {
          if (quantite > product['quantiteDisponible']) {
            throw Exception('Stock insuffisant pour ${product['nom']}');
          }

          final productCopy = Map<String, dynamic>.from(product);
          productCopy['quantite'] = quantite;
          productCopy['dateAjout'] = FieldValue.serverTimestamp();
          productCopy['quantiteDisponible'] = quantite;

          batch.set(stockBoutiqueRef.doc(productId), productCopy);

          final stockRef = FirebaseFirestore.instance.collection('stock').doc(productId);
          batch.update(stockRef, {'quantiteDisponible': FieldValue.increment(-quantite)});
        }
      }

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Boutique chargée avec succès !'), backgroundColor: AppColors.priceColor),
      );

      _quantityControllers.forEach((key, controller) => controller.text = '0');
      _fetchProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: AppColors.criticalColor),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredList = _products.where((p) {
      final name = p['nom'].toString().toLowerCase();
      final gamme = p['gamme'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || gamme.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: HeaderSection(
                title: 'Charger Boutique',
                subtitle: 'Transférez du stock vers le magasin',
                actions: [
                  HeaderAction(icon: Icons.refresh, onPressed: _fetchProducts),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  prefixIcon:  Icon(Icons.search, color: AppColors.accentColor),
                  filled: true,
                  fillColor: AppColors.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _isLoading && _products.isEmpty
                  ?  Center(child: CircularProgressIndicator(color: AppColors.accentColor))
                  : filteredList.isEmpty
                      ?  Center(child: Text('Aucun produit trouvé', style: TextStyle(color: AppColors.secondaryTextColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final product = filteredList[index];
                            return _ProductTransferCard(
                              product: product,
                              controller: _quantityControllers[product['id']]!,
                            );
                          },
                        ),
            ),

            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _chargerBoutique,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading 
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded),
                  SizedBox(width: 12),
                  Text('VALIDER LE CHARGEMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
      ),
    );
  }
}

class _ProductTransferCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final TextEditingController controller;

  const _ProductTransferCard({required this.product, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: product['imageUrl'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(product['imageUrl'], fit: BoxFit.cover),
                  )
                :  Icon(Icons.inventory_2_rounded, color: AppColors.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['nom'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(product['gamme'], style:  TextStyle(fontSize: 12, color: AppColors.secondaryTextColor)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('Stock: ${product['quantiteDisponible']}', style:  TextStyle(fontSize: 11, color: AppColors.accentColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.backgroundColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}