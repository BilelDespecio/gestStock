import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:gest_stock/newVersion/menu/theme_controller.dart';
import 'newVersion/contact/add_contact_page.dart';
import 'newVersion/contact/contact_list_page.dart';

import 'package:flutter_downloader/flutter_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialisation du downloader pour les mises à jour
  await FlutterDownloader.initialize(
    debug: true, 
    ignoreSsl: true 
  );

  await Supabase.initialize(
    url: 'https://urznwnznbzfhrsmsdpvu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyem53bnpuYnpmaHJzbXNkcHZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2NjIwNjAsImV4cCI6MjA4OTIzODA2MH0.1rAkb0ux2y3z9R8ikmVpuTWJAmXJkxs0IjkpOQhhrWc',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR')],
          debugShowCheckedModeBanner: false,
          title: 'Gestion de Stock',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
              surface: const Color(0xFFF8F9FC),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
              surface: const Color(0xFF121212),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F1F1F),
              elevation: 0,
            ),
          ),
          themeMode: themeController.themeMode,
          initialRoute: '/',
          routes: {
            '/homePageMagazinier': (context) => HomePageMagazinier(),
            '/orderForm': (context) => OrderForm(),
            '/gererCommandes': (context) => GestionCommandesPage(),
            '/ventesValidees': (context) => VentesValideesPage(),
            '/ventesEffectuees': (context) => VentesEffectueesPage(),
            '/chargerBoutique': (context) => ChargerBoutiquePage(),
            '/homePageAdmin': (context) => HomePageAdmin(),
            '/addProduct': (context) => AjouterProduitPage(),
            '/stats': (context) => StatistiquesPage(),
            '/addAccount': (context) => AjouterUtilisateurPage(),
            '/homePageCaisier': (context) => AccueilCaissierPage(),
            '/homePageVendeur': (context) => HomePageVendeur(),
            '/vente': (context) => VentePage(),
            '/': (context) => AuthPage(),
            '/approvisionnement': (context) => ApprovisionnementPage(),
            '/destockage': (context) => DestockagePage(),
            '/historique': (context) => HistoriquePage(),
            '/contacts': (context) => const ContactsListPage(),
            '/contacts/add': (context) => const AddContactPage(),
          },
        );
      }
    );
  }
}
