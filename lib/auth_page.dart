import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:gest_stock/newVersion/vendeur/constants.dart';
import 'package:gest_stock/newVersion/menu/theme_controller.dart';

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    FlutterDownloader.registerCallback(downloadCallback);
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return "Aucun utilisateur trouvé pour cet email.";
      case 'wrong-password':
        return "Mot de passe incorrect.";
      case 'invalid-email':
        return "L'adresse email n'est pas valide.";
      case 'user-disabled':
        return "Ce compte a été désactivé.";
      case 'network-request-failed':
        return "Erreur de connexion réseau. Vérifiez votre Internet.";
      case 'too-many-requests':
        return "Trop de tentatives. Réessayez plus tard.";
      default:
        return "Une erreur s'est produite lors de la connexion.";
    }
  }

  Future<void> _authenticate() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Veuillez remplir tous les champs.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

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
        _showError('Utilisateur non trouvé. Contactez l’administrateur.');
      }
    } on FirebaseAuthException catch (e) {
      _showError(_mapFirebaseError(e.code));
    } catch (e) {
      _showError('Erreur inattendue : ${e.toString()}');
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
    
    // Obtenir le dossier de téléchargement
    String? downloadsPath;
    if (Platform.isAndroid) {
      downloadsPath = '/storage/emulated/0/Download';
      final dir = Directory(downloadsPath);
      if (!await dir.exists()) {
        final externalDir = await getExternalStorageDirectory();
        downloadsPath = externalDir?.path ?? (await getApplicationDocumentsDirectory()).path;
      }
    } else {
      downloadsPath = (await getApplicationDocumentsDirectory()).path;
    }

    await FlutterDownloader.enqueue(
      url: apkUrl,
      savedDir: downloadsPath,
      fileName: 'app_update.apk',
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true, // Pour le dossier Downloads
    );
  }

  @override
  Widget build(BuildContext context) {
    const String imagePath = 'assets/images/logo.png';

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final isDark = themeController.isDarkMode;
        
        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Animation du Logo
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 800),
                                  tween: Tween(begin: 0.8, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: child,
                                    );
                                  },
                                  child: Image.asset(
                                    imagePath,
                                    height: 120,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                Text(
                                  'Connexion',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Veuillez vous identifier pour continuer',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                // Champ Email
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 20),
                                // Champ Mot de passe
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'Mot de passe',
                                  icon: Icons.lock_outline,
                                  isDark: isDark,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: AppColors.secondaryTextColor,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                // Bouton Se connecter
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _authenticate,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Se connecter',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                ),
                                // Affichage de l'erreur
                                if (_errorMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.criticalColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.criticalColor.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _errorMessage,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.criticalColor, fontSize: 14),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Footer Développeur
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rocket_launch_rounded,
                              size: 16,
                              color: AppColors.secondaryTextColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Développé par ',
                              style: TextStyle(
                                color: AppColors.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'HOBELIOS',
                              style: TextStyle(
                                color: AppColors.accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'v1.5.0',
                          style: TextStyle(
                            color: AppColors.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                          ],
                        )
                      ),
                    ],
                  ),
                ),
              ),
              // Bouton mise à jour (discret en haut)
              Align(
                alignment: Alignment.topRight,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      onPressed: checkForUpdate,
                      icon: Icon(Icons.system_update_alt, color: AppColors.accentColor),
                      tooltip: 'Vérifier les mises à jour',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.primaryTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.secondaryTextColor),
        prefixIcon: Icon(icon, color: AppColors.accentColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.accentColor.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.accentColor, width: 2),
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
