import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/caisier/firestore_service.dart';
import 'package:gest_stock/newVersion/caisier/pdf_service.dart';
import 'package:gest_stock/newVersion/caisier/whatsapp_service.dart';


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
  final TextEditingController whatsappController = TextEditingController();

  Future<void> _validerVente() async {
    final numeroWhatsApp = whatsappController.text.trim();
    if (numeroWhatsApp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez entrer un numéro WhatsApp.')),
      );
      return;
    }

    await _firestoreService.validerVente(widget.venteId, numeroWhatsApp);
    final filePath = await _pdfService.telechargerFacture(widget.vente);

   /*if (filePath.isNotEmpty) {
    // Envoi sur WhatsApp
        final whatsappService = WhatsAppService();
    await whatsappService.envoyerFactureWhatsApp(filePath, numeroWhatsApp);
  }*/

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vente validée avec succès !')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Détails Vente #${widget.venteId}'), backgroundColor: Colors.blue.shade800, centerTitle: true, elevation: 4),
      body: Column(
        children: [
          Text('Montant: ${widget.vente['montantTotal']} FCFA'),
          TextField(
            controller: whatsappController,
            decoration: InputDecoration(labelText: 'Numéro WhatsApp'),
          ),
          ElevatedButton(
            onPressed: _validerVente,
            child: Text('Valider la vente'),
          ),
        ],
      ),
    );
  }
}
