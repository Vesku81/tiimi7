import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import '../mallit/kysymys.dart';
import 'package:tietovisa/utils/vakiot.dart';
import 'package:dart_openai/dart_openai.dart'; // Tuodaan OpenAI-paketti

class TriviaApiPalvelu {
  final String _openAiApiKey = "API Avain"; // <-- VAIHDA TÄHÄN OMA API-AVAIMESI

  // Funktio, joka hakee kysymyksiä Trivia API:sta ja kääntää ne tarvittaessa
  Future<List<Kysymys>> haeKysymykset(int maara, String vaikeus, String kohdeKieli) async {
    try {
      final url = Uri.parse(
          '$apiBaseUrl/api.php?amount=$maara&difficulty=$vaikeus&type=multiple');
      final vastaus = await http.get(url);

      if (vastaus.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(vastaus.body);

        if (data['response_code'] == 0) {
          final unescape = HtmlUnescape();

          // Alustetaan OpenAI vain kerran, jos tarvitaan käännöstä
          if (kohdeKieli != 'en') {
            OpenAI.apiKey = _openAiApiKey;
          }

          List<Kysymys> kysymykset = [];
          for (var item in data['results']) {
            // Purkaa HTML-entiteetit ensin
            final alkuperainenKategoria = unescape.convert(item['category']);
            final alkuperainenKysymysTeksti = unescape.convert(item['question']);
            final alkuperainenOikeaVastaus = unescape.convert(item['correct_answer']);
            final alkuperaisetVaaratVastaukset = (item['incorrect_answers'] as List<dynamic>) // Varmistetaan tyyppi
                .map((vastaus) => unescape.convert(vastaus.toString())) // Muunnetaan Stringiksi varmuuden vuoksi
                .toList();

            // Käännetään vain jos kohdekieli ei ole englanti
            final kategoria = kohdeKieli != 'en' ? await kaannaTeksti(alkuperainenKategoria, kohdeKieli) : alkuperainenKategoria;
            final kysymysTeksti = kohdeKieli != 'en' ? await kaannaTeksti(alkuperainenKysymysTeksti, kohdeKieli) : alkuperainenKysymysTeksti;
            final oikeaVastaus = kohdeKieli != 'en' ? await kaannaTeksti(alkuperainenOikeaVastaus, kohdeKieli) : alkuperainenOikeaVastaus;
            final vaaratVastaukset = kohdeKieli != 'en' ? await Future.wait(alkuperaisetVaaratVastaukset.map((v) => kaannaTeksti(v, kohdeKieli))) : alkuperaisetVaaratVastaukset;

            kysymykset.add(Kysymys(
              kategoria: kategoria,
              tyyppi: item['type'],
              vaikeus: item['difficulty'],
              kysymysTeksti: kysymysTeksti,
              oikeaVastaus: oikeaVastaus,
              vaaratVastaukset: vaaratVastaukset.cast<String>(), // Varmistetaan tyyppi
            ));
          }

          return kysymykset;
        } else {
          // API palautti virhekoodin (response_code ei ollut 0)
          throw Exception('Trivia API palautti virhekoodin: ${data['response_code']}');
        }
      } else {
        // HTTP-pyyntö epäonnistui (statuskoodi ei ollut 200)
        throw Exception(
            'HTTP-vastaus Trivia API:sta epäonnistui. Statuskoodi: ${vastaus.statusCode}');
      }
    } catch (e) {
      // Käsitellään mahdolliset virheet ja tulostetaan debug-viesti konsoliin
      print('Virhe Trivia API:ssa tai käännöksessä: $e');
      throw Exception('Kysymysten haku tai käännös epäonnistui.');
    }
  }

  // Funktio tekstin kääntämiseen OpenAI:n avulla
  Future<String> kaannaTeksti(String teksti, String kohdeKieli) async {
    // Jos teksti on tyhjä tai kohdekieli on englanti, ei tarvitse kääntää
    if (teksti.isEmpty || kohdeKieli == 'en') {
      return teksti;
    }

    try {
      final chatCompletion = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo", // Voit kokeilla myös muita malleja
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: "Translate the following text to $kohdeKieli: $teksti",
            role: OpenAIChatMessageRole.user,
          ),
        ],
      );

      // Tarkistetaan, että vastaus onnistui ja sisältää sisältöä
      if (chatCompletion.choices.isNotEmpty) {
        return chatCompletion.choices.first.message.content;
      } else {
        print("OpenAI käännös palautti tyhjän vastauksen tekstille: $teksti");
        return teksti; // Palautetaan alkuperäinen teksti, jos käännös epäonnistui
      }

    } catch (e) {
      print("Virhe tekstin kääntämisessä OpenAI:lla: $e");
      return teksti; // Palautetaan alkuperäinen teksti virheen sattuessa
    }
  }
}