import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../vendeur/constants.dart';

class AjouterUtilisateurPage extends StatefulWidget {
  @override
  _AjouterUtilisateurPageState createState() => _AjouterUtilisateurPageState();
}

class _AjouterUtilisateurPageState extends State<AjouterUtilisateurPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'vendeur'; 
  bool _isLoading = false;
  bool _obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, String> _roleLabels = {
    'admin': 'Administrateur',
    'user': 'Magasinier',
    'vendeur': 'Vendeur',
    'caissier': 'Caissier',
  };

  Future<void> _ajouterUtilisateur() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'nom': _nomController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Utilisateur ajouté avec succès !', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.priceColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.message}'), backgroundColor: AppColors.criticalColor),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: AppColors.criticalColor),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title:  Text('Nouveau Compte', style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardColor,
        iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
        elevation: 1,
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
                   Text('Identifiants de connexion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryTextColor)),
                  const SizedBox(height: 24),
                  
                  _buildTextField(
                    controller: _nomController,
                    label: 'Nom Complet',
                    icon: Icons.person_outline,
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email professionnel',
                    icon: Icons.alternate_email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v!.isEmpty || !v.contains('@')) ? 'Email invalide' : null,
                  ),
                  
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Mot de passe',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.secondaryTextColor),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) => v!.length < 6 ? 'Minimum 6 caractères' : null,
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 32),
                   Text('Rôle & Permissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryTextColor)),
                  const SizedBox(height: 16),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _roleLabels.keys.map((role) {
                      final isSelected = _selectedRole == role;
                      return ChoiceChip(
                        label: Text(_roleLabels[role]!),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRole = role);
                        },
                        selectedColor: AppColors.accentColor.withOpacity(0.2),
                        checkmarkColor: AppColors.accentColor,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.accentColor : AppColors.secondaryTextColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppColors.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? AppColors.accentColor : Colors.grey.shade200)
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(color: Colors.black26, child:  Center(child: CircularProgressIndicator(color: AppColors.accentColor))),
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
            onPressed: _isLoading ? null : _ajouterUtilisateur,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: const Text('Créer le compte utilisateur', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style:  TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryTextColor)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.accentColor, size: 20),
              suffixIcon: suffixIcon,
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
          ),
        ],
      ),
    );
  }
}
