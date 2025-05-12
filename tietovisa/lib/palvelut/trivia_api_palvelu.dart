import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import '../mallit/kysymys.dart';
import 'package:tietovisa/utils/vakiot.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Tuodaan shared_preferences

class TriviaApiPalvelu {

  final String _openAiApiKey = "oma api avain"; // <-- VAIHDA TÄHÄN OMA API-AVAIMESI


  // Funktio, joka hakee kysymykset Trivia API:sta, kääntää ne tarvittaessa ja tallentaa/hakee paikallisesti
  Future<List<Kysymys>> haeKysymykset(int maara, String vaikeus, String kohdeKieli) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Luodaan tallennusavain, joka perustuu kysymysten määrään, vaikeuteen ja kohdekieleen
    final String tallennusAvain = 'trivia_kysymykset_${maara}_${vaikeus}_$kohdeKieli';

    // Yritetään hakea kysymykset paikallisesta tallennuksesta ensin
    final String? tallennettuData = prefs.getString(tallennusAvain);
    if (tallennettuData != null) {
      try {
        final List<dynamic> jsonList = json.decode(tallennettuData);
        // Muunnetaan JSON-lista Kysymys-objekteiksi
        List<Kysymys> paikallisetKysymykset = jsonList.map((json) => Kysymys.fromJson(json)).toList();
        print('Kysymykset ladattu paikallisesta tallennuksesta.');
        return paikallisetKysymykset;
      } catch (e) {
        print('Virhe paikallisen datan purkamisessa: $e');
        // Jatka API-kutsuun, jos paikallinen data on virheellinen
      }
    }

    // Jos paikallista dataa ei löytynyt tai se oli virheellinen, haetaan API:sta
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
            final alkuperainenKategoria = unescape.convert(item['category']);
            final alkuperainenKysymysTeksti = unescape.convert(item['question']);
            final alkuperainenOikeaVastaus = unescape.convert(item['correct_answer']);
            final alkuperaisetVaaratVastaukset = (item['incorrect_answers'] as List<dynamic>)
                .map((vastaus) => unescape.convert(vastaus.toString()))
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
              vaaratVastaukset: vaaratVastaukset.cast<String>(),
            ));
          }

          // Tallennetaan käännetyt kysymykset paikallisesti
          final List<Map<String, dynamic>> jsonList = kysymykset.map((kysymys) => kysymys.toJson()).toList();
          await prefs.setString(tallennusAvain, json.encode(jsonList));
          print('Käännetyt kysymykset tallennettu paikallisesti.');

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

  // Funktio tekstin kääntämiseen OpenAI:n avulla (sama kuin aiemmin)
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