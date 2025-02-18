import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AccueilCaissierPage extends StatefulWidget {
  @override
  _AccueilCaissierPageState createState() => _AccueilCaissierPageState();
}

class _AccueilCaissierPageState extends State<AccueilCaissierPage> {
  // Fonction pour récupérer les ventes en attente et validées
  Stream<QuerySnapshot> _getVentes() {
    return FirebaseFirestore.instance.collection('ventes').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ventes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getVentes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final ventes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: ventes.length,
            itemBuilder: (context, index) {
              final vente = ventes[index].data() as Map<String, dynamic>;
              final venteId = ventes[index].id;
              final statut = vente['statut'];

              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Vente #${venteId}'),
                  subtitle: Text('Montant: ${vente['montantTotal']} FCFA'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetailsVentePage(venteId: venteId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DetailsVentePage extends StatelessWidget {
  final String venteId;

  DetailsVentePage({required this.venteId});

  final TextEditingController whatsappController = TextEditingController();

  Future<void> _telechargerFacture(Map<String, dynamic> vente) async {
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
      final filePath =
          '${directory!.path}/facture_${vente['client']}_${now.millisecondsSinceEpoch}.pdf';
      final file = File(filePath);

      await file.writeAsBytes(await pdf.save());

      // Ouvrir le fichier PDF
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        print('Erreur lors de l\'ouverture du fichier : ${result.message}');
      } else {
        print('Facture enregistrée et ouverte : $filePath');

        // Envoi sur WhatsApp
        await _envoyerFactureWhatsApp(filePath, vente['client']);
      }
    } catch (e) {
      print('Erreur lors de la génération de la facture: $e');
    }
  }

void _validerVente(BuildContext context, String venteId, Map<String, dynamic> vente) async {
  final numeroWhatsApp = whatsappController.text.trim();

  if (numeroWhatsApp.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Veuillez entrer un numéro WhatsApp.')),
    );
    return;
  }

  await FirebaseFirestore.instance.collection('ventes').doc(venteId).update({
    'statut': 'validé',
    'client': numeroWhatsApp,
    'dateValidation': Timestamp.now(),
    'destockage': false,
  });

  await _telechargerFacture(vente);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Vente validée avec succès !')),
  );

  Navigator.pop(context);
}

  Future<void> _envoyerFactureWhatsApp(String filePath, String numeroWhatsApp) async {
  final numero = numeroWhatsApp.replaceAll('+', '').replaceAll(' ', ''); // Nettoyage du numéro
  final message = "Voici votre facture.";
  final url = "https://wa.me/$numero?text=${Uri.encodeComponent(message)}";

  try {
    // Vérifier si WhatsApp est installé
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      print("WhatsApp n'est pas installé.");
    }

    // Partager la facture via WhatsApp après ouverture
    await Share.shareXFiles([XFile(filePath)], text: message);
  } catch (e) {
    print('Erreur lors de l\'envoi sur WhatsApp: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails Vente #$venteId'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('ventes').doc(venteId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final vente = snapshot.data!.data() as Map<String, dynamic>;

          final statut = vente['statut'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Montant Total: ${vente['montantTotal']} FCFA',
                    style: TextStyle(fontSize: 18)),
                SizedBox(height: 20),
                Text('Articles:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...vente['articles'].map<Widget>((article) {
                  return ListTile(
                    title: Text('${article['nom']} x${article['quantite']}'),
                    subtitle: Text('Prix: ${article['prixTotal']} FCFA'),
                  );
                }).toList(),
                SizedBox(height: 20),
                TextField(
                  controller: whatsappController,
                  decoration: InputDecoration(
                    labelText: 'Numéro WhatsApp du client',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 20),
                statut == 'en attente'
                    ? ElevatedButton(
                        onPressed: () => _validerVente(context, venteId, vente),
                        child: Text('Valider'),
                      )
                    : ElevatedButton(
                        onPressed: () => _telechargerFacture(vente),
                        child: Text('Télécharger Facture'),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
