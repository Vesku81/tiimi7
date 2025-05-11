import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Tuodaan Provider
import '../mallit/kysymys.dart';
import '../palvelut/trivia_api_palvelu.dart';
import 'asetukset_tarjoaja.dart'; // Tuodaan AsetuksetTarjoaja

class TriviaTarjoaja with ChangeNotifier {
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

  // Muutetaan funktion signaturea ottamaan vastaan BuildContext
  Future<void> haeKysymykset(int maara, String vaikeus, BuildContext context) async {
    _onLataus = true;
    _virhe = null;
    notifyListeners();

    try {
      // Haetaan valittu kieli AsetuksetTarjoajasta Providerin avulla
      final asetuksetTarjoaja = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      final kohdeKieli = asetuksetTarjoaja.kieli;

      // Haetaan kysymykset Trivia API-palvelusta ja välitetään kohdekieli
      _kysymykset = await TriviaApiPalvelu().haeKysymykset(maara, vaikeus, kohdeKieli);

      _nykyinenIndeksi = 0;
      _pisteet = 0;
    } catch (e) {
      _kysymykset = [];
      _virhe = "Kysymysten lataaminen epäonnistui.";
      print('Virhe kysymysten haussa TriviaTarjoajassa: $e'); // Lisätään tarkempi virhetulostus
    } finally {
      _onLataus = false;
      notifyListeners();
    }
  }

  void vastaaKysymykseen(bool oikein) {
    if (oikein) {
      _pisteet += 20;
    } else {
      _pisteet -= 5;
    }
    notifyListeners();
  }

  void seuraavaKysymys() {
    if (_nykyinenIndeksi < _kysymykset.length - 1) {
      _nykyinenIndeksi++;
    }
    notifyListeners();
  }

  void nollaaPeli() {
    _nykyinenIndeksi = 0;
    _pisteet = 0;
    notifyListeners();
  }
}