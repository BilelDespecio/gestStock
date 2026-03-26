import 'package:flutter/material.dart';
import '../constants.dart';

class HeaderSection extends StatelessWidget {
  final VoidCallback onPaidPressed;
  final VoidCallback onContactPressed;
  final VoidCallback onRefreshPressed;

  const HeaderSection({
    required this.onPaidPressed,
    required this.onContactPressed,
    required this.onRefreshPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tableau de bord',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Gérez vos ventes facilement',
              style: TextStyle(fontSize: 14, color: AppColors.secondaryTextColor),
            ),
          ],
        ),
        Row(
          children: [
            _ActionIconButton(icon: Icons.paid_outlined, onPressed: onPaidPressed),
            const SizedBox(width: 8),
            _ActionIconButton(icon: Icons.contact_phone_outlined, onPressed: onContactPressed),
            const SizedBox(width: 8),
            _ActionIconButton(icon: Icons.refresh, onPressed: onRefreshPressed),
          ],
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          )
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.secondaryTextColor),
        onPressed: onPressed,
      ),
    );
  }
}
