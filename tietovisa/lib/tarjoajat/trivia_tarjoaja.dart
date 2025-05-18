import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../mallit/kysymys.dart';
import '../palvelut/trivia_api_palvelu.dart';
import '../palvelut/openai_palvelu.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'asetukset_tarjoaja.dart';

/// Triviatarjoaja hallinnoi sovelluksen trivia-tietoja ja pelin tilaa
class TriviaTarjoaja with ChangeNotifier {
  // Palvelut
  final TriviaApiPalvelu _triviaApiPalvelu = TriviaApiPalvelu();
  final OpenAIPalvelu _openAIPalvelu = OpenAIPalvelu();

  // Kysymykset tallennetaan listana
  List<Kysymys> _kysymykset = [];

  // Nykyinen kysymysindeksi
  int _nykyinenIndeksi = 0;

  // Pelin pistemäärä
  int _pisteet = 0;

  // Onko kysymyksiä latauksessa
  bool _onLataus = false;

  // Mahdollinen virheviesti
  String? _virhe;

  // ML Kit -kääntäjä ja mallinhallinta
  final OnDeviceTranslator _translator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.finnish,
  );
  final OnDeviceTranslatorModelManager _modelManager =
  OnDeviceTranslatorModelManager();

  TriviaTarjoaja() {
    // Ladataan käännösmallit konstruktorissa
    _modelManager.downloadModel(TranslateLanguage.english.bcpCode);
    _modelManager.downloadModel(TranslateLanguage.finnish.bcpCode);
  }

  // Getterit tarjoavat pääsyn yksityisiin muuttujiin
  List<Kysymys> get kysymykset => _kysymykset;
  int get nykyinenIndeksi => _nykyinenIndeksi;
  int get pisteet => _pisteet;
  bool get onLataus => _onLataus;
  String? get virhe => _virhe;

  /// Hakee kysymykset valitusta lähteestä ja kääntää ne tarvittaessa
  Future<void> haeKysymykset(
      int maara,
      String vaikeus, // Vaikeustaso tulee edelleen parametrina
      BuildContext context, // Tarvitaan AsetuksetTarjoajan hakemiseen
      ) async {
    _onLataus = true;
    _virhe = null;
    _kysymykset = []; // Tyhjennetään vanhat kysymykset
    _nykyinenIndeksi = 0;
    _pisteet = 0; // Nollataan pisteet uuden pelin alkaessa
    notifyListeners();

    try {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      final kaytaOpenAI = asetukset.kaytaOpenAIKysymyksia;
      final kaannokset = asetukset.kaytaKaannokset;
      final String valittuAihealue = asetukset.valittuAihealue; // *** LISÄTTY: Haetaan valittu aihealue ***

      List<Kysymys> raakaKysymykset = [];

      if (kaytaOpenAI) {
        // Hae kysymykset OpenAI:lta
        List<Kysymys> generoidutKysymykset = [];
        for (int i = 0; i < maara; i++) {
          // *** MUOKATTU: Käytetään valittua aihealueetta OpenAI-kutsussa ***
          Kysymys? kysymys = await _openAIPalvelu.generoiKysymys(valittuAihealue, vaikeus);
          if (kysymys != null) {
            generoidutKysymykset.add(kysymys);
          }
          // Pieni viive estää API-rajoitusten ylittymisen nopeasti peräkkäisissä kutsuissa
          if (i < maara -1) await Future.delayed(const Duration(milliseconds: 500));
        }

        if (generoidutKysymykset.length < maara && generoidutKysymykset.isNotEmpty) {
          // *** MUOKATTU: Päivitetty virheilmoitus sisältämään aihealueen ***
          _virhe = "OpenAI generoi vain ${generoidutKysymykset.length} kysymystä pyydetystä $maara:sta aiheesta '$valittuAihealue'.";
        } else if (generoidutKysymykset.isEmpty) {
          // *** MUOKATTU: Päivitetty virheilmoitus sisältämään aihealueen ***
          _virhe = "OpenAI ei pystynyt generoimaan kysymyksiä aiheesta '$valittuAihealue'.";
        }
        raakaKysymykset = generoidutKysymykset;

      } else {
        // Hae kysymykset perinteisestä Trivia API:sta
        // Huom: Perinteinen TriviaApiPalvelu ei välttämättä tue kaikkia samoja aihealueita
        // kuin mitä olet määrittänyt OpenAI:lle. Sinun täytyy joko:
        // 1. Mäpätä valittuAihealue TriviaApiPalvelun tukemaan kategoriaan/aiheeseen.
        // 2. Tai antaa TriviaApiPalvelulle aina jokin oletusaihe/kategoria, jos valittuAihealue
        //    ei ole sille relevantti.
        // Tässä esimerkissä oletetaan, että TriviaApiPalvelu ei käytä valittuaAihealuetta suoraan.
        raakaKysymykset = await _triviaApiPalvelu.haeKysymykset(maara, vaikeus);
      }

      // Käännä kysymykset tarvittaessa
      if (!kaytaOpenAI && kaannokset && _translator.targetLanguage != TranslateLanguage.english && raakaKysymykset.isNotEmpty) {
        final List<Kysymys> kaannetytKysymykset = [];
        for (var q in raakaKysymykset) {
          final teksti = await _translator.translateText(q.kysymysTeksti);
          final oikea = await _translator.translateText(q.oikeaVastaus);
          final vaarat = <String>[];
          for (var v in q.vaaratVastaukset) {
            vaarat.add(await _translator.translateText(v));
          }
          kaannetytKysymykset.add(Kysymys(
            kategoria: q.kategoria,
            tyyppi: q.tyyppi,
            vaikeus: q.vaikeus,
            kysymysTeksti: teksti,
            oikeaVastaus: oikea,
            vaaratVastaukset: vaarat,
          ));
        }
        _kysymykset = kaannetytKysymykset;
      } else {
        _kysymykset = raakaKysymykset;
      }

      if (_kysymykset.isEmpty && _virhe == null) {
        _virhe = "Kysymyksiä ei löytynyt valitulla lähteellä ja asetuksilla.";
      }

    } catch (e) {
      _kysymykset = []; // Varmistetaan, että lista on tyhjä virhetilanteessa
      _virhe = "Kysymysten lataaminen epäonnistui: $e";
    } finally {
      _onLataus = false;
      notifyListeners();
    }
  }

  /// Käsittelee pelaajan vastauksen
  void vastaaKysymykseen(bool oikein) {
    // Varmistetaan, että nykyinen indeksi on kelvollinen
    if (_nykyinenIndeksi < _kysymykset.length) {
      if (oikein) {
        _pisteet += 20;
      } else {
        _pisteet -= 5;
        // Estetään negatiiviset pisteet, jos niin halutaan
        if (_pisteet < 0) _pisteet = 0;
      }
      notifyListeners();
    }
  }

  // ... (aiempi koodi TriviaTarjoaja-luokassa, mukaan lukien haeKysymykset ja vastaaKysymykseen)

  /// Siirtyy seuraavaan kysymykseen
  void seuraavaKysymys() {
    if (_nykyinenIndeksi < _kysymykset.length - 1) {
      _nykyinenIndeksi++;
      notifyListeners();
    }
  }

  /// Nollaa pelin tilan (esim. uuden pelin aloittamiseksi ilman kysymysten hakua)
  void nollaaPeli() {
    // _kysymykset = []; // Ei välttämättä nollata kysymyksiä tässä, jos halutaan pelata samat uudelleen
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    _virhe = null; // Nollataan myös virheviesti
    _onLataus = false; // Varmistetaan, ettei lataustila jää päälle
    notifyListeners();
  }

  /// Suljetaan kääntäjä resurssien vapauttamiseksi
  /// Tämä on hyvä kutsua, kun TriviaTarjoajaa ei enää tarvita, esim. Providerin dispose-metodissa.
  @override
  void dispose() {
    _translator.close();
    super.dispose();
  }
}