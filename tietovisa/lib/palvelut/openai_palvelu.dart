// Tuodaan tarvittavat paketit.
import 'dart:convert'; // JSON-koodaukseen ja -dekoodaukseen.
import 'package:http/http.dart' as http; // HTTP-pyyntöjen tekemiseen.
import 'package:shared_preferences/shared_preferences.dart'; // Paikalliseen tallennukseen.
import '../mallit/kysymys.dart'; // Kysymys-datamalli.

/// Palveluluokka OpenAI API:n kanssa kommunikointiin trivia-kysymysten generoimiseksi.
/// Tämä versio käyttää sekä normalisoituja kysymyksiä että "semanttisia hasheja"
/// duplikaattien tunnistamiseen ja välttämiseen.
class OpenAIPalvelu {
  // OpenAI API-avain.
  final String _apiKey = 'Oma avain';
  // OpenAI Chat Completions API:n päätepiste.
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  // SharedPreferences-avaimet esitetyille normalisoiduille kysymyksille ja niiden hasheille.
  // Versionumerot auttavat datan hallinnassa tulevaisuudessa.
  static const String _esitetytKysymyksetAvain = 'openai_esitetyt_kysymykset_v1';
  static const String _esitetytKysymyksetHashAvain = 'openai_esitetyt_kysymys_hash_v1';

  // Muistissa pidettävät joukot (Set) normalisoiduille kysymyksille ja niiden hasheille.
  // Set-rakenne takaa uniikkiuden ja nopean tarkistuksen.
  Set<String> _esitetytKysymyksetMuistissa = {};
  Set<String> _kysymysHashMuistissa = {};
  // Lippu, joka kertoo, onko kysymysten ja hashien lataus SharedPreferencesista suoritettu.
  bool _onkoKysymyksetLadattuMuistiin = false;

  /// Konstruktori. Käynnistää automaattisesti aiemmin esitettyjen kysymysten
  /// ja niiden hashien lataamisen SharedPreferencesista muistiin.
  OpenAIPalvelu() {
    _lataaEsitetytKysymyksetMuistiin();
  }

  /// Lataa aiemmin esitetyt normalisoidut kysymykset ja niiden semanttiset hashit
  /// SharedPreferencesista vastaaviin muistissa oleviin Set-rakenteisiin.
  Future<void> _lataaEsitetytKysymyksetMuistiin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ladataan normalisoidut kysymykset.
      final List<String>? tallennetut = prefs.getStringList(_esitetytKysymyksetAvain);
      // Ladataan kysymysten hashit.
      final List<String>? hashit = prefs.getStringList(_esitetytKysymyksetHashAvain);

