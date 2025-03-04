import 'package:flutter/material.dart';

class ImageZoomPage extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const ImageZoomPage({Key? key, required this.imageUrl, required this.tag}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer( // Permet de zoomer et de déplacer l'image
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
