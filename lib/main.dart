import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
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
//import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'newVersion/contact/add_contact_page.dart';
import 'newVersion/contact/contact_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await FlutterDownloader.initialize(debug: true);
  // Initialisation de Firebase
  await Firebase.initializeApp();

  // Initialisation de Supabase avec les variables du .env
  /*await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,  // URL depuis .env
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,  // Anon key depuis .env
  );*/
  // Initialisation de Supabase
  await Supabase.initialize(
    url:
        'https://urznwnznbzfhrsmsdpvu.supabase.co', // Remplace par ton URL Supabase
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyem53bnpuYnpmaHJzbXNkcHZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2NjIwNjAsImV4cCI6MjA4OTIzODA2MH0.1rAkb0ux2y3z9R8ikmVpuTWJAmXJkxs0IjkpOQhhrWc', // Remplace par ta clé anonyme
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // Nécessaire pour DatePicker
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations
            .delegate, // Si vous utilisez des widgets Cupertino
      ],
      supportedLocales: const [Locale('fr', 'FR')], // Français par défaut
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

        '/contacts': (context) => const ContactsListPage(),
        '/contacts/add': (context) => const AddContactPage(),
      },
    );
  }
}
