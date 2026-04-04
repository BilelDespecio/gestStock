import 'package:flutter/material.dart';
import '../constants.dart';

class HeaderSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<HeaderAction>? actions;

  const HeaderSection({
    this.title = 'Tableau de bord',
    this.subtitle = 'Gérez vos ventes facilement',
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:  TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style:  TextStyle(fontSize: 14, color: AppColors.secondaryTextColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (actions != null && actions!.isNotEmpty)
          Row(
            children: actions!.map((action) => Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: _ActionIconButton(icon: action.icon, onPressed: action.onPressed, color: action.color),
            )).toList(),
          ),
      ],
    );
  }
}

class HeaderAction {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  HeaderAction({required this.icon, required this.onPressed, this.color});
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionIconButton({required this.icon, required this.onPressed, this.color});

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
        icon: Icon(icon, color: color ?? AppColors.secondaryTextColor),
        onPressed: onPressed,
      ),
    );
  }
}
