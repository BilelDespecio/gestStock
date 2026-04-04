import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/vendeur/constants.dart';
import 'package:gest_stock/newVersion/menu/theme_controller.dart';
import 'package:intl/intl.dart';

class DetailsCommandePage extends StatelessWidget {
  final String commandId;
  final List<dynamic> articles;
  final Timestamp date;
  final String statut;
  final double fraisAnnexes;
  final double totalQuantite;
  final double? prixRevientTotal;
  final double? prixVenteMarche;

  DetailsCommandePage({
    required this.commandId,
    required this.articles,
    required this.date,
    required this.statut,
    required this.fraisAnnexes,
    required this.totalQuantite,
    required this.prixRevientTotal,
    required this.prixVenteMarche,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR');
    final bool isValidated = statut.toLowerCase() == 'validée' || statut.toLowerCase() == 'validé';

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          appBar: AppBar(
            title: Text('Commande $commandId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: AppColors.cardColor,
            foregroundColor: AppColors.primaryTextColor,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeaderStat(
                            'Date',
                            dateFormat.format(date.toDate()),
                            Icons.calendar_today_rounded,
                            AppColors.accentColor,
                          ),
                          _buildStatusBadge(statut),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderStat(
                              'Quantité',
                              totalQuantite.toStringAsFixed(0),
                              Icons.inventory_2_rounded,
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildHeaderStat(
                              'Frais Annexes',
                              currencyFormat.format(fraisAnnexes),
                              Icons.account_balance_wallet_rounded,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      if (isValidated && prixRevientTotal != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.priceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.priceColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payments_rounded, color: AppColors.priceColor, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Prix de Revient Total',
                                    style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                currencyFormat.format(prixRevientTotal),
                                style: TextStyle(color: AppColors.priceColor, fontWeight: FontWeight.w900, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 15),
                  child: Text(
                    'ARTICLES COMMANDÉS',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: Colors.grey),
                  ),
                ),

                // Articles List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      final double prixRevient = _convertToDouble(article['prixRevientUnitaire']);
                      final double prixVente = _convertToDouble(article['prixVenteUnitaire']);
                      final int quantite = _convertToInt(article['quantity']);
                      final double pvm = _convertToDouble(article['prixVenteMarche']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.shopping_bag_outlined, color: AppColors.accentColor, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        article['name']?.toString() ?? 'Article Inconnu',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryTextColor),
                                      ),
                                      Text(
                                        'Gamme: ${article['gamme'] ?? 'N/A'} • Type: ${article['type'] ?? 'N/A'}',
                                        style: TextStyle(color: AppColors.secondaryTextColor, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'x$quantite',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            if (isValidated) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                              _buildArticlePriceRow('Prix de revient', prixRevient, currencyFormat, AppColors.secondaryTextColor),
                              const SizedBox(height: 6),
                              _buildArticlePriceRow('Prix de vente', prixVente, currencyFormat, AppColors.priceColor),
                              const SizedBox(height: 6),
                              _buildArticlePriceRow('Prix marché', pvm, currencyFormat, Colors.blue),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.secondaryTextColor, fontSize: 11)),
            Text(value, style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isEnCours = status.toLowerCase() == 'en cours';
    final Color color = isEnCours ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildArticlePriceRow(String label, double price, NumberFormat format, Color? color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          format.format(price),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  double _convertToDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _convertToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
