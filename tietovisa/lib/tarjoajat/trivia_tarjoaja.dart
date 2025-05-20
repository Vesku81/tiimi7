// trivia_tarjoaja.dart
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
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.finnish,
  );
  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();

  TriviaTarjoaja() {
    _modelManager.downloadModel(TranslateLanguage.english.bcpCode);
    _modelManager.downloadModel(TranslateLanguage.finnish.bcpCode);
  }

  List<Kysymys> get kysymykset => _kysymykset;
  int get nykyinenIndeksi => _nykyinenIndeksi;
  int get pisteet => _pisteet;
  bool get onLataus => _onLataus;
  String? get virhe => _virhe;

  /// Hakee kysymykset joko OpenAI:sta tai perinteisestä API:sta
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
    _esitetytKysymyksetTekstit.clear();
    notifyListeners();

    try {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      final kaytaOpenAI = asetukset.kaytaOpenAIKysymyksia;
      final kaytaKaannokset = asetukset.kaytaKaannokset;
      final String valittuAihealue = asetukset.valittuAihealue;

      List<Kysymys> lopulliset = [];

      if (kaytaOpenAI) {
        // --- OpenAI-haara ---
        List<Kysymys> generoidut = [];
        int yrityksetYht = 0;
        const int maksYritykset = 25;

        while (generoidut.length < maara && yrityksetYht < maksYritykset) {
          Kysymys? kys;
          String? norm;
          int perKysYr = 0;
          const int maksPer = 3;

          do {
            kys = await _openAIPalvelu.generoiKysymys(valittuAihealue, vaikeus);
            norm = kys?.kysymysTeksti.trim().toLowerCase();
            perKysYr++;
            yrityksetYht++;

            if (norm != null && _esitetytKysymyksetTekstit.contains(norm)) {
              kys = null;
            }
            if (kys == null && perKysYr < maksPer && yrityksetYht < maksYritykset) {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          } while (kys == null && perKysYr < maksPer && yrityksetYht < maksYritykset);

          if (kys != null && norm != null) {
            generoidut.add(kys);
            _esitetytKysymyksetTekstit.add(norm);
            if (generoidut.length < maara && yrityksetYht < maksYritykset) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
        }

        if (generoidut.length < maara) {
          _virhe = generoidut.isEmpty
              ? 'OpenAI ei generoitu aineistoa aiheesta "$valittuAihealue".'
              : 'OpenAI generoi vain ${generoidut.length} kysymystä pyydetyistä $maara.';
        }
        lopulliset = generoidut;
      } else {
        // --- Perinteinen API-haara ---
        final int categoryId = _mapAihealueToCategoryId(valittuAihealue);
        List<Kysymys> alkuper = await _triviaApiPalvelu.haeKysymykset(maara, vaikeus, categoryId);
        List<Kysymys> kasiteltavat = [];
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

        if (kaytaKaannokset && _translator.targetLanguage != TranslateLanguage.english) {
          List<Kysymys> kaannetyt = [];
          for (var q in kasiteltavat) {
            try {
              final teksti = await _translator.translateText(q.kysymysTeksti);
              final oikea = await _translator.translateText(q.oikeaVastaus);
              final vaarat = <String>[];
              for (var v in q.vaaratVastaukset) {
                vaarat.add(await _translator.translateText(v));
              }
              kaannetyt.add(Kysymys(
                kategoria: q.kategoria,
                tyyppi: q.tyyppi,
                vaikeus: q.vaikeus,
                kysymysTeksti: teksti,
                oikeaVastaus: oikea,
                vaaratVastaukset: vaarat,
              ));
            } catch (_) {}
          }
          lopulliset = kaannetyt;
        } else {
          lopulliset = kasiteltavat;
        }
      }

      _kysymykset = lopulliset;
      if (_kysymykset.isEmpty && _virhe == null && maara > 0) {
        _virhe = 'Kysymyksiä ei löytynyt valituilla asetuksilla.';
      }
    } catch (e) {
      _virhe = 'Kysymysten haussa virhe: $e';
      debugPrint('HaeKys kysymysvirhe: $e');
      _kysymykset = [];
    } finally {
      _onLataus = false;
      notifyListeners();
    }
  }

  // Karttaa suomenkielisen aihealueen Open Trivia DB:n category-id:hen
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

  void vastaaKysymykseen(bool oikein) {
    if (_nykyinenIndeksi < _kysymykset.length) {
      _pisteet += oikein ? 20 : -5;
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
    notifyListeners();
  }

  @override
  void dispose() {
    _translator.close();
    super.dispose();
  }
}
