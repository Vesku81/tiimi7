import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import '../mallit/kysymys.dart'; // Kysymys-malli kysymysten hallintaan
import '../palvelut/trivia_api_palvelu.dart'; // Trivia API rajapinnan palvelut kysymysten hakuun

// Triviatarjoaja hallinnoi sovelluksen trivia-tietoja ja pelin tilaa
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

  // Getterit tarjoavat pääsyn yksityisiin muuttujiin
  List<Kysymys> get kysymykset => _kysymykset; // Palauttaa kysymykset
  int get nykyinenIndeksi => _nykyinenIndeksi; // Palauttaa nykyisen indeksin
  int get pisteet => _pisteet; // Palauttaa pistemäärän
  bool get onLataus => _onLataus; // Palauttaa lataustilan
  String? get virhe => _virhe; // Palauttaa virheviestin, jos sellainen on

  // Hakee kysymykset Trivia API rajapinnan kautta
  Future<void> haeKysymykset(int maara, String vaikeus) async {
    _onLataus = true; // Ilmoittaa, että kysymyksiä ladataan
    _virhe = null; // Nollataan mahdollinen aiempi virhe
    notifyListeners(); // Ilmoittaa kuuntelijoille tilamuutoksista

    try {
      // Haetaan kysymykset Trivia API-palvelusta
      _kysymykset = await TriviaApiPalvelu().haeKysymykset(maara, vaikeus);

      // Nollataan pelin tila
      _nykyinenIndeksi = 0;
      _pisteet = 0;
    } catch (e) {
      // Jos tapahtuu virhe, asetetaan virheviesti ja tyhjennetään kysymykset
      _kysymykset = [];
      _virhe = "Kysymysten lataaminen epäonnistui.";
    } finally {
      _onLataus = false; // Lopetetaan lataustila
      notifyListeners(); // Ilmoitetaan kuuntelijoille tilamuutoksista
    }
  }

  // Käsittelee vastauksen kysymykseen
  void vastaaKysymykseen(bool oikein) {
    // Päivittää pisteet oikean/väärän vastauksen perusteella
    if (oikein) {
      _pisteet += 20; // Lisää +20 pisteitä oikeasta vastauksesta
    } else {
      _pisteet -= 5; // Vähentää -5 pisteitä väärästä vastauksesta
    }
    notifyListeners(); // Ilmoittaa kuuntelijoille tilamuutoksista
  }

  // Siirtyy seuraavaan kysymykseen
  void seuraavaKysymys() {
    if (_nykyinenIndeksi < _kysymykset.length - 1) {
      _nykyinenIndeksi++; // Kasvatetaan indeksiä
    }
    notifyListeners(); // Ilmoittaa kuuntelijoille tilamuutoksista
  }

  // Nollaa pelin tilan
  void nollaaPeli() {
    _nykyinenIndeksi = 0; // Palautetaan indeksi alkuun
    _pisteet = 0; // Nollataan pisteet
    notifyListeners(); // Ilmoittaa kuuntelijoille tilamuutoksista
  }
}
