import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

Future<File?> convertImageToWebP(File imageFile) async {
  try {
    // Obtenir le répertoire temporaire pour stocker le fichier compressé
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.webp';

    // Compression et conversion en WebP (qualité 80)
    final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,  // Chemin du fichier source
      targetPath,               // Chemin du fichier cible
      format: CompressFormat.webp,
      quality: 80,              // Compression de qualité (0-100)
    );

    if (compressedFile == null) return null;
    
    return File(compressedFile.path);
  } catch (e) {
    print("Erreur lors de la conversion en WebP : $e");
    return null;
  }
}
