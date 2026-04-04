import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/admin/add_product.dart';
import 'package:gest_stock/newVersion/vendeur/constants.dart';
import 'package:gest_stock/newVersion/zoomImage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DetailProduitPage extends StatefulWidget {
  final Map<String, dynamic> produit;

  const DetailProduitPage({Key? key, required this.produit}) : super(key: key);

  @override
  State<DetailProduitPage> createState() => _DetailProduitPageState();
}

class _DetailProduitPageState extends State<DetailProduitPage> {
  bool _isAuthorized = false;
  late String idProduit;
  late String imageUrl;
  late String nomProduit;
  late dynamic prix;
  late int quantite;
  late int seuilCritique;
  late int seuilAlerte;
  late String description;
  late String type;
  late dynamic poids;
  late String gamme;
  late String unite;
  late String stockStatus;
  late Color stockColor;

  @override
  void initState() {
    super.initState();
    _initData();
    _checkUserRole();
  }

  void _initData() {
    idProduit = widget.produit['id'] ?? '';
    imageUrl = widget.produit['imageUrl'] ?? widget.produit['image'] ?? '';
    nomProduit = widget.produit['nom'] ?? 'Nom inconnu';
    prix = widget.produit['prixDecide'] ?? widget.produit['prixVente']?.toDouble() ?? 0;
    quantite = widget.produit['quantiteDisponible'] ?? widget.produit['quantite'] ?? 0;
    seuilCritique = widget.produit['seuil_critique'] ?? 0;
    seuilAlerte = widget.produit['seuil_alerte'] ?? 0;
    description = widget.produit['description'] ?? "Aucune description extra disponible.";
    if (description.trim().isEmpty) description = "Aucune description extra disponible.";
    type = widget.produit['type'] ?? "Type inconnu";
    poids = widget.produit['poidsProduit'] ?? widget.produit['poids'] ?? 0;
    gamme = widget.produit['gamme'] ?? 'Gamme';
    unite = widget.produit['unite'] ?? '';

    // Gestion du statut du stock
    if (quantite <= seuilCritique && seuilCritique > 0) {
      stockStatus = "Stock Critique";
      stockColor = AppColors.criticalColor;
    } else if (quantite <= seuilAlerte && seuilAlerte > 0) {
      stockStatus = "Stock Alerte";
      stockColor = AppColors.alertColor;
    } else {
      stockStatus = "En stock";
      stockColor = AppColors.priceColor;
    }
  }

  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        String role = userDoc['role'] ?? '';
        setState(() {
          _isAuthorized = role == "admin" || role == "user";
        });
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération du rôle : $e");
    }
  }

  void _confirmerSuppression(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Confirmation de suppression"),
          content: Text("Voulez-vous vraiment supprimer définitivement '$nomProduit' ?\nCette action est irréversible."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Annuler", style: TextStyle(color: AppColors.secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.criticalColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('produits')
                      .doc(idProduit)
                      .delete();
                  if (mounted) {
                    Navigator.of(context).pop(); 
                    Navigator.of(context).pop(); 
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop(); 
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Erreur : $e"), backgroundColor: AppColors.criticalColor),
                    );
                  }
                }
              },
              child: const Text("Supprimer"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  const SizedBox(height: 24),
                  _buildDetailsCard(),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                  const SizedBox(height: 40),
                  _buildAddToCartButton(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320.0,
      pinned: true,
      backgroundColor: AppColors.cardColor,
      elevation: 0,
      iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
      actions: _isAuthorized
          ? [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon:  Icon(Icons.edit_outlined, color: AppColors.accentColor),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AjouterProduitPage(produitId: idProduit),
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon:  Icon(Icons.delete_outline, color: AppColors.criticalColor),
                  onPressed: () => _confirmerSuppression(context),
                ),
              ),
            ]
          : [],
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          onTap: () {
            if (imageUrl.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageZoomPage(imageUrl: imageUrl, tag: nomProduit),
                ),
              );
            }
          },
          child: Hero(
            tag: nomProduit,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 800, // Optimisation pour la page détail (haute qualité mais limitée)
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade100,
                      child:  Center(child: CircularProgressIndicator(color: AppColors.accentColor)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade100,
                      child:  Icon(Icons.image_not_supported, size: 80, color: AppColors.secondaryTextColor),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child:  Icon(Icons.image, size: 80, color: AppColors.secondaryTextColor),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gamme.toUpperCase(),
                    style:  TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nomProduit,
                    style:  TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: stockColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: stockColor.withOpacity(0.5)),
              ),
              child: Text(
                stockStatus,
                style: TextStyle(
                  color: stockColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "${prix is double ? prix.toInt() : prix} FCFA",
          style:  TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.priceColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    String formattedPoids = "-";
    if (poids != null && poids != 0 && poids.toString() != "0") {
      formattedPoids = "${poids is double ? poids.toInt() : poids} ${unite.trim()}";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailColumn(Icons.inventory_2_outlined, "Quantité", "$quantite"),
          Container(height: 40, width: 1, color: Colors.grey.shade200),
          _buildDetailColumn(Icons.category_outlined, "Type", type),
          Container(height: 40, width: 1, color: Colors.grey.shade200),
          _buildDetailColumn(Icons.scale_outlined, "Poids/Vol.", formattedPoids),
        ],
      ),
    );
  }

  Widget _buildDetailColumn(IconData icon, String label, String value) {
    return Flexible(
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondaryTextColor, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style:  TextStyle(fontSize: 12, color: AppColors.secondaryTextColor),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style:  TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          "Description",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTextColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style:  TextStyle(
            fontSize: 15,
            height: 1.6,
            color: AppColors.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAddToCartButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Cette fonctionnalité est en mise à jour"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
        label: const Text(
          "Ajouter au panier",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
