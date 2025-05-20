// trivia_api_palvelu.dart
import 'dart:convert'; // JSON-datan käsittely
import 'package:http/http.dart' as http; // HTTP-pyyntöihin
import 'package:html_unescape/html_unescape.dart'; // HTML-entiteettien purkamiseen
import '../mallit/kysymys.dart';
import 'package:tietovisa/utils/vakiot.dart'; // apiBaseUrl

class TriviaApiPalvelu {
  /// Hakee kysymyksiä perinteisestä Trivia API:sta.
  /// Lisätty `categoryId` valitun aihealueen rajaamiseen.
  Future<List<Kysymys>> haeKysymykset(int maara, String vaikeus, int categoryId) async {
    try {
      final uri = Uri.parse(
          '$apiBaseUrl/api.php?amount=$maara'
              '&category=$categoryId'
              '&difficulty=$vaikeus'
              '&type=multiple'
      );
      final vastaus = await http.get(uri);

      if (vastaus.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(vastaus.body);
        if (data['response_code'] == 0) {
          final unescape = HtmlUnescape();
          return (data['results'] as List)
              .map((jsonRaw) => Kysymys(
            kategoria: unescape.convert(jsonRaw['category']),
            tyyppi: jsonRaw['type'],
            vaikeus: jsonRaw['difficulty'],
            kysymysTeksti: unescape.convert(jsonRaw['question']),
            oikeaVastaus: unescape.convert(jsonRaw['correct_answer']),
            vaaratVastaukset: (jsonRaw['incorrect_answers'] as List)
                .map((ans) => unescape.convert(ans.toString()))
                .toList(),
          ))
              .toList();
        } else {
          throw Exception('API palautti virhekoodin: ${data['response_code']}');
        }
      } else {
        throw Exception('HTTP-vastaus epäonnistui. Statuskoodi: ${vastaus.statusCode}');
      }
    } catch (e) {
      print('Virhe Trivia API:ssa: $e');
      throw Exception('Kysymysten haku epäonnistui.');
    }
  }
}