// TriviaApiPalvelu luokka vastaa Trivia API:n kysymysten hakemisesta ja datan käsittelystä
import 'dart:convert'; // JSON-datan käsittelyyn
import 'package:http/http.dart' as http; // HTTP-pyyntöjen tekemiseen
import 'package:html_unescape/html_unescape.dart'; // HTML-entiteettien purkamiseen
import '../mallit/kysymys.dart'; // Kysymys-malliluokan tuonti
import 'package:tietovisa/utils/vakiot.dart'; // API-perus URL:n tuonti

class TriviaApiPalvelu {
  // Funktio, joka hakee kysymyksiä Trivia API:sta parametrien perusteella, esim. "määrä", "vaikeustaso" (helppo/easy, keskitaso/medium tai vaikea/hard).
  Future<List<Kysymys>> haeKysymykset(int maara, String vaikeus, int categoryId) async {
    try {
      // Rakennetaan URL API-pyyntöä varten
      final url = Uri.parse(
          '$apiBaseUrl/api.php?amount=$maara&difficulty=$vaikeus&category=$categoryId&type=multiple');
      final vastaus = await http.get(url); // Suoritetaan HTTP GET -pyyntö

      // Tarkistetaan, että HTTP-vastaus onnistui
      if (vastaus.statusCode == 200) {
        // Parsitaan JSON-data vastauksesta
        final Map<String, dynamic> data = json.decode(vastaus.body);

        // Tarkistetaan, että response_code on 0, joka tarkoittaa, että API palautti datan onnistuneesti)
        if (data['response_code'] == 0) {
          final unescape = HtmlUnescape(); // Luodaan instanssi HTML-entiteettien purkamiseen

          // Käydään API rajapinnan palauttama data läpi ja muunnetaan se Kysymys-olioiksi
          List<Kysymys> kysymykset = (data['results'] as List)
              .map((json) => Kysymys(
            kategoria: unescape.convert(
                json['category']), // Purkaa mahdolliset HTML-entiteetit kategoriasta
            tyyppi: json['type'], // Kysymyksen tyyppi (esim. monivalinta/multiple choice)
            vaikeus: json['difficulty'], // Vaikeustaso
            kysymysTeksti: unescape
                .convert(json['question']), // Purkaa kysymyksen tekstin.
            oikeaVastaus: unescape.convert(
                json['correct_answer']), // Purkaa oikean vastauksen
            vaaratVastaukset: (json['incorrect_answers'] as List)
                .map((vastaus) => unescape.convert(
                vastaus)) // Purkaa kaikki väärät vastaukset
                .toList(),
          ))
              .toList();

          return kysymykset; // Palautetaan lista kysymyksistä
        } else {
          // API palautti virhekoodin (response_code ei ollut 0)
          throw Exception('API palautti virhekoodin: ${data['response_code']}');
        }
      } else {
        // HTTP-pyyntö epäonnistui (statuskoodi ei ollut 200)
        throw Exception(
            'HTTP-vastaus epäonnistui. Statuskoodi: ${vastaus.statusCode}');
      }
    } catch (e) {
      // Käsitellään mahdolliset virheet ja tulostetaan debug-viesti konsoliin
      print('Virhe Trivia API:ssa: $e');
      throw Exception('Kysymysten haku epäonnistui.');
    }
  }
}
