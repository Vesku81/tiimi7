import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../mallit/kysymys.dart';
import '../palvelut/trivia_api_palvelu.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'asetukset_tarjoaja.dart';

/// Triviatarjoaja hallinnoi sovelluksen trivia-tietoja ja pelin tilaa
class TriviaTarjoaja with ChangeNotifier {
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

  /// Hakee kysymykset Trivia API:sta ja kääntää ne tarvittaessa
  Future<void> haeKysymykset(
      int maara,
      String vaikeus,
      BuildContext context,
      ) async {
    _onLataus = true;
    _virhe = null;
    notifyListeners();

    try {
      // 1) Tarkistetaan käyttäjän asetus
      final kaannokset = Provider.of<AsetuksetTarjoaja>(
        context,
        listen: false,
      ).kaytaKaannokset;

      // 2) Haetaan alkuperäiset kysymykset
      final raw = await TriviaApiPalvelu().haeKysymykset(maara, vaikeus);

      if (kaannokset &&
          _translator.targetLanguage != TranslateLanguage.english) {
        // 3) Käyttäjä haluaa käännökset, ja kohdekieli ei ole englanti
        final List<Kysymys> lista = [];
        for (var q in raw) {
          final teksti =
          await _translator.translateText(q.kysymysTeksti);
          final oikea =
          await _translator.translateText(q.oikeaVastaus);
          final vaarat = <String>[];
          for (var v in q.vaaratVastaukset) {
            vaarat.add(await _translator.translateText(v));
          }
          lista.add(Kysymys(
            kategoria: q.kategoria,
            tyyppi: q.tyyppi,
            vaikeus: q.vaikeus,
            kysymysTeksti: teksti,
            oikeaVastaus: oikea,
            vaaratVastaukset: vaarat,
          ));
        }
        _kysymykset = lista;
      } else {
        // 4) Ei käännöksiä tai englanti: käytetään suoraan
        _kysymykset = raw;
      }

      // Nollataan pelin tila
      _nykyinenIndeksi = 0;
      _pisteet = 0;
    } catch (e) {
      _kysymykset = [];
      _virhe = "Kysymysten lataaminen epäonnistui.";
    } finally {
      _onLataus = false;
      notifyListeners();
    }
  }

  /// Käsittelee pelaajan vastauksen
  void vastaaKysymykseen(bool oikein) {
    if (oikein) {
      _pisteet += 20;
    } else {
      _pisteet -= 5;
    }
    notifyListeners();
  }

  /// Siirtyy seuraavaan kysymykseen
  void seuraavaKysymys() {
    if (_nykyinenIndeksi < _kysymykset.length - 1) {
      _nykyinenIndeksi++;
      notifyListeners();
    }
  }

  /// Nollaa pelin tilan
  void nollaaPeli() {
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    notifyListeners();
  }

  /// Suljetaan kääntäjä resurssien vapauttamiseksi
  void disposeTranslator() {
    _translator.close();
  }
}