      // Jos dataa löytyi, päivitetään muistissa olevat Setit.
      if (tallennetut != null) _esitetytKysymyksetMuistissa = Set<String>.from(tallennetut);
      if (hashit != null) _kysymysHashMuistissa = Set<String>.from(hashit);
    } catch (e) {
      // Virheenkäsittely latauksen epäonnistuessa.
      print("❌ Virhe kysymysten lataamisessa: $e");
    }
    // Merkitään, että latausyritys on tehty.
    _onkoKysymyksetLadattuMuistiin = true;
  }

  /// Lisää uuden normalisoidun kysymyksen (`norm`) ja sen semanttisen hashin (`hash`)
  /// muistiin ja tallentaa päivitetyt listat SharedPreferencesiin.
  Future<void> _lisaaJaTallennaEsitettyKysymys(String norm, String hash) async {
    _esitetytKysymyksetMuistissa.add(norm);
    _kysymysHashMuistissa.add(hash);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Tallennetaan molemmat Setit listoina.
      await prefs.setStringList(_esitetytKysymyksetAvain, _esitetytKysymyksetMuistissa.toList());
      await prefs.setStringList(_esitetytKysymyksetHashAvain, _kysymysHashMuistissa.toList());
    } catch (e) {
      // Virheenkäsittely tallennuksen epäonnistuessa.
      print("❌ Virhe tallennuksessa: $e");
    }
  }

  /// Tyhjentää esitettyjen kysymysten ja hashien historian sekä muistista
  /// että SharedPreferencesista.
  Future<void> tyhjennaHistoria() async {
    _esitetytKysymyksetMuistissa.clear();
    _kysymysHashMuistissa.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      // Poistetaan molemmat avaimet SharedPreferencesista.
      await prefs.remove(_esitetytKysymyksetAvain);
      await prefs.remove(_esitetytKysymyksetHashAvain);
    } catch (e) {
      // Virheenkäsittely tyhjennyksen epäonnistuessa.
      print("❌ Virhe tyhjennyksessä: $e");
    }
  }

  /// Normalisoi kysymystekstin: poistaa välilyönnit alusta/lopusta,
  /// muuttaa pieniksi kirjaimiksi ja poistaa erikoismerkit.
  /// Käytetään tarkkaan duplikaattien tunnistukseen.
  String _normalisoi(String kysymys) {
    return kysymys.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
  }

  /// Luo "semanttisen hashin" kysymyksestä.
  /// Tämä on yksinkertainen tapa tunnistaa samankaltaisia kysymyksiä.
  /// Normalisoi kysymyksen, jakaa sen sanoiksi, järjestää sanat aakkosjärjestykseen,
  /// ottaa kuusi ensimmäistä sanaa ja yhdistää ne viivoilla.
  /// Tavoitteena on, että samasta aiheesta eri sanamuodoilla olevat kysymykset
  /// tuottaisivat saman tai hyvin samanlaisen hashin.
  String _semanttinenHash(String kysymys) {
    final norm = _normalisoi(kysymys); // Ensin normalisoidaan.
    final parts = norm.split(RegExp(r'\s+'))..sort(); // Jaetaan sanoiksi ja järjestetään.
    return parts.take(6).join('-'); // Otetaan 6 ensimmäistä sanaa ja yhdistetään.
  }

  /// Generoi uuden trivia-kysymyksen OpenAI API:n avulla.
  /// Tarkistaa duplikaatit sekä normalisoidun kysymyksen että semanttisen hashin perusteella.
  Future<Kysymys?> generoiKysymys(String aihe, String vaikeustaso) async {
    // Varmistetaan, että aiemmin esitetyt kysymykset on yritetty ladata muistiin.
    if (!_onkoKysymyksetLadattuMuistiin) {
      await Future.delayed(const Duration(milliseconds: 500)); // Pieni viive lataukselle.
      if (!_onkoKysymyksetLadattuMuistiin) {
        await _lataaEsitetytKysymyksetMuistiin(); // Yritetään ladata uudelleen.
      }
    }

    // Rajoitetaan promptiin mukaan otettavien aiemmin esitettyjen (normalisoitujen) kysymysten määrää.
    final int maxAiemmatPromptissa = 25;
    final aiemmatPromptiin = _esitetytKysymyksetMuistissa
        .take(maxAiemmatPromptissa) // Otetaan vain rajallinen määrä.
        .map((k) => '"$k"') // Lisätään lainausmerkit.
        .toList();

    // Muodostetaan prompti OpenAI API:lle.
    // Sisältää ohjeistuksen generoida täysin uusi kysymys,
    // listan vältettävistä aiemmista kysymyksistä, esimerkin samankaltaisuudesta
    // ja pyynnön palauttaa vastaus tietyssä JSON-muodossa.
    final prompt = '''
Generoi täysin uusi trivia-kysymys aiheesta "$aihe" vaikeustasolla "$vaikeustaso".
Älä toista seuraavia kysymyksiä tai vastaavia:
${aiemmatPromptiin.join(', ')}

Esimerkki samanlaisuudesta: 
"Mikä on Ranskan pääkaupunki?" ja "Missä sijaitsee Eiffel-torni?" ovat liian samankaltaisia.

Palauta vastaus seuraavassa JSON-muodossa:
{
  "kysymys": "...",
  "oikea_vastaus": "...",
  "vaarat_vastaukset": ["...", "...", "..."]
}
''';

    // Tehdään HTTP POST -pyyntö OpenAI API:lle.
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo', // Käytettävä malli.
        'messages': [
          {
            'role': 'system', // Järjestelmän ohjeistus tekoälylle.
            'content': 'Olet avulias tekoäly, joka generoi täysin uusia trivia-kysymyksiä. Älä missään nimessä toista aiempia tai niiden kaltaisia kysymyksiä.'
          },
          {'role': 'user', 'content': prompt} // Käyttäjän antama prompti.
        ],
        'temperature': 0.75, // Luovuuden määrä.
        'max_tokens': 150,  // Vastauksen maksimipituus.
      }),
    );

    // Jos API-kutsu ei onnistunut (statuskoodi ei ole 200), palautetaan null.
    if (response.statusCode != 200) return null;

    // Jäsennetään API:n vastaus.
    final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
    final messageContent = responseBody['choices'][0]['message']['content'] as String?;
    // Jos vastausviesti puuttuu, palautetaan null.
    if (messageContent == null) return null;

    try {
      // Yritetään jäsentää vastausviestin sisältö JSON-objektiksi.
      final Map<String, dynamic> data = jsonDecode(messageContent);
      // Puretaan kysymys, oikea vastaus ja väärät vastaukset.
      final kysymysTeksti = data['kysymys'] as String?;
      final oikeaVastaus = data['oikea_vastaus'] as String?;
      final vaaratVastauksetDynamic = data['vaarat_vastaukset'] as List?;

      // Tarkistetaan, että kaikki tarvittavat kentät ovat olemassa ja kelvollisia.
      if (kysymysTeksti == null || kysymysTeksti.trim().isEmpty) return null;
      if (oikeaVastaus == null || oikeaVastaus.trim().isEmpty) return null;
      if (vaaratVastauksetDynamic == null || vaaratVastauksetDynamic.isEmpty) return null;

      // Muunnetaan väärät vastaukset List<String>-tyyppiseksi ja poistetaan tyhjät.
      final List<String> vaaratVastaukset = vaaratVastauksetDynamic.map((v) => v.toString()).where((v) => v.trim().isNotEmpty).toList();
      if (vaaratVastaukset.isEmpty) return null; // Jos kelvollisia vääriä vastauksia ei ole.

      // Normalisoidaan generoitu kysymys ja luodaan sille semanttinen hash.
      final norm = _normalisoi(kysymysTeksti);
      final hash = _semanttinenHash(kysymysTeksti);

      // Tarkistetaan, onko normalisoitu kysymys TAI sen hash jo esitettyjen joukossa.
      // Tämä on avain duplikaattien ja samankaltaisten kysymysten välttämiseen.
      if (_esitetytKysymyksetMuistissa.contains(norm) || _kysymysHashMuistissa.contains(hash)) {
        return null; // Jos on duplikaatti tai liian samankaltainen, palautetaan null.
      }

      // Lisätään uusi kysymys (normalisoitu ja hash) muistiin ja tallennetaan.
      await _lisaaJaTallennaEsitettyKysymys(norm, hash);

      // Luodaan ja palautetaan Kysymys-olio.
      return Kysymys(
        kysymysTeksti: kysymysTeksti,
        oikeaVastaus: oikeaVastaus,
        vaaratVastaukset: vaaratVastaukset,
        kategoria: aihe,
        tyyppi: 'multiple', // Oletetaan monivalinta.
        vaikeus: vaikeustaso,
      );
    } catch (e) {
      // Virheenkäsittely JSON-jäsennyksen epäonnistuessa.
      print('❌ JSON error: $e');
      return null;
    }
  }
}