import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class PdfService {
  Future<File?> telechargerFacture(Map<String, dynamic> vente) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
    final formattedDate = formatter.format(now);
    
    // Charger une police qui supporte l'Unicode (pour les symboles et accents)
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();

    String convertirNombreEnLettres(int nombre) {
      if (nombre == 0) return "zéro";

      List<String> unite = ['', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf'];
      List<String> dizaine = ['', 'dix', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'soixante-dix', 'quatre-vingt', 'quatre-vingt-dix'];
      List<String> dixOnzeDixNeuf = ['dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf'];

      String convertirCentaines(int n) {
        if (n < 10) return unite[n];
        if (n < 20) return dixOnzeDixNeuf[n - 10];
        if (n < 100) {
          int d = n ~/ 10, u = n % 10;
          String sep = (d == 7 || d == 9) ? '-' : ' ';
          if (d == 7 || d == 9) return dizaine[d - 1] + sep + dixOnzeDixNeuf[u];
          return dizaine[d] + (u > 0 ? (d == 1 && u == 1 ? ' et ' : sep) + unite[u] : '');
        }
        int c = n ~/ 100, reste = n % 100;
        String cent = (c > 1 ? unite[c] + ' ' : '') + "cent";
        if (c > 1 && reste == 0) cent += "s";
        return cent + (reste > 0 ? ' ' + convertirCentaines(reste) : '');
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

    final montantEnLettres = convertirNombreEnLettres(vente['montantTotal'].toInt());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          italic: fontItalic,
        ),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- HEADER ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GEST_STOCK', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text('Système de gestion de stock', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 10),
                        pw.Text('ID Vente : ${vente['id']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('FACTURE', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text('Date : $formattedDate', style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 2, color: PdfColors.blue800),
                pw.SizedBox(height: 10),
                
                // --- CLIENT INFO ---
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CLIENT :', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.Text('${vente['client']??'Client Passagé'}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Spacer(),
                      if (vente['vendeurNom'] != null)
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('VENDEUR :', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                            pw.Text('${vente['vendeurNom']}', style: pw.TextStyle(fontSize: 12)),
                          ],
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // --- ARTICLES TABLE ---
                pw.Text('Détails des articles :', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headers: ['Libellé', 'Qté', 'P.U (FCFA)', 'Total (FCFA)'],
                  data: (vente['articles'] as List).map((article) {
                    return [
                      article['nom'],
                      article['quantite'].toString(),
                      NumberFormat('#,###', 'fr_FR').format(article['prixUnitaire']),
                      NumberFormat('#,###', 'fr_FR').format(article['prixTotal']),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  cellHeight: 25,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                  },
                ),
                pw.SizedBox(height: 20),

                // --- SUMMARY ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('NET À PAYER :', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                              pw.Text('${NumberFormat('#,###', 'fr_FR').format(vente['montantTotal'])} FCFA', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // --- AMOUNT IN WORDS ---
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text('Arrêté la présente facture à la somme de : ', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                      pw.Expanded(
                        child: pw.Text('${montantEnLettres.toUpperCase()} FRANCS CFA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                
                pw.Spacer(),
                
                // --- FOOTER ---
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Merci pour votre achat !', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                    pw.Text('Document généré électroniquement', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;

      final filePath = '${directory.path}/facture_${vente['id']}_${now.millisecondsSinceEpoch}.pdf';
      final file = File(filePath);

      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Erreur PDF: $e');
      return null;
    }
  }

  Future<File?> genererRapportStatistiques({
    required String periode,
    required int totalProduits,
    required int stockCritique,
    required int stockAlerte,
    required int totalNbrVente,
    required int totalNbrCommande,
    required double totalVentes,
    required String tauxNGN,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GEST_STOCK', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text('Rapport d\'activité', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text('Date: ${formatter.format(now)}', style: pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2, color: PdfColors.blue800),
              pw.SizedBox(height: 20),
              pw.Text('Résumé des statistiques (${periode})', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                headers: ['Indicateur', 'Valeur'],
                data: [
                  ['Total Produits en Catalogue', totalProduits.toString()],
                  ['Produits en Stock Critique', stockCritique.toString()],
                  ['Produits en Stock Alerte', stockAlerte.toString()],
                  ['Nombre de Ventes sur la période', totalNbrVente.toString()],
                  ['Nombre de Commandes Effectuées', totalNbrCommande.toString()],
                  ['Chiffre d\'Affaires Total', '${NumberFormat('#,###', 'fr_FR').format(totalVentes)} FCFA'],
                  ['Taux de Conversion (NGN -> XOF)', tauxNGN],
                ],
              ),
              
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Center(child: pw.Text('Document généré par l\'application GestStock', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
            ],
          );
        },
      ),
    );

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      final filePath = '${directory.path}/rapport_stats_${now.millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Erreur Rapport PDF: $e');
      return null;
    }
  }
}
