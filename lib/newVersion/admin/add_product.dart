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
  String? _selectedUnite = 'pcs';// Pour stocker l'unité sélectionnée

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
      setState(() { //ligne 74
        nomController.text = data?['nom'] ?? '';
        prixController.text = data?['prixVente'].toString() ?? '';
        quantiteController.text = data?['quantiteDisponible'].toString() ?? '';
        seuilCritiqueController.text = data?['seuil_critique'].toString() ?? '';
        seuilAlerteController.text = data?['seuil_alerte'].toString() ?? '';
        codeBarreController.text = data?['code_barre'] ?? '';
        gammeController.text = data?['gamme'] ?? '';
        poidsController.text = data?['poids']?.toString() ?? ''; 
        marketPriceController.text = data?['marketPrice'].toString() ?? '';
        descriptionController.text = data?['description'] ?? '';
        _selectedType = data?['type'];
        _image = data?['imageUrl']; // Stocke l'URL existante de l'image
        quantiteController.text = (data?['quantite'] as double?)?.toString() ?? '0'; //ligne 87
        _selectedUnite = data?['unite']?.toString() ?? 'pcs'; 
        prixDecideController.text = data?['prixDecide'].toString() ?? '';
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
    int seuilCritique = int.tryParse(seuilCritiqueController.text) ?? 0;
    int seuilAlerte = int.tryParse(seuilAlerteController.text) ?? 0;
    String codeBarre = codeBarreController.text;
    int poids = int.tryParse(poidsController.text) ?? 0;
    double marketPrice = double.tryParse(marketPriceController.text) ?? 0;
    String description = descriptionController.text;
    int prixDecide = int.tryParse(prixDecideController.text) ?? 0;
    double quantite = double.tryParse(quantiteController.text) ?? 0;
    String unite = _selectedUnite ?? 'pcs'; 
    String docName = gamme + '_' + produitNom;

    // Vérifier si une image a été sélectionnée
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner une image')));
      return;
    }

    // Uploader l'image et obtenir l'URL
    String? imageUrl;
    if (_image != null) {
      if (_image is File) {
        // Cas où c'est une nouvelle image à uploader
        imageUrl =
            await uploadImageToSupabase(_image as File); // ligne 254 modifiée
        if (imageUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur lors de l\'upload de l\'image')));
          return;
        }
      } else if (_image is String) {
        // Cas où c'est déjà une URL existante
        imageUrl = _image as String;
      }
    }

    Map<String, dynamic> produitData = {
      'gamme': gamme,
      'nom': produitNom,
      'type': _selectedType,
      'prixVente': prixVente,
      'seuil_critique': seuilCritique,
      'seuil_alerte': seuilAlerte,
      'code_barre': codeBarre,
      'imageUrl': imageUrl, // Stocker l'URL de l'image dans Firestore
      'poids': poids,
      'marketPrice': marketPrice,
      'description': description,
      'prixDecide': prixDecide,
      // Nouveaux champs
      'quantite': quantite,
      'unite': unite,
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

    // Fonction interne pour rechercher et mettre à jour le champ 'pvp' dans une collection
    // Fonction pour rechercher et mettre à jour le champ 'pvp' tout en conservant l'ancien prix
    Future<void> updatePvpInCollection(String collectionName) async {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('nom', isEqualTo: produitNom)
          .get();

      for (var doc in querySnapshot.docs) {
        final currentData = doc.data();
        final ancienPvp = currentData['pvp'];

        await doc.reference.update({
          'oldPvp': ancienPvp, // Sauvegarder l'ancien pvp
          'pvp': prixDecide, // Mettre à jour le nouveau pvp
          'lastUpdated': FieldValue
              .serverTimestamp(), // Optionnel : trace de la date de mise à jour
        });

        print(
            'Mise à jour de $collectionName : ancien pvp = $ancienPvp, nouveau pvp = $prixDecide');
      }
    }

    // 🔁 Mise à jour dans les deux collections : stock et stockBoutique
    await updatePvpInCollection('stock');
    await updatePvpInCollection('stockBoutique');

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
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: quantiteController,
                      decoration: InputDecoration(
                        labelText: "Quantité",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: "Unité",
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedUnite,
                      onChanged: (newValue) =>
                          setState(() => _selectedUnite = newValue),
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                      ],
                    ),
                  ),
                ],
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
                  decoration:
                      InputDecoration(labelText: "Prix Décidé(en FCFA)"),
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
                  ElevatedButton(
                      onPressed: pickImage,
                      child: Column(
                        children: [Icon(Icons.image), Text("Image")],
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
