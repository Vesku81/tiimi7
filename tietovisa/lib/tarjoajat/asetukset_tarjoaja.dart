import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences asetusten tallentamiseen ja lataamiseen

// AsetuksetTarjoaja hallinnoi sovelluksen asetuksia, kuten esimerkiksi ääntä
class AsetuksetTarjoaja with ChangeNotifier {
  bool _aanetKaytossa = true; // Oletuksena äänet ovat päällä
  int _aanenVoimakkuus = 0; // Oletuksena äänenvoimakkuus on 50%

  // Getterit tarjoavat asetusten tiedot
  bool get aanetKaytossa => _aanetKaytossa; // Palauttaa, ovatko äänet käytössä
  int get aanenVoimakkuus => _aanenVoimakkuus; // Palauttaa äänenvoimakkuuden

  // Konstruktori, joka lataa asetukset sovelluksen käynnistyessä
  AsetuksetTarjoaja() {
    _lataaAsetukset(); // Lataa asetukset SharedPreferencesista
  }

  // Lataa asetukset SharedPreferencesista
  void _lataaAsetukset() async {
    final prefs = await SharedPreferences.getInstance(); // Hakee SharedPreferences-instanssin
    _aanetKaytossa = prefs.getBool('aanet_kaytossa') ?? true; // Lataa "äänet käytössä" -asetus, oletuksena true
    _aanenVoimakkuus = prefs.getInt('aanen_voimakkuus') ?? 50; // Lataa äänenvoimakkuus, oletuksena 50%
    notifyListeners(); // Ilmoittaa kuuntelijoille, että asetukset ovat muuttuneet
  }

  // Muuttaa "äänet käytössä" -asetusta ja tallentaa sen
  void muutaAanetKayttoon(bool kayttoon) async {
    _aanetKaytossa = kayttoon; // Päivittää arvon
    final prefs = await SharedPreferences.getInstance(); // Hakee SharedPreferences-instanssin
    await prefs.setBool('aanet_kaytossa', kayttoon); // Tallentaa arvon SharedPreferencesiin
    notifyListeners(); // Ilmoittaa kuuntelijoille, että asetus on muuttunut
  }

  // Asettaa uuden äänenvoimakkuuden ja tallentaa sen
  void asetaAanenVoimakkuus(int uusiVoimakkuus) async {
    _aanenVoimakkuus = uusiVoimakkuus; // Päivittää äänenvoimakkuuden
    final prefs = await SharedPreferences.getInstance(); // Hakee SharedPreferences-instanssin
    await prefs.setInt('aanen_voimakkuus', uusiVoimakkuus); // Tallentaa uuden äänenvoimakkuuden SharedPreferencesiin
    notifyListeners(); // Ilmoittaa kuuntelijoille, että äänenvoimakkuus on muuttunut
  }
}
