import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance.collection('client_contacts');

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
    'Email',
    'SMS',
    'WhatsApp',
    'Appel téléphonique',
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
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact ajouté avec succès!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Contact Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitForm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextFormField(
                controller: _nomController,
                label: 'Nom*',
                validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
              ),
              _buildTextFormField(
                controller: _prenomController,
                label: 'Prénom*',
                validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
              ),
              _buildTextFormField(
                controller: _telephoneController,
                label: 'Téléphone*',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value!.isEmpty) return 'Obligatoire';
                  if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value)) {
                    return 'Numéro invalide';
                  }
                  return null;
                },
              ),
              _buildTextFormField(
                controller: _emailController,
                label: 'Email*',
                keyboardType: TextInputType.emailAddress,

              ),
              _buildTextFormField(
                controller: _entrepriseController,
                label: 'Entreprise',
              ),
              _buildTextFormField(
                controller: _notesController,
                label: 'Notes',
                maxLines: 3,
              ),

              const SizedBox(height: 20),
              const Text('Canaux de communication préférés:'),
              Wrap(
                spacing: 8,
                children: _canauxDisponibles.map((canal) {
                  return FilterChip(
                    label: Text(canal),
                    selected: _selectedChannels.contains(canal),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedChannels.add(canal);
                        } else {
                          _selectedChannels.remove(canal);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Consentement pour publicité'),
                subtitle: const Text('Le client accepte de recevoir des offres promotionnelles'),
                value: _consentementPub,
                onChanged: (value) => setState(() => _consentementPub = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }
}