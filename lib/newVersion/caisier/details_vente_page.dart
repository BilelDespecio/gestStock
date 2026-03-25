import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gest_stock/newVersion/caisier/firestore_service.dart';
import 'package:gest_stock/newVersion/caisier/pdf_service.dart';
import 'package:gest_stock/newVersion/caisier/whatsapp_service.dart';
import 'package:gest_stock/newVersion/caisier/supabase_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

class DetailsVentePage extends StatefulWidget {
  final String venteId;
  final Map<String, dynamic> vente;

  DetailsVentePage({required this.venteId, required this.vente});

  @override
  _DetailsVentePageState createState() => _DetailsVentePageState();
}

class _DetailsVentePageState extends State<DetailsVentePage> {
  final FirestoreService _firestoreService = FirestoreService();
  final PdfService _pdfService = PdfService();
  final WhatsAppService _whatsappService = WhatsAppService();
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController whatsappController = TextEditingController();

  File? _pdfFile;
  bool isLoading = false;
  String? factureUrl;
  List<Map<String, dynamic>> articles = [];

  Future<void> _validerVente() async {
    final numeroWhatsApp = whatsappController.text.trim();
    if (numeroWhatsApp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez entrer un numéro WhatsApp.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1️⃣ Générer la facture PDF dans lib/newVersion/caisier/pdf_service.dart
      final pdfFile = await _pdfService.telechargerFacture(widget.vente);
      if (pdfFile == null || !pdfFile.existsSync()) {
        print('❌ Erreur : La facture PDF n\'a pas été générée correctement.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du PDF.')),
        );
        return;
      }
      print('✅ Facture générée : ${pdfFile.path}');

      setState(() {
        _pdfFile = pdfFile;
        print('✅ Fichier PDF enregistré: ${_pdfFile?.path}');
        print('🧐 Fichier existe: ${_pdfFile?.existsSync()}');
      });

      // uploadFacture(File file, String venteId) dans lib/newVersion/caisier/supabase_service.dart
      // 2️⃣ Envoyer la facture sur Supabase Storage et récupérer l'URL
      final factureUrl =
          await _supabaseService.uploadFacture(pdfFile, widget.venteId);
      if (factureUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'upload de la facture.')),
        );
        return;
      }

      // 3️⃣ Mettre à jour Firestore avec le lien de la facture dans lib/newVersion/caisier/firestore_service.dart
      await _firestoreService.validerVente(
          widget.venteId, numeroWhatsApp, factureUrl);

      // 4️⃣ Envoyer le lien au client sur WhatsApp dans lib/newVersion/caisier/whatsapp_service.dart
      await _whatsappService.envoyerFactureWhatsApp(factureUrl, numeroWhatsApp);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vente validée et facture envoyée !')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
Future<void> _imprimerFacture(BuildContext context, String factureUrl) async {
  if (factureUrl.isNotEmpty) {
    print("📥 Téléchargement de la facture...");

    try {
      // 📌 Télécharger le fichier PDF depuis l'URL
      final response = await http.get(Uri.parse(factureUrl));

      if (response.statusCode == 200) {
        // 📁 Sauvegarde temporaire du fichier sur l'appareil
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/facture.pdf');
        await file.writeAsBytes(response.bodyBytes);

        print("✅ Facture téléchargée : ${file.path}");

        // 🖨️ Impression du fichier PDF
        await Printing.layoutPdf(
          onLayout: (_) => file.readAsBytes(),
        );

        print("🖨️ Impression terminée !");
      } else {
        throw Exception("❌ Erreur de téléchargement du PDF (Code ${response.statusCode})");
      }
    } catch (e) {
      print("❌ Erreur lors de l'impression : ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'impression : ${e.toString()}')),
      );
    }
  } else {
    print("❌ Aucun fichier PDF disponible pour l'impression.");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aucun fichier PDF disponible pour l\'impression.')),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    final statut = widget.vente['statut'];
    final client = widget.vente['client'] ?? 'Client inconnu';
    final montantTotal = widget.vente['montantTotal'] ?? 'Non défini';
    final dateVente = widget.vente['date'] ?? 'Date inconnue';
    factureUrl = widget.vente['factureUrl'];
    articles = List<Map<String, dynamic>>.from(widget.vente['articles'] ?? []);
    factureUrl = widget.vente['factureUrl'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Détails Vente #${widget.venteId}'),
        backgroundColor: Colors.blue.shade800,
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🛒 Vente ID: ${widget.venteId}',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('👤 Client: $client',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    SizedBox(height: 8),
                    Text('📅 Date: $dateVente', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),
                    Text('💰 Montant Total: $montantTotal FCFA',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Liste des articles vendus
            Text('📦 Articles vendus',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: Icon(FontAwesomeIcons.box as IconData?, color: Colors.blue),
                      title: Text(article['nom'] ?? 'Article inconnu',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'Quantité: ${article['quantite']} | Prix: ${article['prixUnitaire']} FCFA   => Total: ${article['prixTotal']} FCFA'),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 20),

            if (statut == 'en attente') ...[
              TextField(
                controller: whatsappController,
                decoration: InputDecoration(
                  labelText: 'Numéro WhatsApp',
                  prefixIcon: Icon(Icons.phone, color: Colors.green),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _validerVente,
                icon: Icon(Icons.check, color: Colors.white),
                label: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Valider la vente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ] else if (statut == 'validé' && factureUrl != null) ...[
              ElevatedButton.icon(
                onPressed:()=> _imprimerFacture(context, factureUrl!),
                icon: Icon(Icons.print, color: Colors.white),
                label: Text('Imprimer la facture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
