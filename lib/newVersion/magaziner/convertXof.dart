import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyConverter {
  static const String apiKey = "05c5185049495eff0b732f0c"; //clé API
  static const String baseUrl = "https://v6.exchangerate-api.com/v6/";

  // Fonction pour convertir NGN vers XOF
  static Future<double> convertNGNtoXOF(double amount) async {
    final url = Uri.parse("$baseUrl$apiKey/latest/NGN");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final rate = data["conversion_rates"]["XOF"];

      if (rate != null) {
        return amount * rate;
      } else {
        throw Exception("Taux de conversion non trouvé.");
      }
    } else {
      throw Exception("Erreur lors de la récupération des taux.");
    }
  }
}
