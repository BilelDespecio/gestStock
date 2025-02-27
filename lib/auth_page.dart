import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Pour utiliser rootBundle

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    const String imagePath = 'assets/images/logo.png'; // Remplace par ton chemin

    return Scaffold(
      backgroundColor: Colors.white, // Fond propre et clair
      /*appBar: AppBar(
        title: Text('Connexion'),
        backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
      ),*/
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // FutureBuilder pour charger l'image
                FutureBuilder<bool>(
                  future: _imageExists(imagePath),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator(); // Chargement
                    } else if (snapshot.hasError || !snapshot.data!) {
                      return Icon(
                        Icons.storefront, // Icône de boutique par défaut
                        size: 90,
                        color: Colors.blue.shade800,
                      );
                    } else {
                      return Image.asset(
                        imagePath,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      );
                    }
                  },
                ),
                SizedBox(height: 20),

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
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue.shade800),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
