import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AjouterProduitPage extends StatefulWidget {
  @override
  _AjouterProduitPageState createState() => _AjouterProduitPageState();
}

class _AjouterProduitPageState extends State<AjouterProduitPage> {
  final TextEditingController nomController = TextEditingController();
  final TextEditingController prixController = TextEditingController();
  final TextEditingController quantiteController = TextEditingController();
  final TextEditingController seuilCritiqueController = TextEditingController();
  final TextEditingController seuilAlerteController = TextEditingController();
  final TextEditingController codeBarreController = TextEditingController();
  final TextEditingController gammeController = TextEditingController();

// Liste des types de produits
  final List<String> typesDeProduits = [
    'Savon',
    'Gommage',
    'Lotion',
    'Crème',
    'Huile',
    'Sérum',
    'Masque',
    'Shampooing',
  ];

  String? _selectedType; // Variable pour stocker la sélection
  File? _image;
  final ImagePicker _picker = ImagePicker();

  /// Fonction pour scanner un code-barres
  void scannerCodeBarre() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Scanner le Code-Barres"),
        content: Container(
          width: 300,
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                setState(() {
                  codeBarreController.text = barcodes.first.rawValue ?? "";
                });
                Navigator.pop(context); // Fermer la popup après scan
              }
            },
          ),
        ),
      ),
    );
  }

  /// Fonction pour sélectionner une image depuis la galerie
  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  /// Fonction pour uploader l'image sur Supabase et récupérer l'URL
  Future<String?> uploadImageToSupabase(File image) async {
    try {
      final supabase = Supabase.instance.client;
      final String fileName =
          "produits/${DateTime.now().millisecondsSinceEpoch}.jpg";

      final response = await supabase.storage
          .from("images") // Remplace "images" par le nom de ton bucket Supabase
          .upload(fileName, image);

      if (response.isEmpty) throw Exception("Échec du téléversement");

      final String publicUrl =
          supabase.storage.from("images").getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print("Erreur lors du téléchargement de l'image: $e");
      return null;
    }
  }

  /// Fonction pour enregistrer un produit dans Firestore
  Future<void> enregistrerProduit() async {
    String gamme = gammeController.text;
    String produitNom = nomController.text;
    double prixVente = double.tryParse(prixController.text) ?? 0;
    int quantiteDisponible = int.tryParse(quantiteController.text) ?? 0;
    int seuilCritique = int.tryParse(seuilCritiqueController.text) ?? 0;
    int seuilAlerte = int.tryParse(seuilAlerteController.text) ?? 0;
    String codeBarre = codeBarreController.text;

    // Vérifier si une image a été sélectionnée
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner une image')));
      return;
    }

    // Uploader l'image et obtenir l'URL
    String? imageUrl = await uploadImageToSupabase(_image!);
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'upload de l\'image')));
      return;
    }

    Map<String, dynamic> produitData = {
      'gamme': gamme,
      'nom': produitNom,
      'type': _selectedType,
      'prixVente': prixVente,
      'quantiteDisponible': quantiteDisponible,
      'seuil_critique': seuilCritique,
      'seuil_alerte': seuilAlerte,
      'code_barre': codeBarre,
      'imageUrl': imageUrl, // Stocker l'URL de l'image dans Firestore
    };

    // Enregistrer dans Firestore
    await FirebaseFirestore.instance
        .collection('produits')
        .doc(produitNom)
        .set(produitData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Produit enregistré avec succès !')),
    );

    print("Produit ajouté : $produitData");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ajouter un Produit")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: gammeController,
                  decoration: InputDecoration(labelText: "Gamme")),
              TextField(
                  controller: nomController,
                  decoration: InputDecoration(labelText: "Nom du produit")),
              // Sélecteur du type de produit
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Type de produit"),
                value: _selectedType,
                onChanged: (newValue) {
                  setState(() {
                    _selectedType = newValue;
                  });
                },
                items: typesDeProduits.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
              ),

              /* TextField(
                  controller: prixController,
                  decoration: InputDecoration(labelText: "Prix de vente"),
                  keyboardType: TextInputType.number),
             TextField(
                  controller: quantiteController,
                  decoration: InputDecoration(labelText: "Quantité disponible"),
                  keyboardType: TextInputType.number),*/
              TextField(
                  controller: seuilCritiqueController,
                  decoration: InputDecoration(labelText: "Seuil critique"),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: seuilAlerteController,
                  decoration: InputDecoration(labelText: "Seuil alerte"),
                  keyboardType: TextInputType.number),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeBarreController,
                      decoration: InputDecoration(labelText: "Code-Barres"),
                      readOnly: true,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner),
                    onPressed: scannerCodeBarre,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Bouton pour sélectionner une image
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: pickImage,
                    child: Text("Sélectionner une Image"),
                  ),
                ],
              ),

              // Afficher l'image sélectionnée
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Image.file(_image!, height: 150),
                ),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: enregistrerProduit,
                child: Text("Enregistrer"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
