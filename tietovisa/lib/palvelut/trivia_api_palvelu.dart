// palvelut/trivia_api_palvelu.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// Ei tarvitse Kysymys-importtia, koska palauttaa raakadataa

class TriviaApiPalvelu {
  final String _baseUrl = 'https://opentdb.com/api.php';

  // Metodi, joka palauttaa listan Map<String, dynamic> objekteja
  Future<List<dynamic>> haeKysymyksetRaaAllaDatalistana({
    required int amount,
    String? category, // API:n numeerinen kategoria ID (esim. "9" General Knowledge)
    String? difficulty, // "easy", "medium", "hard"
    String? type, // "multiple", "boolean"
  }) async {
    if (amount <= 0) return []; // Ei haeta, jos määrä on nolla tai negatiivinen

    // Muodosta URL ilman encode-parametria tai käyttäen toista, jos tarpeen.
    // Tässä oletetaan, että API palauttaa oletuksena UTF-8-muotoista dataa ilman erityistä enkoodausta.
    String url = '$_baseUrl?amount=$amount';

    if (category != null && category.isNotEmpty) {
      url += '&category=$category';
    }
    if (difficulty != null && difficulty.isNotEmpty && difficulty.toLowerCase() != "any") {
      url += '&difficulty=${difficulty.toLowerCase()}';
    }
    if (type != null && type.isNotEmpty) {
      url += '&type=$type';
    }

    debugPrint("Trivia API URL: $url");

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // On tärkeää varmistaa, että response.body tulkitaan oikein UTF-8:na,
        // jos API palauttaa erikoismerkkejä. http-paketti yleensä hoitaa tämän
        // Content-Type headerin perusteella, mutta joskus eksplisiittinen dekoodaus
        // utf8.decode(response.bodyBytes) voi olla tarpeen, jos merkit näkyvät väärin.
        // Tässä tapauksessa jsonDecode(response.body) pitäisi toimia, jos headerit ovat kunnossa.
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes)); // Käytä utf8.decode varmuuden vuoksi

        if (data['response_code'] == 0) {
          // response_code 0 tarkoittaa onnistunutta hakua
          // Data on nyt oletettavasti suoraan luettavassa muodossa ilman URL-enkoodausta.
          return data['results'] as List<dynamic>;
        } else {
          debugPrint('Trivia API palautti virhekoodin: ${data['response_code']}');
          // Voit halutessasi tulostaa myös viestin, jos API palauttaa sellaisen virhekoodin yhteydessä.
          // Esim. if (data.containsKey('message')) { debugPrint('Viesti: ${data['message']}'); }
          return []; // Palauta tyhjä lista virhetilanteessa
        }
      } else {
        debugPrint('Virhe Trivia API -kutsussa: ${response.statusCode}');
        debugPrint('Vastaus: ${response.body}');
        return [];
      }
    } catch (e, s) {
      debugPrint('Odottamaton virhe Trivia API -kysymysten haussa: $e\nStacktrace: $s');
      return [];
    }
  }
}