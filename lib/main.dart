import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:gest_stock/newVersion/admin/add_account.dart';
import 'package:gest_stock/newVersion/magaziner/addStockShop.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/admin/add_product.dart';
import 'package:gest_stock/newVersion/admin/admin_dashboard.dart';
import 'package:gest_stock/approvisionnement.dart';
import 'package:gest_stock/auth_page.dart';
import 'package:gest_stock/destockage.dart';
import 'package:gest_stock/newVersion/admin/stats.dart';
import 'package:gest_stock/newVersion/caisier/homeCaisier.dart';
import 'package:gest_stock/newVersion/magaziner/ventes_effectue.dart';
import 'package:gest_stock/newVersion/magaziner/ventes_valides.dart';
import 'package:gest_stock/newVersion/vendeur/historique.dart';
import 'package:gest_stock/newVersion/magaziner/do_commande.dart';
import 'package:gest_stock/newVersion/magaziner/home.dart';
import 'package:gest_stock/newVersion/magaziner/manage_commande.dart';
import 'package:gest_stock/newVersion/vendeur/home.dart';
import 'package:gest_stock/newVersion/vendeur/vente.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 //await FlutterDownloader.initialize(debug: true);
  // 🔥 Initialisation de Firebase
  await Firebase.initializeApp();

  // 🔥 Initialisation de Supabase
  await Supabase.initialize(
    url: 'https://hhsccylhbebllyqlihus.supabase.co',  // Remplace par ton URL Supabase
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhoc2NjeWxoYmVibGx5cWxpaHVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk1NDU5MjEsImV4cCI6MjA1NTEyMTkyMX0.genT5pILxWFnmFXvgLlX-nOUdQBw7AScyo55McW0ah4',  // Remplace par ta clé anonyme
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestion de Stock',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        //magasinier
        '/homePageMagazinier': (context) => HomePageMagazinier(),
        '/orderForm': (context) => OrderForm(),
        '/gererCommandes': (context) => GestionCommandesPage(),
        '/ventesValidees': (context) => VentesValideesPage(),
        '/ventesEffectuees': (context) => VentesEffectueesPage(),
        '/chargerBoutique': (context) => ChargerBoutiquePage(),

        //admin
        '/homePageAdmin': (context) => HomePageAdmin(),
        '/addProduct': (context) => AjouterProduitPage(),
        '/stats': (context) => StatistiquesPage(),
        '/addAccount': (context) => AjouterUtilisateurPage(),

        //caisier
        '/homePageCaisier': (context) => AccueilCaissierPage(),

        //vendeur
        '/homePageVendeur': (context) => HomePageVendeur(),
        '/vente': (context) => VentePage(),

        '/': (context) => AuthPage(),
        '/approvisionnement': (context) => ApprovisionnementPage(),
        '/destockage': (context) => DestockagePage(),
        '/historique': (context) => HistoriquePage(),

      },
    );
  }
}
