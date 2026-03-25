import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class MigrationScreen extends StatefulWidget {
  @override
  _MigrationScreenState createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  bool _isMigrating = false;
  int _productsUpdated = 0;
  int _totalProducts = 0;
  String _status = 'Prêt pour la migration';
  List<String> _errors = [];

  // Configuration des URLs
  final String oldBaseUrl = 'https://hhsccylhbebllyqlihus.supabase.co';
  final String newBaseUrl = 'https://urznwnznbzfhrsmsdpvu.supabase.co';
  final String storagePath = '/storage/v1/object/public/images/produits/';

  Future<void> _migrateImageUrls() async {
    setState(() {
      _isMigrating = true;
      _productsUpdated = 0;
      _errors.clear();
      _status = 'Récupération des produits...';
    });

    try {
      // Récupérer tous les produits
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('produits')
          .get();

      _totalProducts = productsSnapshot.docs.length;
      _status = 'Migration de $_totalProducts produits en cours...';

      for (var doc in productsSnapshot.docs) {
        try {
          final data = doc.data();
          final oldUrl = data['imageUrl'] as String?;
          
          if (oldUrl != null && oldUrl.contains(oldBaseUrl)) {
            // Extraire le nom du fichier
            final fileName = oldUrl.split('/').last;
            
            // Créer la nouvelle URL
            final newUrl = '$newBaseUrl$storagePath$fileName';
            
            // Vérifier que le fichier existe dans le nouveau bucket
            final exists = await _checkImageExists(newUrl);
            
            if (exists) {
              // Mettre à jour dans Firestore
              await doc.reference.update({
                'imageUrl': newUrl,
                'migratedAt': FieldValue.serverTimestamp(),
              });
              
              setState(() {
                _productsUpdated++;
                _status = '✅ Migré: $fileName';
              });
            } else {
              setState(() {
                _errors.add('❌ Fichier introuvable: $fileName');
              });
            }
          }
        } catch (e) {
          setState(() {
            _errors.add('Erreur pour produit ${doc.id}: $e');
          });
        }
      }

      setState(() {
        _status = 'Migration terminée ! $_productsUpdated/$_totalProducts produits mis à jour';
        _isMigrating = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Erreur: $e';
        _isMigrating = false;
      });
    }
  }

  Future<bool> _checkImageExists(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Migration des images'),
        backgroundColor: Colors.orange,
        actions: [
          if (!_isMigrating && _productsUpdated > 0)
            IconButton(
              icon: Icon(Icons.check),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Migration terminée !')),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carte d'information
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Migration des URLs d\'images',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text('Ancien: $oldBaseUrl'),
                    Text('Nouveau: $newBaseUrl'),
                    SizedBox(height: 10),
                    Divider(),
                    Text(
                      '⚠️ Important: Cette opération va modifier les URLs dans Firebase',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Bouton de migration
            ElevatedButton(
              onPressed: _isMigrating ? null : _migrateImageUrls,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isMigrating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Migration en cours...'),
                      ],
                    )
                  : Text('Démarrer la migration', style: TextStyle(fontSize: 16)),
            ),
            SizedBox(height: 20),

            // Statut
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('Statut:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text(_status, textAlign: TextAlign.center),
                  if (_totalProducts > 0)
                    Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(
                        value: _productsUpdated / _totalProducts,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  if (_productsUpdated > 0)
                    Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Progression: $_productsUpdated/$_totalProducts',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Liste des erreurs
            if (_errors.isNotEmpty)
              Expanded(
                child: Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '❌ Erreurs (${_errors.length})',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _errors.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 5),
                                child: Text(
                                  _errors[index],
                                  style: TextStyle(fontSize: 12, color: Colors.red[800]),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}