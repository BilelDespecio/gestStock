import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/convertWebp.dart';
import 'package:gest_stock/newVersion/vendeur/constants.dart';
import 'package:gest_stock/newVersion/vendeur/widgets/header_section.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AjouterProduitPage extends StatefulWidget {
  final String? produitId; 
  AjouterProduitPage({this.produitId});

  @override
  _AjouterProduitPageState createState() => _AjouterProduitPageState();
}

class _AjouterProduitPageState extends State<AjouterProduitPage> {
  final _formKey = GlobalKey<FormState>();
  
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
  
  String? _selectedUnite = 'pcs';
  String? _selectedType;
  List<String> _typesDeProduits = [];
  dynamic _image;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.produitId != null) {
      _chargerProduit(widget.produitId!);
    }
    _fetchTypesDeProduits();
  }

  Future<void> _chargerProduit(String produitId) async {
    setState(() => _isLoading = true);
    try {
      var doc = await FirebaseFirestore.instance.collection('produits').doc(produitId).get();
      if (doc.exists) {
        var data = doc.data();
        setState(() {
          nomController.text = data?['nom'] ?? '';
          prixController.text = (data?['prixVente'] ?? '').toString();
          quantiteController.text = (data?['quantite'] ?? '0').toString();
          seuilCritiqueController.text = (data?['seuil_critique'] ?? '50').toString();
          seuilAlerteController.text = (data?['seuil_alerte'] ?? '100').toString();
          codeBarreController.text = data?['code_barre'] ?? '';
          gammeController.text = data?['gamme'] ?? '';
          poidsController.text = (data?['poids'] ?? '').toString(); 
          marketPriceController.text = (data?['marketPrice'] ?? '').toString();
          descriptionController.text = data?['description'] ?? '';
          _selectedType = data?['type'];
          _image = data?['imageUrl']; 
          _selectedUnite = data?['unite'] ?? 'pcs'; 
          prixDecideController.text = (data?['prixDecide'] ?? '').toString();
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTypesDeProduits() async {
    var snapshot = await FirebaseFirestore.instance.collection('types_produits').get();
    setState(() {
      _typesDeProduits = snapshot.docs.map((doc) => doc['nom'].toString()).toList();
    });
  }

  void scannerCodeBarre() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Scanner Code-Barres"),
        content: SizedBox(
          width: 300,
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              if (capture.barcodes.isNotEmpty) {
                setState(() => codeBarreController.text = capture.barcodes.first.rawValue ?? "");
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),
    );
  }

  Future<File?> cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Rogner l\'image',
          toolbarColor: AppColors.accentColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Rogner l\'image'),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:  Icon(Icons.photo_library, color: AppColors.accentColor),
              title: const Text('Galerie'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) _processPickedImage(File(pickedFile.path));
              },
            ),
            ListTile(
              leading:  Icon(Icons.camera_alt, color: AppColors.accentColor),
              title: const Text('Appareil Photo'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) _processPickedImage(File(pickedFile.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPickedImage(File file) async {
    File? cropped = await cropImage(file);
    if (cropped != null) {
      File? webp = await convertImageToWebP(cropped);
      if (webp != null) setState(() => _image = webp);
    }
  }

  Future<String?> _uploadToFirebase(File file) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('produits/${DateTime.now().millisecondsSinceEpoch}.webp');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Erreur Upload: $e");
      return null;
    }
  }

  Future<void> enregistrerProduit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter une image')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (_image is File) {
        imageUrl = await _uploadToFirebase(_image as File);
        if (imageUrl == null) throw Exception("Échec de l'upload");
      } else {
        imageUrl = _image as String;
      }

      Map<String, dynamic> data = {
        'gamme': gammeController.text.trim(),
        'nom': nomController.text.trim(),
        'type': _selectedType,
        'prixVente': double.tryParse(prixController.text) ?? 0,
        'seuil_critique': int.tryParse(seuilCritiqueController.text) ?? 50,
        'seuil_alerte': int.tryParse(seuilAlerteController.text) ?? 100,
        'code_barre': codeBarreController.text.trim(),
        'imageUrl': imageUrl,
        'poids': int.tryParse(poidsController.text) ?? 0,
        'marketPrice': double.tryParse(marketPriceController.text) ?? 0,
        'description': descriptionController.text.trim(),
        'prixDecide': int.tryParse(prixDecideController.text) ?? 0,
        'quantite': double.tryParse(quantiteController.text) ?? 0,
        'unite': _selectedUnite,
      };

      String docId = widget.produitId ?? "${data['gamme']}_${data['nom']}";
      
      await FirebaseFirestore.instance.collection('produits').doc(docId).set(data, SetOptions(merge: true));

      // Mise à jour synchrone du PVP dans les stocks si modification
      if (data['prixDecide'] > 0) {
        await _updatePvpInStocks(data['nom'], data['prixDecide']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Produit enregistré !'), backgroundColor: AppColors.priceColor));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.criticalColor));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePvpInStocks(String nom, int newPvp) async {
    for (String col in ['stock', 'stockBoutique']) {
      final query = await FirebaseFirestore.instance.collection(col).where('nom', isEqualTo: nom).get();
      for (var doc in query.docs) {
        await doc.reference.update({'oldPvp': doc['pvp'], 'pvp': newPvp});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeaderSection(
                      title: widget.produitId == null ? 'Nouveau Produit' : 'Modifier Produit',
                      subtitle: 'Gérez les détails de l\'article',
                    ),
                    const SizedBox(height: 24),
                    
                    _buildImagePicker(),
                    const SizedBox(height: 32),

                    _sectionTitle('Informations Générales'),
                    _buildTextField(nomController, 'Nom du produit (Variété)', Icons.inventory_2_outlined),
                    _buildTextField(gammeController, 'Gamme / Marque', Icons.branding_watermark_outlined),
                    _buildTypeDropdown(),
                    _buildTextField(descriptionController, 'Description (Usage/Composition)', Icons.description_outlined, maxLines: 3),

                    const Divider(height: 48),
                    _sectionTitle('Prix & Stock'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(quantiteController, 'Quantité', Icons.numbers, keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildUniteDropdown()),
                      ],
                    ),
                    _buildTextField(marketPriceController, 'Prix Marché (FCFA)', Icons.store_outlined, keyboardType: TextInputType.number),
                    if (widget.produitId != null) 
                      _buildTextField(prixDecideController, 'Prix Décidé (FCFA)', Icons.check_circle_outline, keyboardType: TextInputType.number),

                    const Divider(height: 48),
                    _sectionTitle('Alertes & Technique'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(seuilCritiqueController, 'Seuil Critique', Icons.warning_amber_rounded, keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(seuilAlerteController, 'Seuil Alerte', Icons.notifications_active_outlined, keyboardType: TextInputType.number)),
                      ],
                    ),
                    _buildBarcodeField(),
                    _buildTextField(poidsController, 'Poids / Volume numérique', Icons.scale_outlined, keyboardType: TextInputType.number),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
            if (_isLoading) Container(color: Colors.black26, child:  Center(child: CircularProgressIndicator(color: AppColors.accentColor))),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style:  TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryTextColor)),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: pickImage,
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
          ),
          child: _image == null
              ?  Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.accentColor),
                    SizedBox(height: 8),
                    Text('Ajouter une photo', style: TextStyle(color: AppColors.secondaryTextColor)),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _image is File ? Image.file(_image as File, fit: BoxFit.cover) : Image.network(_image as String, fit: BoxFit.cover),
                      Positioned(
                        right: 8, top: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: pickImage),
                        ),
                      )
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.accentColor, size: 20),
          filled: true,
          fillColor: AppColors.cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
        ),
        validator: (v) => v!.isEmpty ? 'Requis' : null,
      ),
    );
  }

  Widget _buildBarcodeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: _buildTextField(codeBarreController, 'Code-Barres', Icons.qr_code_outlined)),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 56,
            width: 56,
            decoration: BoxDecoration(color: AppColors.accentColor, borderRadius: BorderRadius.circular(12)),
            child: IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.white), onPressed: scannerCodeBarre),
          )
        ],
      ),
    );
  }

  Widget _buildTypeDropdown() {
     return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedType,
        decoration: InputDecoration(
          labelText: 'Catégorie',
          prefixIcon:  Icon(Icons.category_outlined, color: AppColors.accentColor),
          filled: true, fillColor: AppColors.cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: [
          ..._typesDeProduits.map((t) => DropdownMenuItem(value: t, child: Text(t))),
           DropdownMenuItem(value: 'ADD_NEW', child: Text('+ Ajouter catégorie', style: TextStyle(color: AppColors.priceColor))),
        ],
        onChanged: (val) {
          if (val == 'ADD_NEW') _promptNewCategory();
          else setState(() => _selectedType = val);
        },
      ),
    );
  }

  Widget _buildUniteDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUnite,
      decoration: InputDecoration(
        labelText: 'Unité',
        filled: true, fillColor: AppColors.cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ['pcs', 'g', 'ml', 'kg', 'L'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (val) => setState(() => _selectedUnite = val),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isLoading ? null : enregistrerProduit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Enregistrer le Produit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _promptNewCategory() {
    String newCat = "";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle Catégorie'),
        content: TextField(onChanged: (v) => newCat = v.trim(), decoration: const InputDecoration(hintText: 'Nom...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              if (newCat.isNotEmpty) {
                await FirebaseFirestore.instance.collection('types_produits').doc(newCat).set({'nom': newCat});
                setState(() { _typesDeProduits.add(newCat); _selectedType = newCat; });
                Navigator.pop(ctx);
              }
            }, 
            child: const Text('Ajouter')
          ),
        ],
      )
    );
  }
}
