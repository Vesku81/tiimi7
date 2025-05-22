import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../mallit/kysymys.dart'; // Kysymys-datamalli.
import '../palvelut/trivia_api_palvelu.dart'; // Palvelu perinteisten trivia-kysymysten hakemiseen.
import '../palvelut/openai_palvelu.dart'; // Palvelu OpenAI-pohjaisten kysymysten generointiin.
import 'package:google_mlkit_translation/google_mlkit_translation.dart'; // ML Kit -käännöskirjasto.
import 'asetukset_tarjoaja.dart'; // Asetusten hallinta Providerilla.

/// `TriviaTarjoaja` on keskeinen luokka pelin logiikalle. Se hallinnoi:
/// - Kysymysten noutamista joko perinteisestä API:sta tai OpenAI:n avulla.
/// - Pelaajan pisteiden laskentaa.
/// - Kysymysten kääntämistä tarvittaessa suomeksi käyttäen ML Kitiä.
/// - Pelin yleistä tilaa (lataus, virheet, nykyinen kysymys).
///
/// Luokka käyttää `ChangeNotifier`-mixin'iä ilmoittaakseen UI-kerrokselle tilanmuutoksista,
/// mahdollistaen reaktiivisen käyttöliittymän.
class TriviaTarjoaja with ChangeNotifier {
  // Palveluolio perinteisten trivia-kysymysten hakemiseen.
  final TriviaApiPalvelu _triviaApiPalvelu = TriviaApiPalvelu();
  // Palveluolio OpenAI API:n kautta tapahtuvaan kysymysten generointiin.
  final OpenAIPalvelu _openAIPalvelu = OpenAIPalvelu();

  // Lista pelissä käytettävistä kysymyksistä.
  List<Kysymys> _kysymykset = [];
  // Indeksi, joka osoittaa nykyiseen aktiiviseen kysymykseen listalla.
  int _nykyinenIndeksi = 0;
  // Pelaajan keräämät pisteet.
  int _pisteet = 0;
  // Lippu, joka ilmaisee, onko käynnissä asynkroninen operaatio (esim. kysymysten haku).
  bool _onLataus = false;
  // Merkkijono mahdolliselle virheilmoitukselle, joka voidaan näyttää UI:ssa.
  String? _virhe;
  // Joukko (Set) jo esitettyjen kysymysten normalisoiduista teksteistä duplikaattien välttämiseksi.
  Set<String> _esitetytKysymyksetTekstit = {};

