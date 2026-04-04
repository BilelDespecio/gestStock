import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  Future<void> envoyerFactureWhatsApp(String factureUrl, String phoneNumber) async {
    // Nettoyer le numéro (enlever le +, les espaces, les tirets)
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Encoder le message
    String message = "Bonjour, voici votre reçu de paiement. Vous pouvez le consulter ici : $factureUrl";

    final Uri uri = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");

    // Vérifier si l'URL peut être ouverte (Package Visibility géré dans AndroidManifest)
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception("Impossible d'ouvrir WhatsApp. Vérifiez s'il est installé.");
    }
  }
}