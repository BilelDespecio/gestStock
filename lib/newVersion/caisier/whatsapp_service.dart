import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  Future<void> envoyerFactureWhatsApp(String factureUrl, String phoneNumber) async {
    String encodedMessage = Uri.encodeComponent(
        "Bonjour, voici votre reçu de paiement. Vous pouvez le consulter ici : $factureUrl");

    Uri uri = Uri.parse("https://wa.me/$phoneNumber?text=$encodedMessage");

    bool isInstalled = await canLaunchUrl(uri);
    if (!isInstalled) {
      throw Exception("WhatsApp n'est pas installé sur cet appareil.");
    }

    bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception("Impossible d'ouvrir WhatsApp.");
    }
  }
}