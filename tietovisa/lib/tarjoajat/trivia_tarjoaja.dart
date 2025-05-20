// tarjoajat/trivia_tarjoaja.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../mallit/kysymys.dart';
import '../palvelut/trivia_api_palvelu.dart';
import '../palvelut/openai_palvelu.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'asetukset_tarjoaja.dart';

class TriviaTarjoaja with ChangeNotifier {
  final TriviaApiPalvelu _triviaApiPalvelu = TriviaApiPalvelu();
  final OpenAIPalvelu _openAIPalvelu = OpenAIPalvelu();

  List<Kysymys> _kysymykset = [];
  int _nykyinenIndeksi = 0;
  int _pisteet = 0;
  bool _onLataus = false;
  String? _virhe;

  Set<String> _esitetytKysymyksetTekstit = {};

  final OnDeviceTranslator _translator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english, // Oletuslähdekieli perinteiselle API:lle
    targetLanguage: TranslateLanguage.finnish,
  );
  final OnDeviceTranslatorModelManager _modelManager =
  OnDeviceTranslatorModelManager();

  TriviaTarjoaja() {
    _modelManager.downloadModel(TranslateLanguage.english.bcpCode);
    _modelManager.downloadModel(TranslateLanguage.finnish.bcpCode);
  }

  List<Kysymys> get kysymykset => _kysymykset;
  int get nykyinenIndeksi => _nykyinenIndeksi;
  int get pisteet => _pisteet;
  bool get onLataus => _onLataus;
  String? get virhe => _virhe;

  Future<void> haeKysymykset(
      int maara,
      String vaikeus,
      BuildContext context,
      ) async {
    _onLataus = true;
    _virhe = null;
    _kysymykset = [];
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    _esitetytKysymyksetTekstit.clear(); // Nollaa esitetyt uutta peliä varten
    notifyListeners();

    try {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      final kaytaOpenAI = asetukset.kaytaOpenAIKysymyksia;
      final kaytaKaannoksetPerinteiselleAPIlle = asetukset.kaytaKaannokset;
      final String valittuAihealue = asetukset.valittuAihealue;

      List<Kysymys> lopullisetKysymyksetPeliin = [];

      if (kaytaOpenAI) {
        // --- HAE KYSYMYKSET OPENAI:LTA (oletetaan suomeksi) ---
        List<Kysymys> generoidutOpenAIKysymykset = [];
        int yrityksetKaikkiaan = 0;
        const int maksimiYrityksetYhteensa = 25;

        while (generoidutOpenAIKysymykset.length < maara && yrityksetKaikkiaan < maksimiYrityksetYhteensa) {
          Kysymys? kysymys;
          String? kysymysTekstiNormalisoitu;
          int yrityksetTalleKysymykselle = 0;
          const int maksimiYrityksetPerKysymys = 3;

          do {
            kysymys = await _openAIPalvelu.generoiKysymys(valittuAihealue, vaikeus);
            kysymysTekstiNormalisoitu = kysymys?.kysymysTeksti.trim().toLowerCase();
            yrityksetTalleKysymykselle++;
            yrityksetKaikkiaan++;

            if (kysymysTekstiNormalisoitu != null && _esitetytKysymyksetTekstit.contains(kysymysTekstiNormalisoitu)) {
              kysymys = null;
              debugPrint("OpenAI generoi duplikaattikysymyksen, yritetään uudelleen...");
            }

            if (kysymys == null && yrityksetTalleKysymykselle < maksimiYrityksetPerKysymys && yrityksetKaikkiaan < maksimiYrityksetYhteensa) {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          } while (kysymys == null && yrityksetTalleKysymykselle < maksimiYrityksetPerKysymys && yrityksetKaikkiaan < maksimiYrityksetYhteensa);

          if (kysymys != null && kysymysTekstiNormalisoitu != null) {
            generoidutOpenAIKysymykset.add(kysymys);
            _esitetytKysymyksetTekstit.add(kysymysTekstiNormalisoitu);
            if (generoidutOpenAIKysymykset.length < maara && yrityksetKaikkiaan < maksimiYrityksetYhteensa) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          } else if (yrityksetTalleKysymykselle >= maksimiYrityksetPerKysymys) {
            debugPrint("Ei saatu uniikkia OpenAI-kysymystä $maksimiYrityksetPerKysymys yrityksen jälkeen aiheesta '$valittuAihealue'.");
          }
        }

        if (generoidutOpenAIKysymykset.length < maara && generoidutOpenAIKysymykset.isNotEmpty && maara > 0) {
          _virhe = "OpenAI generoi vain ${generoidutOpenAIKysymykset.length} uniikkia kysymystä pyydetystä $maara:sta aiheesta '$valittuAihealue'.";
        } else if (generoidutOpenAIKysymykset.isEmpty && maara > 0) {
          _virhe = "OpenAI ei pystynyt generoimaan yhtään uniikkia kysymystä aiheesta '$valittuAihealue'.";
        }
        lopullisetKysymyksetPeliin = generoidutOpenAIKysymykset;

        // tarjoajat/trivia_tarjoaja.dart
// ... (aiempi koodi, mukaan lukien importit, luokan alku ja if (kaytaOpenAI) -lohko) ...

      } else {
        // --- HAE KYSYMYKSET PERINTEISESTÄ API:STA ---
        List<Kysymys> apiKysymyksetAlkuperaiset = await _triviaApiPalvelu.haeKysymykset(maara, vaikeus);
        List<Kysymys> kasiteltavatApiKysymykset = [];

        for (var q in apiKysymyksetAlkuperaiset) {
          if (kasiteltavatApiKysymykset.length >= maara) break; // Estää ylimääräisen työn, jos saatiin jo tarpeeksi
          final normalisoituTeksti = q.kysymysTeksti.trim().toLowerCase();
          if (!_esitetytKysymyksetTekstit.contains(normalisoituTeksti)) {
            kasiteltavatApiKysymykset.add(q);
            _esitetytKysymyksetTekstit.add(normalisoituTeksti);
          }
        }

        if (kasiteltavatApiKysymykset.isEmpty && apiKysymyksetAlkuperaiset.isNotEmpty && maara > 0) {
          _virhe = "Kaikki perinteisestä API:sta haetut kysymykset olivat duplikaatteja tai niitä ei löytynyt riittävästi.";
        } else if (kasiteltavatApiKysymykset.isEmpty && maara > 0) { // Tarkistetaan myös, jos maara > 0
          _virhe = "Perinteinen API ei palauttanut kysymyksiä tai niitä ei ollut riittävästi uniikkeina.";
        }


        // Käännä perinteisen API:n kysymykset, JOS käännökset ovat päällä
        if (kaytaKaannoksetPerinteiselleAPIlle && _translator.targetLanguage != TranslateLanguage.english && kasiteltavatApiKysymykset.isNotEmpty) {
          final List<Kysymys> kaannetytKysymyksetListaan = [];
          for (var q in kasiteltavatApiKysymykset) {
            try {
              final teksti = await _translator.translateText(q.kysymysTeksti);
              final oikea = await _translator.translateText(q.oikeaVastaus);
              final vaarat = <String>[];
              for (var v in q.vaaratVastaukset) {
                vaarat.add(await _translator.translateText(v));
              }
              kaannetytKysymyksetListaan.add(Kysymys(
                kategoria: q.kategoria,
                tyyppi: q.tyyppi,
                vaikeus: q.vaikeus,
                kysymysTeksti: teksti,
                oikeaVastaus: oikea,
                vaaratVastaukset: vaarat,
              ));
            } catch (e) {
              debugPrint("Kysymyksen '${q.kysymysTeksti}' kääntäminen epäonnistui: $e");
              // Voit päättää, lisätäänkö kääntämätön kysymys vai ohitetaanko se
              // Tässä esimerkissä se ohitetaan, jotta lista sisältää vain onnistuneesti käännettyjä
            }
          }
          lopullisetKysymyksetPeliin = kaannetytKysymyksetListaan;
          if (lopullisetKysymyksetPeliin.isEmpty && kasiteltavatApiKysymykset.isNotEmpty) {
            _virhe = (_virhe == null ? "" : "$_virhe ") + "Kysymysten kääntäminen epäonnistui kaikille haetuille kysymyksille.";
          }
        } else {
          // Jos käännöksiä ei ole päällä perinteiselle API:lle (tai kohdekieli on jo englanti), käytä niitä sellaisenaan
          lopullisetKysymyksetPeliin = kasiteltavatApiKysymykset;
        }
      }

      _kysymykset = lopullisetKysymyksetPeliin;

      // Yleinen tarkistus, jos kysymyslista on tyhjä eikä virhettä ole vielä asetettu
      if (_kysymykset.isEmpty && _virhe == null && maara > 0) {
        _virhe = "Kysymyksiä ei löytynyt valituilla asetuksilla.";
      }

    } catch (e) {
      _kysymykset = [];
      _virhe = "Kysymysten lataamisessa tapahtui odottamaton virhe: $e";
      debugPrint("HaeKysymykset virhe: $e");
    } finally {
      _onLataus = false;
      notifyListeners();
    }
  }

  void vastaaKysymykseen(bool oikein) {
    if (_nykyinenIndeksi < _kysymykset.length) {
      if (oikein) {
        _pisteet += 20;
      } else {
        _pisteet -= 5;
        if (_pisteet < 0) _pisteet = 0;
      }
      notifyListeners();
    }
  }

  void seuraavaKysymys() {
    if (_nykyinenIndeksi < _kysymykset.length - 1) {
      _nykyinenIndeksi++;
      notifyListeners();
    }
  }

  void nollaaPeli() {
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    _virhe = null;
    _onLataus = false;
    // _esitetytKysymyksetTekstit tyhjennetään haeKysymykset-metodin alussa
    notifyListeners();
  }

  @override
  void dispose() {
    _translator.close();
    super.dispose();
  }
}