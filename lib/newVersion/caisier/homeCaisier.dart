import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../vendeur/constants.dart';
import 'details_vente_page.dart';
import 'package:gest_stock/newVersion/menu/app_menu_sheet.dart';

class AccueilCaissierPage extends StatefulWidget {
  @override
  _AccueilCaissierPageState createState() => _AccueilCaissierPageState();
}

class _AccueilCaissierPageState extends State<AccueilCaissierPage> {
  String _searchQuery = '';
  DateTime? _selectedDate;
  String _statusFilter = 'Toutes'; // 'Toutes', 'En attente', 'Validées'
  
  bool _isSelectionMode = false;
  Set<String> _selectedVentesIds = {};
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:  ColorScheme.light(
              primary: AppColors.accentColor,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedVentesIds.contains(id)) {
        _selectedVentesIds.remove(id);
        if (_selectedVentesIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedVentesIds.add(id);
      }
    });
  }

  Future<void> _validerLot() async {
    if (_selectedVentesIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:  Text('Validation par lot', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTextColor)),
        content: Text('Voulez-vous vraiment valider ${_selectedVentesIds.length} vente(s) sans envoyer de reçu WhatsApp immédiat ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:  Text('Annuler', style: TextStyle(color: AppColors.secondaryTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (String id in _selectedVentesIds) {
        final docRef = FirebaseFirestore.instance.collection('ventes').doc(id);
        batch.update(docRef, {'statut': 'validé'});
      }
      await batch.commit();

      if (mounted) {
        setState(() {
          _selectedVentesIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Ventes validées avec succès !', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: AppColors.priceColor),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la validation en lot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.criticalColor),
        );
      }
    }
  }

  Stream<QuerySnapshot> _buildStream() {
    Query query = FirebaseFirestore.instance.collection('ventes').orderBy('date', descending: true);
    
    // Filtre par Date directement dans la base de données
    if (_selectedDate != null) {
      final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay));
    }
    
    // Filtre par statut si ce n'est pas "Toutes"
    if (_statusFilter == 'En attente') {
      query = query.where('statut', isEqualTo: 'en attente');
    } else if (_statusFilter == 'Validées') {
      query = query.where('statut', isEqualTo: 'validé');
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title:  Text('Caisse & Ventes', style: TextStyle(color: AppColors.primaryTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardColor,
        iconTheme:  IconThemeData(color: AppColors.primaryTextColor),
        elevation: 1,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon:  Icon(Icons.clear, color: AppColors.criticalColor),
              tooltip: 'Annuler la sélection',
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedVentesIds.clear();
              }),
            ),
          IconButton(
            icon: Icon(Icons.calendar_today_outlined, color: _selectedDate != null ? AppColors.accentColor : AppColors.secondaryTextColor),
            onPressed: _selectDate,
            tooltip: 'Sélectionner une date',
          ),
          if (_selectedDate != null)
            IconButton(
              icon:  Icon(Icons.event_busy, color: AppColors.criticalColor),
              tooltip: 'Supprimer le filtre de date',
              onPressed: () => setState(() => _selectedDate = null),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode && _selectedVentesIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _validerLot,
              backgroundColor: AppColors.priceColor,
              icon: const Icon(Icons.fact_check, color: Colors.white),
              label: Text('Valider (${_selectedVentesIds.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          // En-tête: Recherche et Filtres
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher (ID, Client, Vendeur)...',
                    hintStyle:  TextStyle(color: AppColors.secondaryTextColor),
                    prefixIcon:  Icon(Icons.search, color: AppColors.accentColor),
                    filled: true,
                    fillColor: AppColors.backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Toutes', 'En attente', 'Validées'].map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          selectedColor: AppColors.accentColor.withOpacity(0.15),
                          backgroundColor: AppColors.backgroundColor,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.accentColor : AppColors.secondaryTextColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _statusFilter = status;
                                _isSelectionMode = false;
                                _selectedVentesIds.clear();
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Liste dynamique
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return  Center(child: CircularProgressIndicator(color: AppColors.accentColor));
                }

                final searchLower = _searchQuery.toLowerCase();
                final ventes = snapshot.data!.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
                    .where((vente) {
                  if (searchLower.isEmpty) return true;
                  final id = vente['id']?.toString().toLowerCase() ?? '';
                  final client = vente['client']?.toString().toLowerCase() ?? '';
                  final vendeur = vente['vendeurNom']?.toString().toLowerCase() ?? '';
                  return id.contains(searchLower) || client.contains(searchLower) || vendeur.contains(searchLower);
                }).toList();

                // Tri local supplémentaire si "Toutes" (En attente en premier)
                if (_statusFilter == 'Toutes') {
                  ventes.sort((a, b) {
                    if (a['statut'] == 'en attente' && b['statut'] != 'en attente') return -1;
                    if (a['statut'] != 'en attente' && b['statut'] == 'en attente') return 1;
                    return 0;
                  });
                }

                if (ventes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 60, color: AppColors.secondaryTextColor.withOpacity(0.5)),
                        const SizedBox(height: 16),
                         Text('Aucune vente trouvée', style: TextStyle(color: AppColors.secondaryTextColor, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80), // Espace pour le FAB
                  itemCount: ventes.length,
                  itemBuilder: (context, index) {
                    final vente = ventes[index];
                    final id = vente['id'];
                    final num montantTotal = vente['montantTotal'] ?? 0;
                    final statut = vente['statut'];
                    final dateVente = vente['date'] != null ? (vente['date'] as Timestamp).toDate() : null;
                    
                    final bool isEnAttente = statut == 'en attente';
                    final bool isSelected = _selectedVentesIds.contains(id);

                    return GestureDetector(
                      onLongPress: isEnAttente ? () {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedVentesIds.add(id);
                        });
                      } : null,
                      onTap: () {
                        if (_isSelectionMode) {
                          if (isEnAttente) _toggleSelection(id);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DetailsVentePage(venteId: id, vente: vente)),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentColor.withOpacity(0.05) : AppColors.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? AppColors.accentColor : Colors.grey.shade100, width: isSelected ? 2 : 1),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: _isSelectionMode && isEnAttente
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (val) => _toggleSelection(id),
                                  activeColor: AppColors.accentColor,
                                )
                              : Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isEnAttente ? AppColors.alertColor.withOpacity(0.1) : AppColors.priceColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isEnAttente ? Icons.hourglass_top : Icons.check_circle,
                                    color: isEnAttente ? AppColors.alertColor : AppColors.priceColor,
                                  ),
                                ),
                          title: Text(
                            'Vente #$id',
                            style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTextColor),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${montantTotal.toStringAsFixed(0)} FCFA',
                                style:  TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentColor, fontSize: 15),
                              ),
                              if (dateVente != null)
                                Text(
                                  _dateFormat.format(dateVente),
                                  style:  TextStyle(fontSize: 12, color: AppColors.secondaryTextColor),
                                ),
                            ],
                          ),
                          trailing: !_isSelectionMode
                              ?  Icon(Icons.chevron_right, color: AppColors.secondaryTextColor)
                              : null,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