  // ML Kit -kääntäjäobjekti tekstien kääntämiseen laitteella.
  // Kääntää oletuksena englannista suomeksi.
  final OnDeviceTranslator _translator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english, // Lähdekieli käännökselle.
    targetLanguage: TranslateLanguage.finnish, // Kohdekieli käännökselle.
  );
  // Hallintaobjekti ML Kit -käännösmallien lataamiseen ja hallintaan.
  final OnDeviceTranslatorModelManager _modelManager =
  OnDeviceTranslatorModelManager();

  /// Konstruktori. Kun `TriviaTarjoaja`-olio luodaan:
  /// - Ladataan tarvittavat käännösmallit (englanti ja suomi) laitteelle.
  /// Tämä tehdään etukäteen, jotta käännökset ovat nopeita pelin aikana.
  TriviaTarjoaja() {
    // Aloitetaan englannin käännösmallin lataus.
    _modelManager.downloadModel(TranslateLanguage.english.bcpCode);
    // Aloitetaan suomen käännösmallin lataus.
    _modelManager.downloadModel(TranslateLanguage.finnish.bcpCode);
  }

  // Getterit pelin tilan seuraamiseen UI-kerroksesta.
  // Nämä mahdollistavat pääsyn yksityisiin tilamuuttujiin vain lukutarkoituksessa.

  /// Palauttaa listan pelin nykyisistä kysymyksistä.
  List<Kysymys> get kysymykset => _kysymykset;
  /// Palauttaa nykyisen kysymyksen indeksin.
  int get nykyinenIndeksi => _nykyinenIndeksi;
  /// Palauttaa pelaajan nykyiset pisteet.
  int get pisteet => _pisteet;
  /// Palauttaa `true`, jos peli lataa dataa (esim. kysymyksiä), muuten `false`.
  bool get onLataus => _onLataus;
  /// Palauttaa mahdollisen virheviestin merkkijonona, tai `null` jos virhettä ei ole.
  String? get virhe => _virhe;

  /// Asynkroninen päämetodi uusien kysymysten hakemiseen peliä varten.
  /// Kysymykset voidaan hakea joko OpenAI:n generoimana tai perinteisestä Trivia API:sta
  /// riippuen käyttäjän asetuksista (`AsetuksetTarjoaja`).
  ///
  /// Parametrit:
  /// - `maara`: Haettavien kysymysten lukumäärä.
  /// - `vaikeus`: Kysymysten vaikeustaso (esim. "easy", "medium", "hard").
  /// - `context`: `BuildContext` pääsyyn `AsetuksetTarjoaja`an Providerin kautta.
  Future<void> haeKysymykset(
      int maara,
      String vaikeus,
      BuildContext context,
      ) async {
    // Alustetaan pelin tila ennen uutta hakua: asetetaan lataustila päälle,
    // nollataan virheet, tyhjennetään aiemmat kysymykset, nollataan indeksi ja pisteet,
    // ja tyhjennetään esitettyjen kysymysten lista.
    _onLataus = true;
    _virhe = null;
    _kysymykset.clear();
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    _esitetytKysymyksetTekstit.clear();
    notifyListeners(); // Ilmoitetaan UI:lle tilanmuutoksesta.

    try {
      // Haetaan käyttäjän asetukset Providerin avulla.
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      final kaytaOpenAI = asetukset.kaytaOpenAIKysymyksia; // Käytetäänkö OpenAI:ta?
      final kaytaKaannokset = asetukset.kaytaKaannokset; // Käännetäänkö kysymykset?
      final String valittuAihe = asetukset.valittuAihealue; // Valittu aihealue.

      List<Kysymys> lopullisetKysymykset = []; // Lista lopullisille kysymyksille.

      if (kaytaOpenAI) {
        // --- Kysymysten haku OpenAI:n avulla ---
        List<Kysymys> generoidut = [];
        int yrityksetYhteensa = 0; // Kokonaisyritysten määrä duplikaattien välttämiseksi.
        const int maksimiYritykset = 25; // Maksimimäärä yrityksiä generoida uniikkeja kysymyksiä.

        // Yritetään generoida pyydetty määrä uniikkeja kysymyksiä.
        while (generoidut.length < maara && yrityksetYhteensa < maksimiYritykset) {
          Kysymys? kysymys;
          String? normalisoituKysymysTeksti;
          int yrityksetPerKysymys = 0; // Yritykset generoida yksi uniikki kysymys.
          const int maksimiYrityksetPerKysymys = 3; // Maksimiyritykset per kysymys.

          // Sisempi silmukka: yritetään generoida yksi uniikki kysymys.
          do {
            kysymys = await _openAIPalvelu.generoiKysymys(valittuAihe, vaikeus);
            // Normalisoidaan kysymysteksti duplikaattien tarkistusta varten.
            normalisoituKysymysTeksti = kysymys?.kysymysTeksti.trim().toLowerCase();
            yrityksetPerKysymys++;
            yrityksetYhteensa++;

            // Tarkistetaan, onko normalisoitu kysymys jo esitetty. Jos on, hylätään se.
            if (normalisoituKysymysTeksti != null &&
                _esitetytKysymyksetTekstit.contains(normalisoituKysymysTeksti)) {
              kysymys = null; // Merkitään kysymys hylätyksi (duplikaatti).
            }
            // Jos kysymystä ei saatu ja yrityksiä on jäljellä, pidetään pieni tauko ennen uutta yritystä.
            if (kysymys == null &&
                yrityksetPerKysymys < maksimiYrityksetPerKysymys &&
                yrityksetYhteensa < maksimiYritykset) {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          } while (kysymys == null && // Jatka, kunnes saadaan kelvollinen kysymys
              yrityksetPerKysymys < maksimiYrityksetPerKysymys && // tai yritykset per kysymys loppuvat
              yrityksetYhteensa < maksimiYritykset); // tai kokonaisyritykset loppuvat.

          // Jos kelvollinen ja uniikki kysymys saatiin, lisätään se listaan.
          if (kysymys != null && normalisoituKysymysTeksti != null) {
            generoidut.add(kysymys);
            _esitetytKysymyksetTekstit.add(normalisoituKysymysTeksti); // Lisätään esitettyjen joukkoon.
            // Pieni tauko ennen seuraavan kysymyksen generointia, jos tarvitaan lisää.
            if (generoidut.length < maara && yrityksetYhteensa < maksimiYritykset) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
        }

        // Jos OpenAI ei onnistunut generoimaan pyydettyä määrää kysymyksiä, asetetaan virheilmoitus.
        if (generoidut.length < maara) {
          _virhe = generoidut.isEmpty
              ? 'OpenAI ei onnistunut generoimaan yhtään kysymystä aiheesta "$valittuAihe".'
              : 'OpenAI generoi vain ${generoidut.length} kysymystä pyydetystä $maara aiheesta "$valittuAihe".';
        }
        lopullisetKysymykset = generoidut;
      } else {
        // --- Kysymysten haku perinteisestä Trivia API:sta ---
        // Muunnetaan valittu aihealue vastaavaksi kategoria ID:ksi API-kutsua varten.
        final int categoryId = _mapAihealueToCategoryId(valittuAihe);
        // Haetaan kysymykset Trivia API:sta.
        List<Kysymys> alkuperaisetKysymykset =
        await _triviaApiPalvelu.haeKysymykset(maara, vaikeus, categoryId);
        List<Kysymys> kasiteltavatKysymykset = [];

        // Käydään läpi haetut kysymykset ja poistetaan duplikaatit.
        for (var kysymys in alkuperaisetKysymykset) {
          if (kasiteltavatKysymykset.length >= maara) break; // Lopetetaan, jos tarpeeksi kysymyksiä.
          final normalisoitu = kysymys.kysymysTeksti.trim().toLowerCase();
          if (!_esitetytKysymyksetTekstit.contains(normalisoitu)) {
            kasiteltavatKysymykset.add(kysymys);
            _esitetytKysymyksetTekstit.add(normalisoitu);
          }
        }

        // Jos API ei palauttanut riittävästi uniikkeja kysymyksiä.
        if (kasiteltavatKysymykset.isEmpty && maara > 0) {
          _virhe = 'Perinteinen API ei palauttanut riittävästi uniikkeja kysymyksiä.';
        }

        // Käännetään kysymykset suomeksi, jos asetus on päällä ja kääntäjän kohdekieli ei ole englanti.
        if (kaytaKaannokset && _translator.targetLanguage != TranslateLanguage.english) {
          List<Kysymys> kaannetytKysymykset = [];
          for (var kysymys in kasiteltavatKysymykset) {
            try {
              // Käännetään kysymysteksti, oikea vastaus ja väärät vastaukset.
              final teksti = await _translator.translateText(kysymys.kysymysTeksti);
              final oikeaVastaus = await _translator.translateText(kysymys.oikeaVastaus);
              final vaaratVastaukset = <String>[];
              for (var vastaus in kysymys.vaaratVastaukset) {
                vaaratVastaukset.add(await _translator.translateText(vastaus));
              }
              // Luodaan uusi Kysymys-olio käännetyillä teksteillä.
              kaannetytKysymykset.add(Kysymys(
                kategoria: kysymys.kategoria,
                tyyppi: kysymys.tyyppi,
                vaikeus: kysymys.vaikeus,
                kysymysTeksti: teksti,
                oikeaVastaus: oikeaVastaus,
                vaaratVastaukset: vaaratVastaukset,
              ));
            } catch (e) {
              // Jos käännöksessä tapahtuu virhe, ohitetaan tämä kysymys ja jatketaan seuraavaan.
              // Voitaisiin myös lisätä alkuperäinen kysymys tai logata virhe tarkemmin.
              debugPrint('Käännösvirhe kysymykselle: ${kysymys.kysymysTeksti}, Virhe: $e');
            }
          }
          lopullisetKysymykset = kaannetytKysymykset;
        } else {
          // Jos käännöksiä ei käytetä, käytetään käsiteltyjä (duplikaatit poistettu) kysymyksiä.
          lopullisetKysymykset = kasiteltavatKysymykset;
        }
      }

      // Tallennetaan lopullinen kysymyslista tilaan.
      _kysymykset = lopullisetKysymykset;
      // Jos kysymyksiä ei löytynyt eikä virhettä ole aiemmin asetettu, asetetaan yleinen virheilmoitus.
      if (_kysymykset.isEmpty && _virhe == null && maara > 0) {
        _virhe = 'Kysymyksiä ei löytynyt valituilla asetuksilla.';
      }
    } catch (e) {
      // Yleinen virheenkäsittely kysymysten haussa.
      _virhe = 'Kysymysten haussa tapahtui odottamaton virhe: $e';
      debugPrint('HaeKysymykset virhe: $e');
      _kysymykset = []; // Tyhjennetään kysymyslista virhetilanteessa.
    } finally {
      // Varmistetaan, että lataustila poistetaan aina, onnistui haku tai ei.
      _onLataus = false;
      notifyListeners(); // Ilmoitetaan UI:lle tilanmuutoksesta.
    }
  }

  /// Apumetodi, joka muuntaa käyttäjän valitseman aihealueen (merkkijono)
  /// Open Trivia DB API:n vaatimaksi numeeriseksi kategoria ID:ksi.
  ///
  /// Parametri:
  /// - `aihealue`: Käyttäjän valitsema aihealue merkkijonona.
  ///
  /// Palauttaa:
  /// - Vastaavan kategoria ID:n Open Trivia DB:lle. Palauttaa yleistiedon (9) ID:n oletuksena.
  int _mapAihealueToCategoryId(String aihealue) {
    switch (aihealue.toLowerCase()) { // Muunnetaan pieniksi kirjaimiksi vertailun robustoimiseksi.
      case 'yleistieto':
        return 9;
      case 'historia':
        return 23;
      case 'maantieto':
        return 22;
      case 'tiede': // Huom: "luonto" voi myös kartoittua tähän tai omaan ID:hen riippuen API:sta.
      case 'luonto': // Tässä yhdistetty tieteen alle.
        return 17; // Science & Nature
      case 'viihde': // Yleinen viihde, voi sisältää useita alakategorioita.
        return 10; // Entertainment: Books (esimerkkinä, API:ssa voi olla tarkempia)
      case 'elokuvat':
        return 11; // Entertainment: Film
      case 'musiikki':
        return 12; // Entertainment: Music
      case 'urheilu':
        return 21; // Sports
      case 'taide ja kirjallisuus': // Yhdistetty kategoria.
        return 25; // Art (API:ssa voi olla erikseen kirjallisuudelle, esim. 10)
      default:
        return 9; // Oletusarvo, jos aihealue ei vastaa mitään tunnettua.
    }
  }

  /// Käsittelee pelaajan antaman vastauksen nykyiseen kysymykseen.
  /// Päivittää pelaajan pisteet sen mukaan, oliko vastaus oikein vai väärin.
  ///
  /// Parametri:
  /// - `oikein`: `true`, jos pelaajan vastaus oli oikein, muuten `false`.
  void vastaaKysymykseen(bool oikein) {
    // Varmistetaan, että ollaan validin kysymyksen kohdalla.
    if (_nykyinenIndeksi < _kysymykset.length) {
      _pisteet += oikein ? 20 : -5; // Lisätään pisteitä oikeasta, vähennetään väärästä.
      notifyListeners(); // Ilmoitetaan UI:lle pistemäärän muutoksesta.
    }
  }

  /// Siirtää pelin seuraavaan kysymykseen, jos sellainen on saatavilla.
  /// Päivittää `_nykyinenIndeksi`-tilaa.
  void seuraavaKysymys() {
    // Tarkistetaan, onko olemassa vielä seuraavia kysymyksiä.
    if (_nykyinenIndeksi < _kysymykset.length - 1) {
      _nykyinenIndeksi++; // Siirrytään seuraavaan indeksiin.
      notifyListeners(); // Ilmoitetaan UI:lle kysymyksen vaihtumisesta.
    }
  }

  /// Nollaa pelin tilan alkuasetelmiin.
  /// Tämä metodi kutsutaan tyypillisesti, kun aloitetaan uusi peli.
  /// Nollaa nykyisen kysymyksen indeksin, pisteet, virheilmoitukset ja lataustilan.
  void nollaaPeli() {
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    _virhe = null;
    _onLataus = false;
    // _kysymykset ja _esitetytKysymyksetTekstit tyhjennetään haeKysymykset-metodissa.
    notifyListeners(); // Ilmoitetaan UI:lle pelin nollauksesta.
  }

  /// Vapauttaa `TriviaTarjoaja`-olion käyttämät resurssit, kun sitä ei enää tarvita.
  /// Erityisesti sulkee ML Kit -kääntäjän resurssien vapauttamiseksi.
  /// Tämä on tärkeää muistivuotojen estämiseksi.
  @override
  void dispose() {
    _translator.close(); // Vapautetaan kääntäjän resurssit.
    super.dispose(); // Kutsutaan yliluokan dispose-metodia.
  }
}