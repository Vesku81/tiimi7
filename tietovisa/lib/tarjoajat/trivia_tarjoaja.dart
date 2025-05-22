import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../mallit/kysymys.dart';
import '../palvelut/trivia_api_palvelu.dart';
import '../palvelut/openai_palvelu.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'asetukset_tarjoaja.dart';

/// Vastaa pelin kysymysten hakemisesta, pisteiden laskemisesta
/// ja tarvittaessa käännöksistä sekä OpenAI-generaatiosta.
class TriviaTarjoaja with ChangeNotifier {
  final TriviaApiPalvelu _triviaApiPalvelu = TriviaApiPalvelu();
  final OpenAIPalvelu _openAIPalvelu     = OpenAIPalvelu();

  List<Kysymys> _kysymykset       = [];
  int          _nykyinenIndeksi   = 0;
  int          _pisteet           = 0;
  bool         _onLataus          = false;
  String?      _virhe;
  Set<String>  _esitetytKysymyksetTekstit = {};

  // ML Kit -kääntäjä (englanti → suomi)
  final OnDeviceTranslator _translator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.finnish,
  );
  final OnDeviceTranslatorModelManager _modelManager =
  OnDeviceTranslatorModelManager();

  TriviaTarjoaja() {
    // Pelin alussa ladataan käännösmallit laitteelle
    _modelManager.downloadModel(TranslateLanguage.english.bcpCode);
    _modelManager.downloadModel(TranslateLanguage.finnish.bcpCode);
  }

  // UI:n käyttöön getterit tiloille
  List<Kysymys> get kysymykset      => _kysymykset;
  int           get nykyinenIndeksi => _nykyinenIndeksi;
  int           get pisteet         => _pisteet;
  bool          get onLataus        => _onLataus;
  String?       get virhe           => _virhe;

  /// Päämetodi kysymysten hakemiseen joko OpenAI:sta tai perinteiseltä API:lta.
  /// Palauttaa halutun määrän kysymyksiä valitulla vaikeustasolla ja aihealueella.
  Future<void> haeKysymykset(
      int maara,
      String vaikeus,
      BuildContext context,
      ) async {
    // Nollataan tila ennen hakua
    _onLataus = true;
    _virhe    = null;
    _kysymykset.clear();
    _nykyinenIndeksi = 0;
    _pisteet         = 0;
    _esitetytKysymyksetTekstit.clear();
    notifyListeners();

    try {
      final asetukset          = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      final kaytaOpenAI        = asetukset.kaytaOpenAIKysymyksia;
      final kaytaKaannokset    = asetukset.kaytaKaannokset;
      final String valittuAihe = asetukset.valittuAihealue;

      List<Kysymys> lopulliset = [];

      if (kaytaOpenAI) {
        // --- OpenAI-haara: generaattori kysymyksille ---
        List<Kysymys> generoidut = [];
        int yrityksetYht = 0;
        const int maksYritykset = 25;

        while (generoidut.length < maara && yrityksetYht < maksYritykset) {
          Kysymys? kys;
          String? norm;
          int perKysYr = 0;
          const int maksPer = 3;

          // Yritetään generoida uniikki kysymys useamman kerran
          do {
            kys = await _openAIPalvelu.generoiKysymys(valittuAihe, vaikeus);
            norm = kys?.kysymysTeksti.trim().toLowerCase();
            perKysYr++;
            yrityksetYht++;

            // Vältä duplikaatit
            if (norm != null && _esitetytKysymyksetTekstit.contains(norm)) {
              kys = null;
            }
            if (kys == null && perKysYr < maksPer && yrityksetYht < maksYritykset) {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          } while (kys == null && perKysYr < maksPer && yrityksetYht < maksYritykset);

          // Jos saatiin kelvollinen kysymys, lisätään se listaan
          if (kys != null && norm != null) {
            generoidut.add(kys);
            _esitetytKysymyksetTekstit.add(norm);
            if (generoidut.length < maara && yrityksetYht < maksYritykset) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
        }

        // Jos ei saatu pyydettyä määrää, asetetaan virheviesti
        if (generoidut.length < maara) {
          _virhe = generoidut.isEmpty
              ? 'OpenAI ei generoitu aineistoa aiheesta "$valittuAihe".'
              : 'OpenAI generoi vain ${generoidut.length} kysymystä pyydetyistä $maara.';
        }
        lopulliset = generoidut;

      } else {
        // --- Perinteinen API-haara ---
        final int categoryId = _mapAihealueToCategoryId(valittuAihe);
        // Haetaan raakadata API:lta
        List<Kysymys> alkuper = await _triviaApiPalvelu.haeKysymykset(maara, vaikeus, categoryId);
        List<Kysymys> kasiteltavat = [];

        // Poistetaan duplikaatit
        for (var q in alkuper) {
          if (kasiteltavat.length >= maara) break;
          final norm = q.kysymysTeksti.trim().toLowerCase();
          if (!_esitetytKysymyksetTekstit.contains(norm)) {
            kasiteltavat.add(q);
            _esitetytKysymyksetTekstit.add(norm);
          }
        }
        if (kasiteltavat.isEmpty && maara > 0) {
          _virhe = 'Perinteinen API ei palauttanut riittävästi kysymyksiä.';
        }

        // Tarvittaessa käännetään suomeksi
        if (kaytaKaannokset && _translator.targetLanguage != TranslateLanguage.english) {
          List<Kysymys> kaannetyt = [];
          for (var q in kasiteltavat) {
            try {
              final teksti = await _translator.translateText(q.kysymysTeksti);
              final oikea  = await _translator.translateText(q.oikeaVastaus);
              final vaarat = <String>[];
              for (var v in q.vaaratVastaukset) {
                vaarat.add(await _translator.translateText(v));
              }
              kaannetyt.add(Kysymys(
                kategoria: q.kategoria,
                tyyppi:    q.tyyppi,
                vaikeus:   q.vaikeus,
                kysymysTeksti:   teksti,
                oikeaVastaus:    oikea,
                vaaratVastaukset: vaarat,
              ));
            } catch (_) {
              // Käännösvirheet ohitetaan
            }
          }
          lopulliset = kaannetyt;
        } else {
          lopulliset = kasiteltavat;
        }
      }

      // Lopuksi tallennetaan kysymykset ja asetetaan virhe, jos ei löytynyt
      _kysymykset = lopulliset;
      if (_kysymykset.isEmpty && _virhe == null && maara > 0) {
        _virhe = 'Kysymyksiä ei löytynyt valituilla asetuksilla.';
      }

    } catch (e) {
      // Yleinen virhepolku
      _virhe      = 'Kysymysten haussa virhe: $e';
      debugPrint('HaeKysymykset virhe: $e');
      _kysymykset = [];
    } finally {
      // Lopetetaan lataustila aina
      _onLataus = false;
      notifyListeners();
    }
  }

  /// Kartoitus suomenkielisestä aihealueesta Open Trivia DB:n category-id:hen
  int _mapAihealueToCategoryId(String aihealue) {
    switch (aihealue) {
      case 'yleistieto': return 9;
      case 'historia': return 23;
      case 'maantieto': return 22;
      case 'tiede': return 17;
      case 'viihde': return 10;
      case 'elokuvat': return 11;
      case 'musiikki': return 12;
      case 'urheilu': return 21;
      case 'taide ja kirjallisuus': return 25;
      case 'luonto': return 17;
      default: return 9;
    }
  }

  /// Käsittelee pelaajan vastauksen: lisätään tai vähennetään pisteitä
  void vastaaKysymykseen(bool oikein) {
    if (_nykyinenIndeksi < _kysymykset.length) {
      _pisteet += oikein ? 20 : -5;
      notifyListeners();
    }
  }

  /// Siirrytään seuraavaan kysymykseen, jos mahdollista
  void seuraavaKysymys() {
    if (_nykyinenIndeksi < _kysymykset.length - 1) {
      _nykyinenIndeksi++;
      notifyListeners();
    }
  }

  /// Nollaa pelin tilan (alamittaiset muuttujat)
  void nollaaPeli() {
    _nykyinenIndeksi = 0;
    _pisteet         = 0;
    _virhe           = null;
    _onLataus        = false;
    notifyListeners();
  }

  /// Vapautetaan käännöspalvelun resurssit
  @override
  void dispose() {
    _translator.close();
    super.dispose();
  }
}
