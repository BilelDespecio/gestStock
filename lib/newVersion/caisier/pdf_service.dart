import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';


class PdfService {
  Future<File?> telechargerFacture(Map<String, dynamic> vente) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}:${now.second}';
    String convertirNombreEnLettres(int nombre) {
      if (nombre == 0) return "zéro";

      List<String> unite = [
        '',
        'un',
        'deux',
        'trois',
        'quatre',
        'cinq',
        'six',
        'sept',
        'huit',
        'neuf'
      ];

      List<String> dizaine = [
        '',
        'dix',
        'vingt',
        'trente',
        'quarante',
        'cinquante',
        'soixante',
        'soixante-dix',
        'quatre-vingt',
        'quatre-vingt-dix'
      ];

      List<String> dixOnzeDixNeuf = [
        'dix',
        'onze',
        'douze',
        'treize',
        'quatorze',
        'quinze',
        'seize',
        'dix-sept',
        'dix-huit',
        'dix-neuf'
      ];

      String convertirCentaines(int n) {
        if (n < 10) return unite[n];
        if (n < 20) return dixOnzeDixNeuf[n - 10];
        if (n < 100) {
          int d = n ~/ 10, u = n % 10;
          String sep = (d == 7 || d == 9) ? '-' : ' ';
          if (d == 7 || d == 9) return dizaine[d - 1] + sep + dixOnzeDixNeuf[u];
          return dizaine[d] + (u > 0 ? sep + unite[u] : '');
        }

        int c = n ~/ 100, reste = n % 100;
        String cent = (c > 1 ? unite[c] + ' ' : '') + "cent";
        return cent + (reste > 0 ? ' ' + convertirCentaines(reste) : (c > 1 ? 's' : ''));
      }

      String convertir(int n) {
        if (n < 1000) return convertirCentaines(n);

        int mille = n ~/ 1000, reste = n % 1000;
        String milleTxt = (mille > 1 ? convertirCentaines(mille) + " " : "") + "mille";
        if (mille == 1) milleTxt = "mille";

        return milleTxt + (reste > 0 ? ' ' + convertirCentaines(reste) : '');
      }

      if (nombre < 1000000) return convertir(nombre);

      int million = nombre ~/ 1000000, reste = nombre % 1000000;
      String millionTxt = (million > 1 ? convertir(million) + " " : "") + "million" + (million > 1 ? "s" : "");

      return millionTxt + (reste > 0 ? ' ' + convertir(reste) : '');
    }


    // Utilisation :
    final montantEnLettres =
    convertirNombreEnLettres(vente['montantTotal'].toInt());

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('FACTURE ${vente['id']}',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Date: $formattedDate'),
              pw.Text('Client: ${vente['client']}',
                  style: pw.TextStyle(fontSize: 18)),
              pw.Text('Montant Total: ${vente['montantTotal']} FCFA',
                  style: pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Text('Détails des articles:',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: [
                  'N⁰', // Nouvelle colonne
                  'Désignation',
                  'Quantité',
                  'Prix Unitaire (FCFA)',
                  'Montant (FCFA)'
                ],
                data: vente['articles']
                    .asMap()
                    .entries
                    .map<List<String>>((entry) {
                  final index = entry.key + 1; // Incrémentation du numéro
                  final article = entry.value;
                  return [
                    index.toString(), // Ajout du numéro
                    article['nom'].toString(),
                    article['quantite'].toString(),
                    '${article['prixUnitaire']}',
                    '${article['prixTotal']}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Arrêté la présente facture à $montantEnLettres francs CFA.',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Merci pour votre achat',
                  style: pw.TextStyle(fontSize: 16)),
            ],
          );
        },
      ),
    );

    try {
  final directory = await getExternalStorageDirectory();
  if (directory == null) {
    print('Erreur: Impossible d\'accéder au stockage externe.');
    return null;
  }

  final filePath =
      '${directory.path}/facture_${vente['client']}_${now.millisecondsSinceEpoch}.pdf';
  final file = File(filePath);

  await file.writeAsBytes(await pdf.save());

  print('Facture générée avec succès: $filePath');

  return file;
} catch (e) {
  print('Erreur lors de la génération de la facture: $e');
  return null;
}
  }

}
