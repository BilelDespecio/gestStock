import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gest_stock/newVersion/caisier/firestore_service.dart';
import 'package:gest_stock/newVersion/caisier/pdf_service.dart';
import 'package:gest_stock/newVersion/caisier/whatsapp_service.dart';
import 'package:gest_stock/newVersion/caisier/supabase_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../vendeur/constants.dart'; // Pour AppColors

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
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy à HH:mm');

  // Sécuriser l'attente du clic pour éviter des validations multiples
  Future<void> _validerVente() async {
    if (isLoading) return;

    final numeroWhatsApp = whatsappController.text.trim();
    if (numeroWhatsApp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Veuillez entrer un numéro WhatsApp.'), backgroundColor: AppColors.criticalColor),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final pdfFile = await _pdfService.telechargerFacture(widget.vente);
      if (pdfFile == null || !pdfFile.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur lors de la génération du PDF.'), backgroundColor: AppColors.criticalColor),
        );
        return;
      }

      setState(() {
        _pdfFile = pdfFile;
      });

      final url = await _supabaseService.uploadFacture(pdfFile, widget.venteId);
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Échec de l\'upload de la facture.'), backgroundColor: AppColors.criticalColor),
        );
        return;
      }

      await _firestoreService.validerVente(widget.venteId, numeroWhatsApp, url);
      await _whatsappService.envoyerFactureWhatsApp(url, numeroWhatsApp);

      setState(() {
        factureUrl = url;
        widget.vente['statut'] = 'validé';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Vente validée et facture envoyée avec succès !', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: AppColors.priceColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: AppColors.criticalColor),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _imprimerFacture(BuildContext context, String url) async {
    if (url.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/facture_${widget.venteId}.pdf');
          await file.writeAsBytes(response.bodyBytes);

          await Printing.layoutPdf(
            onLayout: (_) => file.readAsBytes(),
          );
        } else {
          throw Exception("Code ${response.statusCode}");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'impression : ${e.toString()}'), backgroundColor: AppColors.criticalColor),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Aucun fichier PDF disponible pour l\'impression.'), backgroundColor: AppColors.criticalColor),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    factureUrl = widget.vente['factureUrl'];
    articles = List<Map<String, dynamic>>.from(widget.vente['articles'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final statut = widget.vente['statut'];
    final client = widget.vente['client'] ?? 'Client inconnu';
    final num montantTotal = widget.vente['montantTotal'] ?? 0;
    
    // Formatage de la date
    String dateAffichee = 'Date inconnue';
    if (widget.vente['date'] != null) {
      if (widget.vente['date'] is Timestamp) {
        dateAffichee = _dateFormat.format((widget.vente['date'] as Timestamp).toDate());
      } else if (widget.vente['date'] is String) {
        dateAffichee = widget.vente['date'];
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('Vente #${widget.venteId}', style:  TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardColor,
        iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
        centerTitle: true,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- RECEIPT/FACTURE CARD ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Facture
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text('FACTURE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.primaryTextColor)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statut == 'validé' ? AppColors.priceColor.withOpacity(0.1) : AppColors.alertColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statut == 'validé' ? 'VALIDÉE' : 'EN ATTENTE',
                                style: TextStyle(
                                  color: statut == 'validé' ? AppColors.priceColor : AppColors.alertColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Informations Client/Date
                        _buildInfoRow(Icons.person_outline, 'Client', client),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.calendar_today_outlined, 'Date', dateAffichee),
                        if (widget.vente['vendeurNom'] != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.storefront_outlined, 'Vendeur', widget.vente['vendeurNom']),
                        ],
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Divider(color: Colors.black12, thickness: 1.5),
                        ),

                        // Articles
                         Text('ARTICLES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondaryTextColor, letterSpacing: 1.2)),
                        const SizedBox(height: 16),
                        ...articles.map((article) {
                          final num pTotal = article['prixTotal'] ?? 0;
                          final num pUnit = article['prixUnitaire'] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${article['quantite']}x', style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentColor)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(article['nom'] ?? 'Article', style:  TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryTextColor)),
                                      Text('${pUnit.toStringAsFixed(0)} FCFA / u', style:  TextStyle(fontSize: 12, color: AppColors.secondaryTextColor)),
                                    ],
                                  ),
                                ),
                                Text('${pTotal.toStringAsFixed(0)} FCFA', style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTextColor)),
                              ],
                            ),
                          );
                        }).toList(),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: Colors.black12, thickness: 1.5),
                        ),

                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryTextColor)),
                            Text(
                              '${montantTotal.toStringAsFixed(0)} FCFA',
                              style:  TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.priceColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // --- BOTTOM ACTION AREA ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
            ),
            child: SafeArea(
              child: statut == 'en attente'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: whatsappController,
                          decoration: InputDecoration(
                            labelText: 'Numéro WhatsApp du client',
                            labelStyle:  TextStyle(color: AppColors.secondaryTextColor),
                            prefixIcon:  Icon(Icons.phone_android, color: AppColors.priceColor),
                            filled: true,
                            fillColor: AppColors.backgroundColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : _validerVente,
                          icon: isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: Text(
                            isLoading ? 'Génération...' : 'Valider & Envoyer Reçu',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.priceColor,
                            disabledBackgroundColor: AppColors.priceColor.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    )
                  : statut == 'validé' && factureUrl != null
                      ? ElevatedButton.icon(
                          onPressed: () => _imprimerFacture(context, factureUrl!),
                          icon: const Icon(Icons.print, color: Colors.white),
                          label: const Text('Imprimer le Ticket', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          child:  Text('Vente validée (sans PDF généré)', style: TextStyle(color: AppColors.secondaryTextColor, fontWeight: FontWeight.bold)),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.secondaryTextColor),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style:  TextStyle(fontSize: 12, color: AppColors.secondaryTextColor)),
            Text(value, style:  TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryTextColor)),
          ],
        ),
      ],
    );
  }
}
