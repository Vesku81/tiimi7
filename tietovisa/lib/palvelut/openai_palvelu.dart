import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // LISÄTTY
import '../mallit/kysymys.dart';

class OpenAIPalvelu {
  final String _apiKey = 'Oma avain'; // MUISTA KÄYTTÄÄ TURVALLISEMPAA TALLENNUSTAPAA API-AVAIMELLE TUOTANNOSSA
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  // SharedPreferences-avain esitetyille kysymyksille
  static const String _esitetytKysymyksetAvain = 'openai_esitetyt_kysymykset_v1';

  // _esitetytKysymykset ladataan nyt asynkronisesti SharedPreferencesista
  Set<String> _esitetytKysymyksetMuistissa = {};
  bool _onkoKysymyksetLadattuMuistiin = false;

  // Konstruktori, joka käynnistää esitettyjen kysymysten lataamisen
  OpenAIPalvelu() {
    _lataaEsitetytKysymyksetMuistiin();
  }

  Future<void> _lataaEsitetytKysymyksetMuistiin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? tallennetut = prefs.getStringList(_esitetytKysymyksetAvain);
      if (tallennetut != null) {
        _esitetytKysymyksetMuistissa = Set<String>.from(tallennetut);
        print("✅ OpenAI: Esitetyt kysymykset ladattu SharedPreferencesista: ${_esitetytKysymyksetMuistissa.length} kpl");
      } else {
        print("ℹ️ OpenAI: Ei aiempia esitettyjä kysymyksiä SharedPreferencesissa.");
      }
    } catch (e) {
      print("❌ OpenAI: Virhe esitettyjen kysymysten lataamisessa SharedPreferencesista: $e");
    }
    _onkoKysymyksetLadattuMuistiin = true;
  }

  Future<void> _lisaaJaTallennaEsitettyKysymys(String normalisoituKysymys) async {
    _esitetytKysymyksetMuistissa.add(normalisoituKysymys); // Lisää ensin muistiin
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_esitetytKysymyksetAvain, _esitetytKysymyksetMuistissa.toList());
      // print("💾 OpenAI: Kysymys tallennettu SharedPreferencesiin."); // Voit poistaa tämän, jos liian verbose
    } catch (e) {
      print("❌ OpenAI: Virhe esitetyn kysymyksen tallentamisessa SharedPreferencesiin: $e");
    }
  }

  // Metodi esitettyjen kysymysten tyhjentämiseen (esim. testausta tai nollausta varten)
  Future<void> tyhjennaHistoria() async {
    _esitetytKysymyksetMuistissa.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_esitetytKysymyksetAvain);
      print("🗑️ OpenAI: Kaikki esitetyt kysymykset poistettu SharedPreferencesista ja muistista.");
    } catch (e) {
      print("❌ OpenAI: Virhe esitettyjen kysymysten poistamisessa: $e");
    }
  }

  String _normalisoi(String kysymys) {
    return kysymys.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
  }

  Future<Kysymys?> generoiKysymys(String aihe, String vaikeustaso) async {
    // Varmistetaan, että kysymykset on yritetty ladata ennen jatkamista.
    // Tämä on yksinkertainen tarkistus. Monimutkaisemmissa sovelluksissa
    // saatat haluta käyttää esim. Completeria tai Streamia ilmoittamaan, kun lataus on valmis.
    if (!_onkoKysymyksetLadattuMuistiin) {
      // Annetaan pieni hetki lataukselle, jos se on juuri käynnissä.
      // Tämä ei ole täydellinen ratkaisu kilpa-ajotilanteisiin, mutta auttaa yleisimmissä tapauksissa.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_onkoKysymyksetLadattuMuistiin) {
        print("⚠️ OpenAI: Esitettyjen kysymysten lataus SharedPreferencesista ei ole vielä valmis. Yritetään ladata uudelleen.");
        await _lataaEsitetytKysymyksetMuistiin(); // Varmistetaan, että lataus on yritetty
      }
    }

    // Rajoitetaan promptiin lähetettävien kysymysten määrää token-rajoitusten vuoksi
    final int maxAiemmatPromptissa = 25; // Säädä tarpeen mukaan
    List<String> aiemmatPromptiin;

    if (_esitetytKysymyksetMuistissa.length > maxAiemmatPromptissa) {
      // Otetaan 'take' Setistä, koska järjestys ei ole taattu.
      // Parempi olisi satunnainen otos tai jokin muu logiikka, jos halutaan "viimeisimmät".
      aiemmatPromptiin = _esitetytKysymyksetMuistissa
          .take(maxAiemmatPromptissa)
          .map((k) => '"$k"') // Lisätään lainausmerkit promptia varten
          .toList();
    } else {
      aiemmatPromptiin = _esitetytKysymyksetMuistissa
          .map((k) => '"$k"')
          .toList();
    }

    final prompt = '''
Generoi trivia-kysymys aiheesta "$aihe" vaikeustasolla "$vaikeustaso".
${aiemmatPromptiin.isNotEmpty ? 'Älä toista seuraavia kysymyksiä (tai hyvin samankaltaisia): ${aiemmatPromptiin.join(', ')}.' : ''}
Palauta vastaus seuraavassa JSON-muodossa:
{
  "kysymys": "...",
  "oikea_vastaus": "...",
  "vaarat_vastaukset": ["...", "...", "..."] // Pyydetään 3 väärää vastausta
}
''';
// Huom! Vähensin vaarat_vastaukset kolmesta kahteen promptissa, jotta se vastaa paremmin yleistä trivia-formaattia
// ja vähentää hieman tokenien käyttöä. Voit muuttaa takaisin kolmeen, jos haluat.

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'Olet avulias tekoäly, joka generoi uniikkeja trivia-kysymyksiä JSON-muodossa. Vältä antamasta kysymyksiä, jotka on lueteltu käyttäjän promptissa aiemmin esitettyinä.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.75, // Hieman nostettu luovuuden lisäämiseksi
          'max_tokens': 150,  // Rajoitetaan vastauksen pituutta varmuuden vuoksi
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        final messageContent = responseBody['choices'][0]['message']['content'] as String?;

        if (messageContent == null) {
          print('❌ OpenAI API -virhe: Vastausviesti puuttuu.');
          return null;
        }

        try {
          final Map<String, dynamic> data = jsonDecode(messageContent);

          // Varmistetaan, että avaimet löytyvät ja ovat oikeaa tyyppiä
          final kysymysTeksti = data['kysymys'] as String?;
          final oikeaVastaus = data['oikea_vastaus'] as String?;
          final vaaratVastauksetDynamic = data['vaarat_vastaukset'] as List?;

          if (kysymysTeksti == null || kysymysTeksti.trim().isEmpty) {
            print('❌ OpenAI JSON-virhe: "kysymys" puuttuu tai on tyhjä. Sisältö: $messageContent');
            return null;
          }
          if (oikeaVastaus == null || oikeaVastaus.trim().isEmpty) {
            print('❌ OpenAI JSON-virhe: "oikea_vastaus" puuttuu tai on tyhjä. Sisältö: $messageContent');
            return null;
          }
          if (vaaratVastauksetDynamic == null || vaaratVastauksetDynamic.isEmpty) {
            print('❌ OpenAI JSON-virhe: "vaarat_vastaukset" puuttuu tai on tyhjä lista. Sisältö: $messageContent');
            return null;
          }

          final List<String> vaaratVastaukset = vaaratVastauksetDynamic
              .map((v) => v.toString()) // Varmistetaan, että kaikki ovat merkkijonoja
              .where((v) => v.trim().isNotEmpty) // Poistetaan tyhjät vastaukset
              .toList();

          if (vaaratVastaukset.isEmpty) {
            print('❌ OpenAI JSON-virhe: "vaarat_vastaukset" ei sisältänyt kelvollisia merkkijonoja. Sisältö: $messageContent');
            return null;
          }

          final kysymysNorm = _normalisoi(kysymysTeksti);

          if (_esitetytKysymyksetMuistissa.contains(kysymysNorm)) {
            print("⚠️ OpenAI: Duplikaatti havaittu (oli jo muistissa/SharedPreferencesissa), ohitetaan: $kysymysTeksti");
           return null;
          }

          // Lisää uusi kysymys muistiin ja tallenna SharedPreferencesiin
          await _lisaaJaTallennaEsitettyKysymys(kysymysNorm);

          return Kysymys(
            kysymysTeksti: kysymysTeksti,
            oikeaVastaus: oikeaVastaus,
            vaaratVastaukset: vaaratVastaukset,
            kategoria: aihe,
            tyyppi: 'multiple', // Oletetaan edelleen monivalinta
            vaikeus: vaikeustaso,
          );
        } catch (e) {
          print('❌ OpenAI: JSON-jäsennysvirhe: $e\nSisältö: $messageContent');
          return null;
        }
      } else {
        print('❌ OpenAI API -virhe: ${response.statusCode}\nVastaus: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ OpenAI: Verkkovirhe tai muu odottamaton virhe: $e');
      return null;
    }
  }
}