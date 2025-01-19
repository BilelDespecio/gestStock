import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gest_stock/admin_dashboard.dart';
import 'package:gest_stock/approvisionnement.dart';
import 'package:gest_stock/auth_page.dart';
import 'package:gest_stock/dashboard.dart';
import 'package:gest_stock/destockage.dart';
import 'package:gest_stock/historique.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion de Stock',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthPage(),
        '/dashboard': (context) => DashboardPage(),
        '/approvisionnement': (context) => ApprovisionnementPage(), // À créer
        '/destockage': (context) => DestockagePage(), // À créer
        '/historique': (context) => HistoriquePage(), // À créer
        '/adminDashboard': (context) => AdminDashboard(), // À créer

      },
    );
  }
}
