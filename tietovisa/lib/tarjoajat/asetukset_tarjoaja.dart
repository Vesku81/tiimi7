import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AsetuksetTarjoaja with ChangeNotifier {
  int _aanenVoimakkuus = 50; // Oletusäänenvoimakkuus
  bool _aanetKaytossa = true; // Oletuksena äänet päällä
  String _kieli = 'fi'; // Oletuskieli suomi
  // Uusi asetus: haetaanko kysymykset paikallisesti (true) vai API:sta (false)
  bool _haePaikallisesti = false; // Oletuksena haetaan API:sta

  int get aanenVoimakkuus => _aanenVoimakkuus;
  bool get aanetKaytossa => _aanetKaytossa;
  String get kieli => _kieli;
  // Getter uudelle asetukselle
  bool get haePaikallisesti => _haePaikallisesti;

  AsetuksetTarjoaja() {
    _lataaAsetukset(); // Ladataan asetukset käynnistyksen yhteydessä
  }

  // Funktio asetusten lataamiseen SharedPreferencesista
  Future<void> _lataaAsetukset() async {
    final prefs = await SharedPreferences.getInstance();
    _aanenVoimakkuus = prefs.getInt('aanenVoimakkuus') ?? 50;
    _aanetKaytossa = prefs.getBool('aanetKaytossa') ?? true;
    _kieli = prefs.getString('kieli') ?? 'fi';
    // Ladataan uusi asetus
    _haePaikallisesti = prefs.getBool('haePaikallisesti') ?? false;
    notifyListeners();
  }

  // Funktio äänenvoimakkuuden asettamiseen
  void setAanenVoimakkuus(int voimakkuus) {
    _aanenVoimakkuus = voimakkuus;
    _tallennaAsetukset(); // Tallennetaan asetus
    notifyListeners();
  }

  // Funktio äänten käytön asettamiseen
  void setAanetKaytossa(bool kaytossa) {
    _aanetKaytossa = kaytossa;
    _tallennaAsetukset(); // Tallennetaan asetus
    notifyListeners();
  }

  // Funktio kielen asettamiseen
  void setKieli(String kieli) {
    _kieli = kieli;
    _tallennaAsetukset(); // Tallennetaan asetus
    notifyListeners();
  }

  // Funktio kysymysten hakutavan asettamiseen
  void setHaePaikallisesti(bool paikallisesti) {
    _haePaikallisesti = paikallisesti;
    _tallennaAsetukset(); // Tallennetaan asetus
    notifyListeners();
  }

  // Funktio asetusten tallentamiseen SharedPreferencesiin
  Future<void> _tallennaAsetukset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('aanenVoimakkuus', _aanenVoimakkuus);
    await prefs.setBool('aanetKaytossa', _aanetKaytossa);
    await prefs.setString('kieli', _kieli);
    // Tallennetaan uusi asetus
    await prefs.setBool('haePaikallisesti', _haePaikallisesti);
  }
}