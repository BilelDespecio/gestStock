import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  bool _obscurePassword = true;
  String _errorMessage = '';

  Future<void> _authenticate() async {
    try {
      // Connexion de l'utilisateur
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Récupérer les données de l'utilisateur dans Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'] ?? 'user';

        // Redirection en fonction du rôle
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/homePageAdmin');
        } else if (role == 'user') {
          Navigator.pushReplacementNamed(context, '/homePageMagazinier');
        } else if (role == 'vendeur') {
          Navigator.pushReplacementNamed(context, '/homePageVendeur');
        } else if (role == 'caissier') {
          Navigator.pushReplacementNamed(context, '/homePageCaisier');
        } else {
          setState(() {
            _errorMessage = 'Rôle inconnu. Contactez l’administrateur.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Utilisateur non trouvé. Contactez l’administrateur.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Une erreur s’est produite.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur inattendue : ${e.toString()}';
      });
    }
  }

  Future<bool> _imageExists(String path) async {
    try {
      await rootBundle.load(path);
      return true; // L'image existe
    } catch (e) {
      return false; // L'image n'existe pas
    }
  }

  /// Récupère la version installée
  Future<String> getInstalledVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version; // Ex: "1.0.0"
  }

  /// Récupère la dernière version disponible sur Supabase
  Future<Map<String, String>?> getLatestVersion() async {
    try {
      final response = await supabase
          .from('updates')
          .select()
          .order('version', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final latest = response.first;
        return {
          "version": latest['version'].toString(),
          "apkUrl": latest['apkUrl'].toString(),
        };
      }
    } catch (e) {
      print('Erreur lors de la récupération de la version : $e');
    }
    return null;
  }

  /// Vérifie si une mise à jour est disponible
  void checkForUpdate() async {
    String installedVersion = await getInstalledVersion();
    Map<String, String>? latestVersionData = await getLatestVersion();

    if (latestVersionData != null && latestVersionData.isNotEmpty) {
      String latestVersion = latestVersionData["version"]!;
      String apkUrl = latestVersionData["apkUrl"]!;

      if (installedVersion != latestVersion) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Mise à jour disponible"),
            content: Text(
                "Nouvelle version : $latestVersion\nVoulez-vous mettre à jour ?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Annuler"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Permission.storage.request();
                  _downloadAndInstallApk(apkUrl);
                },
                child: Text("Mettre à jour"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("L'application est à jour"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> requestPermissions() async {
    if (await Permission.storage.request().isGranted) {
      print("Permission accordée");
    } else {
      print("Permission refusée");
    }
  }

  /// Télécharge et installe l'APK
  Future<void> _downloadAndInstallApk(String apkUrl) async {
    await requestPermissions();
    await FlutterDownloader.initialize(debug: true);

    // 🔹 Enregistre le callback global
    FlutterDownloader.registerCallback(downloadCallback);

    await FlutterDownloader.enqueue(
      url: apkUrl,
      savedDir: '/storage/emulated/0/Download',
      fileName: 'app_update.apk',
      showNotification: true,
      openFileFromNotification: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    const String imagePath =
        'assets/images/logo.png'; // Remplace par ton chemin

    return Scaffold(
      backgroundColor: Colors.white, // Fond propre et clair
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: checkForUpdate,
            icon: Icon(Icons.cloud_upload),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              //mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // FutureBuilder pour charger l'image
                FutureBuilder<bool>(
                  future: _imageExists(imagePath),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator(); // Chargement
                    } else if (snapshot.hasError || !snapshot.data!) {
                      return Image.asset(
                        imagePath,
                        //width: 90,
                        //height: 90,
                        fit: BoxFit.cover,
                      );
                    } else {
                      return Image.asset(
                        imagePath,
                        //width: 90,
                        //height: 90,
                        fit: BoxFit.cover,
                      );
                    }
                  },
                ),
                SizedBox(height: 40),
                Text(
                  'Connexion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 15),
                // Champ Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: Colors.blue.shade800),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Champ Mot de passe

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue.shade800),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Bouton Se connecter
                ElevatedButton(
                  onPressed: _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Se connecter',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),

                /* // Lien Mot de passe oublié
                TextButton(
                  onPressed: () {
                    // Action pour mot de passe oublié
                  },
                  child: Text(
                    "Mot de passe oublié ?",
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                ),
*/
                // Affichage de l'erreur
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point') // 🔥 Obligatoire pour le callback
void downloadCallback(String id, int status, int progress) {
  print('Download task ($id) is in status ($status) and progress ($progress)');
  if (status == DownloadTaskStatus.complete.index) {
    OpenFile.open('/storage/emulated/0/Download/app_update.apk');
  }
}
