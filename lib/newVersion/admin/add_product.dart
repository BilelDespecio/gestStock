import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/convertWebp.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AjouterProduitPage extends StatefulWidget {
  final String?
      produitId; // Si null, c'est un ajout, sinon c'est une modification.
  AjouterProduitPage({this.produitId});

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
  final TextEditingController poidsController = TextEditingController();
  final TextEditingController marketPriceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController prixDecideController = TextEditingController();

  final List<String> typesDeProduits = [
    'Savon',
    'Gommage',
    'Lotion',
    'Crème',
    'Huile',
    'Sérum',
    'Masque',
    'Shampooing',
    'Lait',
    'Mèche',
    'Gellule',
    'Parfum',
    'Gel de Douche',
    'Déodorant',
    'Grattoir',
  ];

  final List<Map<String, String>> etatsProduits = [
    {'label': 'Poids', 'value': 'g'},
    {'label': 'Volume', 'value': 'ml'},
    {'label': 'Nombre', 'value': 'pcs'}
  ];

  String? _selectedType;
  List<String> _typesDeProduits = [];
  String? _selectedEtat;
  dynamic _image;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.produitId != null) {
      _chargerProduit(widget.produitId!);
    }
    _fetchTypesDeProduits();
  }

  Future<void> _chargerProduit(String produitId) async {
    var doc = await FirebaseFirestore.instance
        .collection('produits')
        .doc(produitId)
        .get();
    if (doc.exists) {
      var data = doc.data();
      setState(() {
        nomController.text = data?['nom'] ?? '';
        prixController.text = data?['prixVente'].toString() ?? '';
        quantiteController.text = data?['quantiteDisponible'].toString() ?? '';
        seuilCritiqueController.text = data?['seuil_critique'].toString() ?? '';
        seuilAlerteController.text = data?['seuil_alerte'].toString() ?? '';
        codeBarreController.text = data?['code_barre'] ?? '';
        gammeController.text = data?['gamme'] ?? '';
        poidsController.text = data?['poids'] ?? '';
        marketPriceController.text = data?['marketPrice'].toString() ?? '';
        descriptionController.text = data?['description'] ?? '';
        _selectedType = data?['type'];
        _image = data?['imageUrl']; // Stocke l'URL existante de l'image
      });
    }
  }

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

  ///la fonction pour rogner l'image

  Future<File?> cropImage(File imageFile) async {
    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      // Style de rognage
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Rogner l\'image',
          toolbarColor: Colors.green,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Rogner l\'image',
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  /// Fonction pour sélectionner une image depuis la galerie ou prendre une photo
  Future<void> pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Galerie'),
            onTap: () async {
              Navigator.pop(context);
              final pickedFile =
                  await _picker.pickImage(source: ImageSource.gallery);

              if (pickedFile != null) {
                File originalImage = File(pickedFile.path);
                // Rogner l'image
                File? croppedImage = await cropImage(originalImage);

                if (croppedImage != null) {
                  // Convertir en WebP après rognage
                  File? webpImage = await convertImageToWebP(croppedImage);
                  if (webpImage != null) {
                    setState(() {
                      _image = webpImage;
                    });
                  }
                }
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Appareil Photo'),
            onTap: () async {
              Navigator.pop(context);
              final pickedFile =
                  await _picker.pickImage(source: ImageSource.camera);

              if (pickedFile != null) {
                File originalImage = File(pickedFile.path);
                // Rogner l'image
                File? croppedImage = await cropImage(originalImage);

                if (croppedImage != null) {
                  // Convertir en WebP après rognage
                  File? webpImage = await convertImageToWebP(croppedImage);
                  if (webpImage != null) {
                    setState(() {
                      _image = webpImage;
                    });
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Fonction pour uploader l'image sur Supabase et récupérer l'URL
  Future<String?> uploadImageToSupabase(File image) async {
    try {
      final supabase = Supabase.instance.client;
      final String fileName =
          "produits/${DateTime.now().millisecondsSinceEpoch}.webp"; // Enregistre en WebP

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
    String poids = '${poidsController.text} ${_selectedEtat!}';
    double marketPrice = double.tryParse(marketPriceController.text) ?? 0;
    String description = descriptionController.text;
    int prixDecide = int.tryParse(prixDecideController.text) ?? 0;

    String docName = gamme + '_' + produitNom;

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
      'poids': poids,
      'marketPrice': marketPrice,
      'description': description,
      'prixDecide': prixDecide,
    };

    if (widget.produitId == null) {
      // Création d'un nouveau produit
      await FirebaseFirestore.instance
          .collection('produits')
          .doc(docName)
          .set(produitData);
    } else {
      // Mise à jour d'un produit existant
      await FirebaseFirestore.instance
          .collection('produits')
          .doc(widget.produitId)
          .update(produitData);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Succès"),
          content: Text("Produit enregistré avec succès !"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
    print("Produit ajouté : $produitData");
  }

  // Fonction pour récupérer les types de produits depuis Firestore
  Future<void> _fetchTypesDeProduits() async {
    try {
      var snapshot =
          await FirebaseFirestore.instance.collection('types_produits').get();

      List<String> types = snapshot.docs
          .map((doc) => doc['nom']
              .toString()) // Vérifier que 'nom' est bien le champ contenant le type
          .toList();

      setState(() {
        _typesDeProduits = types;
      });
    } catch (e) {
      print("Erreur lors du chargement des types de produits : $e");
    }
  }

// Fonction pour ajouter une nouvelle catégorie
  Future<void> _ajouterNouvelleCategorie(BuildContext context) async {
    String nouvelleCategorie = "";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Ajouter une nouvelle catégorie"),
          content: TextField(
            decoration: InputDecoration(hintText: "Nom de la catégorie"),
            onChanged: (value) {
              nouvelleCategorie = value.trim();
            },
          ),
          actions: [
            TextButton(
              child: Text("Annuler"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("Ajouter"),
              onPressed: () async {
                if (nouvelleCategorie.isNotEmpty &&
                    !_typesDeProduits.contains(nouvelleCategorie)) {
                  try {
                    // Ajouter dans Firestore
                    await FirebaseFirestore.instance
                        .collection('types_produits')
                        .doc(nouvelleCategorie)
                        .set({'nom': nouvelleCategorie});

                    // Mettre à jour la liste et sélectionner la nouvelle catégorie
                    setState(() {
                      _typesDeProduits.add(nouvelleCategorie);
                      _selectedType = nouvelleCategorie;
                    });

                    Navigator.pop(context);
                  } catch (e) {
                    print("Erreur lors de l'ajout : $e");
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ajouter un Produit"),
        backgroundColor: Colors.blue.shade800, // Bleu foncé pour un aspect pro
        centerTitle: true,
        elevation: 4,
      ),
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
                  decoration: InputDecoration(labelText: "Variété")),
              // Sélecteur du type de produit
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Catégorie"),
                value: _selectedType,
                onChanged: (newValue) {
                  if (newValue == "Ajouter une catégorie") {
                    _ajouterNouvelleCategorie(context);
                  } else {
                    setState(() {
                      _selectedType = newValue;
                    });
                  }
                },
                items: [
                  ..._typesDeProduits.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  DropdownMenuItem<String>(
                    value: "Ajouter une catégorie",
                    child: Row(
                      children: [
                        Icon(Icons.add, color: Colors.green),
                        SizedBox(width: 8),
                        Text("Ajouter une catégorie"),
                      ],
                    ),
                  ),
                ],
              ),
              /* TextField(
                  controller: prixController,
                  decoration: InputDecoration(labelText: "Prix de vente"),
                  keyboardType: TextInputType.number),*/
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "État du produit"),
                value: _selectedEtat,
                onChanged: (newValue) =>
                    setState(() => _selectedEtat = newValue),
                items: etatsProduits.map((etat) {
                  return DropdownMenuItem<String>(
                    value: etat['value'], // Valeur enregistrée
                    child: Text(etat['label']!), // Texte affiché
                  );
                }).toList(),
              ),
              TextField(
                controller: poidsController,
                decoration: InputDecoration(
                  labelText: _selectedEtat == "ml"
                      ? "Volume (ml)"
                      : _selectedEtat == "pcs"
                          ? "Nombre (pcs)"
                          : "Poids (g)",
                  border:
                      OutlineInputBorder(), // Ajoute une bordure pour un meilleur design
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                    labelText: "Description(usage et/ou composition)"),
              ),
              TextField(
                  controller: seuilCritiqueController,
                  decoration: InputDecoration(labelText: "Seuil critique"),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: seuilAlerteController,
                  decoration: InputDecoration(labelText: "Seuil alerte"),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: marketPriceController,
                  decoration: InputDecoration(
                      labelText: "Prix de vente du marché(en FCFA)"),
                  keyboardType: TextInputType.number),
              if (widget.produitId != null)
                TextField(
                  controller: prixDecideController,
                  decoration: InputDecoration(labelText: "Prix Décidé(en FCFA)"),
                  keyboardType: TextInputType.number,
                ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  
                  ElevatedButton(onPressed: pickImage, child: Column(
                    children: [
                      Icon(Icons.image),
                      Text("Image")
                    ],
                  )),
                  if (_image != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: _image is String // Vérifie si c'est une URL
                          ? Image.network(_image as String,
                              height: 150) // Affiche l'image depuis Firestore
                          : Image.file(_image as File,
                              height: 150), // Affiche depuis le stockage local
                    ),
                ],
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
