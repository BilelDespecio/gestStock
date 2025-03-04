import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// Envoie une facture PDF sur Supabase Storage et retourne son URL
  Future<String?> uploadFacture(File file, String venteId) async {
    try {
      final filePath = 'factures/$venteId.pdf'; // Nom du fichier sur Supabase

      // Vérifier si le fichier existe déjà (optionnel)
      final response = await supabase.storage.from('factures').list();
      if (response.any((element) => element.name == '$venteId.pdf')) {
        await supabase.storage.from('factures').update(filePath, file);
      } else {
        await supabase.storage.from('factures').upload(filePath, file);
      }

      // Génération de l'URL publique du fichier
      final publicUrl = supabase.storage.from('factures').getPublicUrl(filePath);
      print('Facture uploadée avec succès: $publicUrl');
      return publicUrl;
      
    } catch (e) {
      print("Erreur lors de l'upload sur Supabase: $e");
      return null;
    }
  }
}
