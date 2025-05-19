// palvelut/openai_palvelu.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../mallit/kysymys.dart'; // Tärkeä import

class OpenAIPalvelu {
  final String _apiKey = 'oma koodi'; // MUISTA TURVALLISUUS!
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<Kysymys?> generoiYksiKysymys(String aihe, String vaikeustaso) async {
    if (_apiKey == 'OMA_OPENAI_API_AVAIN_TÄHÄN' || _apiKey.isEmpty) {
      debugPrint("OpenAI API-avain puuttuu. Ei voida generoida kysymystä.");
      return null;
    }
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo-0125', // Tai uudempi malli
          'messages': [
            {
              'role': 'system',
              'content': '''Olet avulias tekoäly, joka generoi trivia-kysymyksiä.
Vastaa AINA VAIN JSON-objektilla, jossa on seuraavat avaimet: "kysymys_teksti", "oikea_vastaus", "vaarat_vastaukset" (lista kolmesta merkkijonosta).
Älä lisää mitään muuta tekstiä tai selityksiä vastaukseesi.
Esimerkki:
{
  "kysymys_teksti": "Mikä on Ranskan pääkaupunki?",
  "oikea_vastaus": "Pariisi",
  "vaarat_vastaukset": ["Lontoo", "Berliini", "Madrid"]
}'''
            },
            {
              'role': 'user',
              'content': 'Generoi YKSI trivia-kysymys aiheesta "$aihe" vaikeustasolla "$vaikeustaso".'
            }
          ],
          'temperature': 0.75,
          'max_tokens': 150,
          'response_format': { "type": "json_object" }, // Varmistaa JSON-muotoisen vastauksen content-kentässä
        }),
      );

      if (response.statusCode == 200) {
        final responseBodyString = utf8.decode(response.bodyBytes);
        debugPrint("OpenAI vastaus raakana (merkkijono): $responseBodyString");

        try {
          // 1. Jäsennä koko OpenAI:n vastaus
          final Map<String, dynamic> openAiResponseMap = jsonDecode(responseBodyString);

          // 2. Hae 'content'-kenttä, joka on merkkijono ja sisältää varsinaisen kysymys-JSON:in
          //    Lisätään turvatarkistuksia matkan varrelle.
          final choices = openAiResponseMap['choices'];
          if (choices is List && choices.isNotEmpty) {
            final firstChoice = choices[0];
            if (firstChoice is Map) {
              final message = firstChoice['message'];
              if (message is Map) {
                final content = message['content'];
                if (content is String) {
                  final String contentString = content;
                  debugPrint("OpenAI content-merkkijono: $contentString");

                  // 3. Jäsennä 'content'-merkkijono varsinaiseksi kysymysdataksi
                  final Map<String, dynamic> questionData = jsonDecode(contentString);
                  debugPrint("OpenAI jäsennetty kysymysdata: $questionData");

                  // Tarkista, että tarvittavat kentät löytyvät nyt questionData-mapista
                  if (questionData.containsKey('kysymys_teksti') &&
                      questionData.containsKey('oikea_vastaus') &&
                      questionData.containsKey('vaarat_vastaukset') &&
                      questionData['vaarat_vastaukset'] is List &&
                      (questionData['vaarat_vastaukset'] as List).isNotEmpty) { // Vähintään yksi väärä vastaus riittää

                    return Kysymys(
                      // ID ja lisäyspäivämäärä luodaan Kysymys-konstruktorissa oletuksena
                      kysymysTeksti: questionData['kysymys_teksti'] as String,
                      oikeaVastaus: questionData['oikea_vastaus'] as String,
                      vaaratVastaukset: List<String>.from(questionData['vaarat_vastaukset'] as List<dynamic>),
                      // kategoria ja vaikeus asetetaan TriviaTarjoajassa,
                      // koska ne tiedetään siellä paremmin kontekstin perusteella
                      lahde: "openai_generoitu", // Lähde asetetaan tässä
                    );
                  } else {
                    debugPrint('OpenAI content-JSON ei sisältänyt kaikkia vaadittuja kenttiä tai väärät vastaukset oli virheellinen.');
                    debugPrint('Vastaanotettu content-data (jäsennettynä): $questionData');
                    return null;
                  }
                } else {
                  debugPrint('OpenAI-vastauksen message.content ei ollut merkkijono.');
                  debugPrint('Vastaanotettu message.content: $content');
                  return null;
                }
              } else {
                debugPrint('OpenAI-vastauksen choices[0].message ei ollut Map.');
                return null;
              }
            } else {
              debugPrint('OpenAI-vastauksen choices[0] ei ollut Map.');
              return null;
            }
          } else {
            debugPrint('OpenAI-vastauksen choices-lista oli tyhjä tai ei ollut lista.');
            return null;
          }
        } catch (e, s) {
          debugPrint('Virhe JSON-datan purkamisessa OpenAI-vastauksesta: $e\nStacktrace: $s');
          debugPrint('Käsiteltävä responseBodyString: $responseBodyString');
          return null;
        }
      } else {
        debugPrint('Virhe OpenAI API -kutsussa: ${response.statusCode}');
        debugPrint('Vastaus: ${response.body}'); // response.body on jo merkkijono
        return null;
      }
    } catch (e, s) {
      debugPrint('Odottamaton virhe OpenAI-kysymyksen generoinnissa: $e\nStacktrace: $s');
      return null;
    }
  }
}