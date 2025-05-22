// trivia_api_palvelu.dart

import 'dart:convert'; // JSON-käsittelyyn
import 'package:http/http.dart' as http; // HTTP-pyyntöihin
import 'package:html_unescape/html_unescape.dart'; // HTML-entiteettien purkamiseen
import '../mallit/kysymys.dart';
import 'package:tietovisa/utils/vakiot.dart'; // apiBaseUrl

/// Tämä palvelu hakee kysymyksiä Open Trivia DB -rajapinnasta.
/// Parametrina annetaan:
/// - `maara`       : montako kysymystä halutaan
/// - `vaikeus`     : "easy", "medium" tai "hard"
/// - `categoryId`  : numeroinen tunniste aihealueelle
class TriviaApiPalvelu {
  Future<List<Kysymys>> haeKysymykset(
      int maara,
      String vaikeus,
      int categoryId,
      ) async {
    try {
      // 1) Rakennetaan pyyntö-URI, mukaan luettuna category-parametri.
      final uri = Uri.parse(
        '$apiBaseUrl/api.php?amount=$maara'
            '&category=$categoryId'
            '&difficulty=$vaikeus'
            '&type=multiple',
      );

      // 2) Lähetetään GET-pyyntö Trivia API:lle
      final vastaus = await http.get(uri);

      // 3) Tarkistetaan, että palautuskoodi on 200 (OK)
      if (vastaus.statusCode == 200) {
        // 4) Parsitaan JSON-vastaus
        final Map<String, dynamic> data = json.decode(vastaus.body);

        // 5) Tarkistetaan, että API:n oma response_code on 0 (onnistunut)
        if (data['response_code'] == 0) {
          final unescape = HtmlUnescape();

          // 6) Muunnetaan jokainen tulos JSONista Kysymys-olioksi
          return (data['results'] as List)
              .map((jsonRaw) => Kysymys(
            kategoria: unescape.convert(jsonRaw['category']),     // puretaan HTML-entiteetit
            tyyppi: jsonRaw['type'],                               // monivalinta tms.
            vaikeus: jsonRaw['difficulty'],                        // vaikeustaso
            kysymysTeksti: unescape.convert(jsonRaw['question']), // kysymysteksti
            oikeaVastaus: unescape.convert(jsonRaw['correct_answer']),
            vaaratVastaukset: (jsonRaw['incorrect_answers'] as List)
                .map((ans) => unescape.convert(ans.toString()))
                .toList(),                                       // väärät vaihtoehdot
          ))
              .toList();
        } else {
          // jos API ilmoittaa virhekoodin, heitetään poikkeus
          throw Exception('API palautti virhekoodin: ${data['response_code']}');
        }
      } else {
        // HTTP-virhe
        throw Exception(
            'HTTP-vastaus epäonnistui. Statuskoodi: ${vastaus.statusCode}');
      }
    } catch (e) {
      // Kaikki virheet tiputetaan konsoliin ja heitetään eteenpäin
      print('Virhe Trivia API:ssa: $e');
      throw Exception('Kysymysten haku epäonnistui.');
    }
  }
}
