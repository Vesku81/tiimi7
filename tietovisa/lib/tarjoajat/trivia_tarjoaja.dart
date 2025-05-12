import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import '../mallit/kysymys.dart';
import 'package:tietovisa/utils/vakiot.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // Tuodaan Provider
import 'asetukset_tarjoaja.dart'; // Tuodaan AsetuksetTarjoaja
import 'package:flutter/material.dart'; // Tuodaan BuildContextia varten

// Korjattu: Peritään ChangeNotifier
class TriviaTarjoaja extends ChangeNotifier {
  final String _openAiApiKey = "oma api avain"; // <-- VAIHDA TÄHÄN OMA API-AVAIMESI

  List<Kysymys> _kysymykset = [];
  int _nykyinenIndeksi = 0;
  int _pisteet = 0;
  bool _onLataus = false;
  String? _virhe;

  List<Kysymys> get kysymykset => _kysymykset;
  int get nykyinenIndeksi => _nykyinenIndeksi;
  int get pisteet => _pisteet;
  bool get onLataus => _onLataus;
  String? get virhe => _virhe;

  // Funktio, joka hakee kysymyksiä Trivia API:sta, kääntää ne tarvittaessa ja tallentaa/hakee paikallisesti
  Future<void> haeKysymykset(int maara, String vaikeus, BuildContext context) async {
    _onLataus = true;
    _virhe = null;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Haetaan kohdekieli AsetuksetTarjoajasta tallennusavainta varten
    final String kohdeKieli = Provider.of<AsetuksetTarjoaja>(context, listen: false).kieli;
    final String tallennusAvain = 'trivia_kysymykset_${maara}_${vaikeus}_$kohdeKieli';

    // Haetaan asetus AsetuksetTarjoajasta
    final bool haePaikallisesti = Provider.of<AsetuksetTarjoaja>(context, listen: false).haePaikallisesti;

    // Yritetään hakea kysymykset paikallisesta tallennuksesta, jos asetus on päällä
    if (haePaikallisesti) {
      final String? tallennettuData = prefs.getString(tallennusAvain);
      if (tallennettuData != null) {
        try {
          final List<dynamic> jsonList = json.decode(tallennettuData);
          List<Kysymys> paikallisetKysymykset = jsonList.map((json) => Kysymys.fromJson(json)).toList();
          _kysymykset = paikallisetKysymykset;
          _nykyinenIndeksi = 0;
          _pisteet = 0;
          _onLataus = false;
          print('Kysymykset ladattu paikallisesta tallennuksesta asetuksen mukaisesti.');
          notifyListeners();
          return; // Palataan, koska kysymykset ladattiin paikallisesti
        } catch (e) {
          print('Virhe paikallisen datan purkamisessa: $e');
          // Jatka API-kutsuun, jos paikallinen data on virheellinen
        }
      }
    }

    // Jos paikallista dataa ei löytynyt (tai asetus ei ollut päällä), haetaan API:sta
    try {
      final url = Uri.parse(
          '$apiBaseUrl/api.php?amount=$maara&difficulty=$vaikeus&type=multiple');
      final vastaus = await http.get(url);

      if (vastaus.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(vastaus.body);

        if (data['response_code'] == 0) {
          final unescape = HtmlUnescape();

          // Alustetaan OpenAI vain kerran, jos tarvitaan käännöstä ja API-kutsu tehdään
          // Käännös tarvitaan, jos kohdekieli ei ole englanti JA kysymykset haetaan API:sta
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

            // Käännetään vain jos kohdekieli ei ole englanti JA kysymykset haettiin API:sta
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

          _kysymykset = kysymykset;
          _nykyinenIndeksi = 0;
          _pisteet = 0;

          // Tallennetaan käännetyt kysymykset paikallisesti, jos ne haettiin API:sta
          final List<Map<String, dynamic>> jsonList = kysymykset.map((kysymys) => kysymys.toJson()).toList();
          await prefs.setString(tallennusAvain, json.encode(jsonList));
          print('Käännetyt kysymykset tallennettu paikallisesti API-haun jälkeen.');

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
      _kysymykset = [];
      _virhe = "Kysymysten lataaminen epäonnistui.";
      print('Virhe Trivia API:ssa tai käännöksessä: $e');
    } finally {
      _onLataus = false;
      notifyListeners();
    }
  }

  // Funktio, joka käsittelee käyttäjän vastauksen
  void vastaaKysymykseen(bool oikein) {
    if (_nykyinenIndeksi < _kysymykset.length) {
      if (oikein) {
        _pisteet += 20; // Lisää pisteitä oikeasta vastauksesta
      } else {
        _pisteet -= 5; // Vähennä pisteitä väärästä vastauksesta
      }
      // Siirrytään seuraavaan kysymykseen vastauslogiikka on nyt PeliNakymaTila:ssa
      // _nykyinenIndeksi++; // Tämä rivi poistetaan tai kommentoidaan
      notifyListeners();
    }
  }

  // Funktio seuraavaan kysymykseen siirtymiseen
  void seuraavaKysymys() {
    if (_nykyinenIndeksi < _kysymykset.length - 1) {
      _nykyinenIndeksi++;
    }
    notifyListeners();
  }

  // Funktio pelin tilan nollaamiseen
  void nollaaPeli() {
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    // _kysymykset = []; // Voit halutessasi tyhjentää kysymyslistan tässä
    notifyListeners();
  }

  // Funktio paikallisesti tallennettujen kysymysten poistamiseen
  Future<void> poistaPaikallisetKysymykset(int maara, String vaikeus, String kohdeKieli) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String tallennusAvain = 'trivia_kysymykset_${maara}_${vaikeus}_$kohdeKieli';
    await prefs.remove(tallennusAvain);
    print('Paikallisesti tallennetut kysymykset poistettu avaimella: $tallennusAvain');
  }

  // Funktio tekstin kääntämiseen OpenAI:n avulla (sama kuin aiemmin)
  Future<String> kaannaTeksti(String teksti, String kohdeKieli) async {
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

      if (chatCompletion.choices.isNotEmpty && chatCompletion.choices.first.message.content != null) {
        return chatCompletion.choices.first.message.content!;
      } else {
        print("OpenAI käännös palautti tyhjän vastauksen tekstille: $teksti");
        return teksti;
      }

    } catch (e) {
      print("Virhe tekstin kääntämisessä OpenAI:lla: $e");
      return teksti;
    }
  }
}