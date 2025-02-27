import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
class DetailsCommandePage extends StatelessWidget {
  final String commandId;
  final List<dynamic> articles;
  final Timestamp date;
  final String statut;
  final double fraisAnnexes;
  final double totalQuantite;
  final double prixRevientTotal;

  DetailsCommandePage({
    required this.commandId,
    required this.articles,
    required this.date,
    required this.statut,
    required this.fraisAnnexes,
    required this.totalQuantite,
    required this.prixRevientTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Détails de la commande $commandId'), backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID de commande: $commandId', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Date: ${_formatDate(date)}'),
            Text('Statut: $statut'),
            Text('Frais annexes: ${fraisAnnexes.toStringAsFixed(2)} FCFA'),
            Text('Total quantité: ${totalQuantite.toStringAsFixed(2)}'),
            Text('Prix de revient total: ${prixRevientTotal.toStringAsFixed(2)} FCFA'),
            SizedBox(height: 20),
            Text('Articles:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  var article = articles[index];
                  // Conversion des valeurs en double
                  double prixRevient = _convertToDouble(article['prixRevientUnitaire']);
                  double prixVente = _convertToDouble(article['prixVenteUnitaire']);
                  int quantite = _convertToInt(article['quantity']);

                  return ListTile(
                    title: Text(article['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantité: $quantite'),
                        if (statut == 'validée') ...[
                          Text('Prix de revient unitaire: ${prixRevient.toStringAsFixed(2)} FCFA'),
                          Text('Prix de vente unitaire: ${prixVente.toStringAsFixed(2)} FCFA'),
                        ],
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

  // Méthode pour convertir en double de manière sécurisée
  double _convertToDouble(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      // Tentative de conversion de String en double
      final doubleValue = double.tryParse(value);
      return doubleValue ?? 0.0; // Si la conversion échoue, retourne 0.0
    } else {
      return 0.0; // Valeur par défaut si aucune conversion n'est possible
    }
  }

  // Méthode pour convertir en int de manière sécurisée
  int _convertToInt(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is double) {
      return value.toInt();
    } else if (value is String) {
      // Tentative de conversion de String en int
      final intValue = int.tryParse(value);
      return intValue ?? 0; // Si la conversion échoue, retourne 0
    } else {
      return 0; // Valeur par défaut si aucune conversion n'est possible
    }
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
