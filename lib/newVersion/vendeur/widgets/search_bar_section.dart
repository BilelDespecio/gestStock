import 'package:flutter/material.dart';
import '../constants.dart';

class SearchBarSection extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onScanPressed;

  const SearchBarSection({required this.controller, required this.onChanged, required this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4)
                )
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration:  InputDecoration(
                hintText: 'Rechercher un produit...',
                hintStyle: TextStyle(color: AppColors.secondaryTextColor),
                prefixIcon: Icon(Icons.search, color: AppColors.accentColor),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4)
              )
            ]
          ),
          child: IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white), 
            onPressed: onScanPressed, 
            tooltip: "Scanner un QR Code", 
            iconSize: 28
          ),
        ),
      ],
    );
  }
}
