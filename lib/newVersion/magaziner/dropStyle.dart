import 'package:flutter/material.dart';

class ProductDropdownItem extends StatelessWidget {
  final String gamme;
  final String type;
  final String nom;
  final String poids;

  const ProductDropdownItem({
    required this.gamme,
    required this.type,
    required this.nom,
    required this.poids,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$gamme - $type',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text('$nom - $poids'),
      ],
    );
  }
}
