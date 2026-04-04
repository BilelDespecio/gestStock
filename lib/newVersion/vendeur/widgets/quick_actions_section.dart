import 'package:flutter/material.dart';
import '../constants.dart';

class QuickActionData {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  QuickActionData({required this.title, required this.icon, required this.onTap, this.color});
}

class QuickActionsSection extends StatelessWidget {
  final List<QuickActionData> actions;

  const QuickActionsSection({required this.actions});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions.map((action) => Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: _QuickActionCard(
            title: action.title,
            icon: action.icon,
            onTap: action.onTap,
            color: action.color,
          ),
        )).toList(),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _QuickActionCard({required this.title, required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.04),
              spreadRadius: 2,
              blurRadius: 8,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color ?? AppColors.accentColor, size: 24),
            const SizedBox(width: 10),
            Text(
              title, 
              style:  TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTextColor, fontSize: 13)
            ),
          ],
        ),
      ),
    );
  }
}
