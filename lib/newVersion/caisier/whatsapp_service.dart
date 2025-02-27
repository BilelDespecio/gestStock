/*import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class WhatsAppService {
  Future<void> envoyerFactureWhatsApp(String filePath, String numeroWhatsApp) async {
    final numero = numeroWhatsApp.replaceAll('+', '').replaceAll(' ', '');
    final message = "Voici votre facture.";
    final url = "https://wa.me/$numero?text=${Uri.encodeComponent(message)}";

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        print("WhatsApp n'est pas installé.");
      }

      await Share.shareXFiles([XFile(filePath)], text: message);
    } catch (e) {
      print('Erreur lors de l\'envoi sur WhatsApp: $e');
    }
  }
}*/


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class WhatsAppService{
  Future< void> envoyerFactureWhatsApp( String filePath, String phoneNumber,) async {
    final file = File(filePath);
    if (await file.exists()) {
      Uri uri = Uri.parse("https://wa.me/$phoneNumber"); // Ouvre le chat

      // Ouvre la discussion WhatsApp du client
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await Future.delayed(Duration(seconds: 2)); // Attendre que WhatsApp charge

        // Ensuite, on partage le fichier
        await Share.shareXFiles([XFile(filePath)], text: "Voici votre reçu !");
      } else {
        print("Impossible d'ouvrir WhatsApp");
      }
    } else {
      print("Le fichier PDF n'existe pas");
    }
  }



}


/*
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService{

  Future <void> envoyerFactureWhatsApp( String filePath, String phoneNumber,) async {
    final file = File(filePath);
    if (await file.exists()) {
      // Ouvrir directement la conversation WhatsApp avec un message
      Uri uri = Uri.parse("https://wa.me/$phoneNumber?text=Voici votre reçu.");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await Future.delayed(Duration(seconds: 2)); // Attendre l’ouverture de WhatsApp

        // Ensuite, proposer le partage du fichier
        await Share.shareXFiles([XFile(filePath)], text: "Voici votre reçu en PDF.");
      } else {
        print("Impossible d'ouvrir WhatsApp");
      }
    } else {
      print("Le fichier PDF n'existe pas");
    }
  }

}
*/