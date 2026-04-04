import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../vendeur/constants.dart';
import '../vendeur/widgets/header_section.dart';
import 'dropStyle.dart';

class OrderForm extends StatefulWidget {
  @override
  _OrderFormState createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _productNames = [];
  String? _selectedProductId;
  List<Map<String, dynamic>> _items = [];
  int _itemQuantity = 1;
  bool _isLoading = false;
  List<Map<String, dynamic>> _suspendedOrders = [];
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('produits').get();
      final products = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'nom': doc['nom'],
          'code_barre': doc['code_barre'],
          'gamme': doc['gamme'],
          'type': doc['type'],
          'poids': doc['poids'],
          'imageUrl': doc['imageUrl']
        };
      }).toList();

      products.sort((a, b) {
        int gammeCompare = a['gamme'].compareTo(b['gamme']);
        if (gammeCompare != 0) return gammeCompare;
        return a['nom'].compareTo(b['nom']);
      });

      setState(() {
        _productNames = products;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: AppColors.criticalColor),
      );
    }
  }

  void _showProductSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _productNames.where((p) =>
                p['nom'].toLowerCase().contains(_searchQuery) ||
                p['gamme'].toLowerCase().contains(_searchQuery)).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration:  BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setModalState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        prefixIcon:  Icon(Icons.search, color: AppColors.accentColor),
                        filled: true,
                        fillColor: AppColors.cardColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return ListTile(
                          onTap: () {
                            setState(() => _selectedProductId = product['id']);
                            Navigator.pop(context);
                          },
                          leading: Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: product['imageUrl'] != null && product['imageUrl'].isNotEmpty
                                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(product['imageUrl'], fit: BoxFit.cover))
                                :  Icon(Icons.inventory_2_outlined, color: AppColors.accentColor),
                          ),
                          title: Text(product['nom'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(product['gamme'], style:  TextStyle(fontSize: 12, color: AppColors.secondaryTextColor)),
                          trailing: Text(product['type'] ?? '', style:  TextStyle(color: AppColors.accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addItem() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Sélectionnez un produit'), backgroundColor: AppColors.alertColor));
      return;
    }

    final selectedProduct = _productNames.firstWhere((prod) => prod['id'] == _selectedProductId);
    setState(() {
      _items.add({
        'id': '${selectedProduct['gamme']}_${_selectedProductId}',
        'name': selectedProduct['nom'],
        'quantity': _itemQuantity,
        'code_barre': selectedProduct['code_barre'],
        'gamme': selectedProduct['gamme'],
        'type': selectedProduct['type'],
        'poids': selectedProduct['poids'],
      });
      _selectedProductId = null;
      _itemQuantity = 1;
    });
  }

  Future<void> _saveOrderToFirestore() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Ajoutez des articles'), backgroundColor: AppColors.alertColor));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('commandes').get();
      int orderNumber = snapshot.size + 1;
      String formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());
      String orderId = 'CMD-$orderNumber-$formattedDate';

      int totalQuantity = _items.fold(0, (sum, item) => sum + (item['quantity'] as int));

      await FirebaseFirestore.instance.collection('commandes').doc(orderId).set({
        'id': orderId,
        'articles': _items,
        'totalArticles': totalQuantity,
        'date': Timestamp.now(),
        'statut': 'en cours',
      });

      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Commande enregistrée !'), backgroundColor: AppColors.priceColor));
      setState(() => _items.clear());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.criticalColor));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _suspendreCommande() async {
    if (_items.isEmpty) return;
    try {
      String orderId = 'SUSP-${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('commandes').doc(orderId).set({
        'id': orderId,
        'articles': _items,
        'totalArticles': _items.fold(0, (sum, item) => sum + (item['quantity'] as int)),
        'date': Timestamp.now(),
        'statut': 'suspendue',
      });
      setState(() => _items.clear());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande suspendue'), backgroundColor: Colors.orange));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _showSuspendedOrders() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('commandes').where('statut', isEqualTo: 'suspendue').get();
      _suspendedOrders = snapshot.docs.map((doc) => {
        'id': doc.id,
        'articles': List<Map<String, dynamic>>.from(doc['articles']),
        'totalArticles': doc['totalArticles'],
        'date': (doc['date'] as Timestamp).toDate(),
      }).toList();
    } catch (e) {} finally { setState(() => _isLoading = false); }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration:  BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          children: [
            const Text('Commandes suspendues', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: _suspendedOrders.isEmpty 
                  ? const Center(child: Text('Aucune commande suspendue'))
                  : ListView.builder(
                      itemCount: _suspendedOrders.length,
                      itemBuilder: (context, index) {
                        final order = _suspendedOrders[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            title: Text('ID: ${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('Articles: ${order['totalArticles']}', style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.green), onPressed: () {
                              setState(() => _items = List.from(order['articles']));
                              Navigator.pop(context);
                            }),
                          ),
                        );
                      }
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: HeaderSection(
                title: 'Nouvelle Commande',
                subtitle: 'Assemblez les articles pour l\'entrée',
                actions: [
                  HeaderAction(icon: Icons.pause_circle_outline, onPressed: _showSuspendedOrders),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildSelectionForm(),
                    const SizedBox(height: 24),
                    _buildItemList(),
                  ],
                ),
              ),
            ),
            
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.withOpacity(0.05))),
      child: Column(
        children: [
          InkWell(
            onTap: _showProductSelection,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                   Icon(Icons.search, color: AppColors.accentColor),
                  const SizedBox(width: 12),
                  Text(
                    _selectedProductId != null 
                        ? _productNames.firstWhere((p) => p['id'] == _selectedProductId)['nom']
                        : "Choisir un produit...",
                    style: TextStyle(color: _selectedProductId != null ? AppColors.primaryTextColor : AppColors.secondaryTextColor),
                  ),
                  const Spacer(),
                   Icon(Icons.arrow_drop_down, color: AppColors.secondaryTextColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _itemQuantity = int.tryParse(v) ?? 1,
                  decoration: InputDecoration(
                    labelText: 'Quantité',
                    filled: true,
                    fillColor: AppColors.backgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor,
                  minimumSize: const Size(60, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    if (_items.isEmpty) {
      return  Column(
        children: [
          SizedBox(height: 40),
          Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Aucun article ajouté', style: TextStyle(color: AppColors.secondaryTextColor)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Articles sélectionnés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: AppColors.cardColor, borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Gamme: ${item['gamme']} • Qté: ${item['quantity']}', style: const TextStyle(fontSize: 12)),
                trailing: IconButton(icon:  Icon(Icons.delete_outline, color: AppColors.criticalColor), onPressed: () => setState(() => _items.removeAt(index))),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _items.isEmpty ? null : _suspendreCommande,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
                side: const BorderSide(color: Colors.orange),
                foregroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('SUSPENDRE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading || _items.isEmpty ? null : _saveOrderToFirestore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.priceColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('VALIDER LA COMMANDE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
