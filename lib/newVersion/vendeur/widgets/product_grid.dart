import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants.dart';

class ProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onProductTap;

  const ProductGrid({required this.products, required this.onProductTap});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 50.0),
          child: Text(
            'Aucun produit trouvé.',
            style: TextStyle(color: AppColors.secondaryTextColor, fontSize: 16)
          )
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.68,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final produit = products[index];
        return ProductCard(
          produit: produit, 
          key: ValueKey(produit['id']), 
          onTap: () => onProductTap(produit)
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> produit;
  final VoidCallback onTap;

  const ProductCard({required this.produit, required this.onTap, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int quantite = produit['quantiteDisponible'] ?? 0;
    final double prix = produit['prixVente']?.toDouble() ?? 0.0;
    final String imageUrl = produit['image'] ?? '';
    final int seuilCritique = produit['seuil_critique'] ?? 0;
    final int seuilAlerte = produit['seuil_alerte'] ?? 0;
    final int? prixDecide = produit['prixDecide'];
    final String? newPoids = produit['poidsProduit'] != null
        ? ('${produit['poidsProduit'].toInt()} ${produit['unite']}')
        : null;

    String? rubanText;
    Color rubanColor = Colors.transparent;
    
    if (quantite <= seuilCritique && seuilCritique > 0) {
      rubanText = "Stock Critique";
      rubanColor = AppColors.criticalColor;
    } else if (quantite <= seuilAlerte && seuilAlerte > 0) {
      rubanText = "Stock Alerte";
      rubanColor = AppColors.alertColor;
    }

    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            cacheKey: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.accentColor)),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade100,
                              child: const Icon(Icons.image_not_supported,
                                  color: AppColors.secondaryTextColor, size: 40),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.image,
                                color: AppColors.secondaryTextColor, size: 40),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produit['gamme'] ?? 'Marque',
                        style: const TextStyle(fontSize: 12, color: AppColors.accentColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        produit['nom'] ?? 'Nom inconnu',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${produit['type'] ?? 'Type'} - ${newPoids?.toString() ?? produit['poids']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.secondaryTextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${prixDecide?.toInt() ?? prix.toInt()} FCFA',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.priceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Stock: $quantite',
                            style: const TextStyle(fontSize: 12, color: AppColors.secondaryTextColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (rubanText != null)
            Positioned(
              right: 0,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rubanColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rubanColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2)
                    )
                  ],
                ),
                child: Text(
                  rubanText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
