import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../vendeur/constants.dart';

class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance.collection('client_contacts');
  bool _isLoading = false;

  // Contrôleurs
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _entrepriseController = TextEditingController();
  final _notesController = TextEditingController();

  bool _consentementPub = false;
  final List<String> _selectedChannels = [];

  final _canauxDisponibles = [
    'WhatsApp',
    'SMS',
    'Email',
    'Appel',
    'Newsletter',
  ];

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _entrepriseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _firestore.add({
          'nom': _nomController.text.trim(),
          'prenom': _prenomController.text.trim(),
          'telephone': _telephoneController.text.trim(),
          'email': _emailController.text.trim(),
          'entreprise': _entrepriseController.text.trim(),
          'notes': _notesController.text.trim(),
          'dateAjout': Timestamp.now(),
          'canauxCommunication': _selectedChannels,
          'consentementPub': _consentementPub,
          'statut': 'actif',
          'searchKeywords': [
            _nomController.text.trim().toLowerCase(),
            _prenomController.text.trim().toLowerCase(),
            _telephoneController.text.trim(),
          ],
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text('Contact ajouté avec succès !', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.priceColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: AppColors.criticalColor),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title:  Text('Nouveau Contact', style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardColor,
        iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
        elevation: 1,
        actions: [
          if (!_isLoading)
            IconButton(
              icon:  Icon(Icons.check, color: AppColors.priceColor, size: 28),
              onPressed: _submitForm,
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Informations personnelles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryTextColor)),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _prenomController,
                          label: 'Prénom',
                          icon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'Requis' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _nomController,
                          label: 'Nom',
                          validator: (v) => v!.isEmpty ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),
                  
                  _buildTextField(
                    controller: _telephoneController,
                    label: 'Téléphone',
                    icon: Icons.phone_android_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.alternate_email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  _buildTextField(
                    controller: _entrepriseController,
                    label: 'Entreprise (Optionnel)',
                    icon: Icons.business_outlined,
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 32),
                   Text('Préférences & Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryTextColor)),
                  const SizedBox(height: 16),

                   Text('Canaux de communication préférés :', style: TextStyle(fontSize: 13, color: AppColors.secondaryTextColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _canauxDisponibles.map((canal) {
                      final isSelected = _selectedChannels.contains(canal);
                      return FilterChip(
                        label: Text(canal),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedChannels.add(canal);
                            } else {
                              _selectedChannels.remove(canal);
                            }
                          });
                        },
                        selectedColor: AppColors.accentColor.withOpacity(0.2),
                        checkmarkColor: AppColors.accentColor,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.accentColor : AppColors.secondaryTextColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppColors.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSelected ? AppColors.accentColor : Colors.grey.shade200),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(color: AppColors.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                    child: SwitchListTile(
                      activeColor: AppColors.priceColor,
                      title: const Text('Consentement Marketing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Autoriser l\'envoi d\'offres promotionnelles', style: TextStyle(fontSize: 12)),
                      value: _consentementPub,
                      onChanged: (value) => setState(() => _consentementPub = value),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes internes',
                    icon: Icons.edit_note,
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 100), // Espace pour scroller au dessus du clavier
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child:  Center(child: CircularProgressIndicator(color: AppColors.accentColor)),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Enregistrer le contact', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style:  TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryTextColor)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: icon != null ? Icon(icon, color: AppColors.accentColor, size: 20) : null,
              filled: true,
              fillColor: AppColors.cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.accentColor, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style:  TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.w600),
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
          ),
        ],
      ),
    );
  }
}