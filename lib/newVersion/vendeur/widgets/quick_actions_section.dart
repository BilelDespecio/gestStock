import 'package:flutter/material.dart';
import '../constants.dart';

class QuickActionsSection extends StatelessWidget {
  final VoidCallback onHistoryTap;
  final VoidCallback onSaleTap;

  const QuickActionsSection({required this.onHistoryTap, required this.onSaleTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _QuickActionCard(title: 'Historique', icon: Icons.history, onTap: onHistoryTap)),
        const SizedBox(width: 16),
        Expanded(child: _QuickActionCard(title: 'Faire une vente', icon: Icons.point_of_sale_outlined, onTap: onSaleTap)),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.05),
              spreadRadius: 2,
              blurRadius: 10,
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accentColor, size: 32),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title, 
                textAlign: TextAlign.center, 
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryTextColor)
              )
            ),
          ],
        ),
      ),
    );
  }
}
