import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({super.key});

  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outils Admin'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isUpdating ? null : () => _confirmAndUpdatePVPs(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isUpdating
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(width: 8),
                        Text('Mise à jour en cours...'),
                      ],
                    )
                  : const Text('Mettre à jour les PVP (1.3 → 1.45)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndUpdatePVPs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text(
          'Cette action va mettre à jour tous les PVP dans Firestore.\n\n'
          'Nouveau PVP = (1.45 × ancien PVP) / 1.3\n\n'
          'Êtes-vous sûr de vouloir continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      setState(() => _isUpdating = true);
      await _updateAllPVPs(context);
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateAllPVPs(BuildContext context) async {
    try {
      // 1. Mettre à jour les commandes
      await _updateCollectionPVPs(
        collection: 'commandes',
        arrayField: 'articles',
        pvpField: 'Pvp',
      );

      // 2. Mettre à jour le stock
      await _updateCollectionPVPs(
        collection: 'stock',
        pvpField: 'pvp',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tous les PVP ont été mis à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: ${e.toString()}')),
        );
      }
      rethrow;
    }
  }

  Future<void> _updateCollectionPVPs({
    required String collection,
    String? arrayField,
    required String pvpField,
  }) async {
    final firestore = FirebaseFirestore.instance;
    const batchSize = 400;
    var lastDocument;

    do {
      var query = firestore.collection(collection).limit(batchSize);
      if (lastDocument != null) query = query.startAfterDocument(lastDocument);

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;

      final batch = firestore.batch();

      for (final doc in snapshot.docs) {
        if (arrayField != null) {
          // Cas des commandes (tableau d'articles)
          final articles = doc.data()[arrayField] as List<dynamic>?;
          if (articles != null) {
            final updatedArticles = articles.map((article) {
              if (article is Map<String, dynamic>) {
                final oldPVP = (article[pvpField] as num?)?.toDouble();
                if (oldPVP != null) {
                  return {
                    ...article,
                    pvpField: _calculateNewPVP(oldPVP),
                  };
                }
              }
              return article;
            }).toList();

            batch.update(doc.reference, {arrayField: updatedArticles});
          }
        } else {
          // Cas simple (champ direct)
          final oldPVP = (doc.data()[pvpField] as num?)?.toDouble();
          if (oldPVP != null) {
            batch.update(doc.reference, {
              pvpField: _calculateNewPVP(oldPVP),
            });
          }
        }
      }

      await batch.commit();
      lastDocument = snapshot.docs.last;
      debugPrint('${snapshot.docs.length} documents mis à jour dans $collection');
    } while (true);
  }

  double _calculateNewPVP(double oldPVP) {
    // Applique la formule: (1.45 * ancienPVP) / 1.3
    // Puis arrondit au multiple de 25 supérieur
    final newPVP = (oldPVP * 1.45) / 1.3;
    return (newPVP / 25).ceil() * 25;
  }
}