import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AsetuksetTarjoaja with ChangeNotifier {
  bool _aanetKaytossa = true;
  int _aanenVoimakkuus = 50; // Oletuksena äänenvoimakkuus on 50%
  String _kieli = 'fi'; // Oletuksena kieli on englanti

  bool get aanetKaytossa => _aanetKaytossa;
  int get aanenVoimakkuus => _aanenVoimakkuus;
  String get kieli => _kieli; // Uusi getter kielelle

  AsetuksetTarjoaja() {
    _lataaAsetukset();
  }

  void _lataaAsetukset() async {
    final prefs = await SharedPreferences.getInstance();
    _aanetKaytossa = prefs.getBool('aanet_kaytossa') ?? true;
    _aanenVoimakkuus = prefs.getInt('aanen_voimakkuus') ?? 50;
    _kieli = prefs.getString('kieli') ?? 'en'; // Lataa kieli, oletuksena englanti
    notifyListeners();
  }

  void muutaAanetKayttoon(bool kayttoon) async {
    _aanetKaytossa = kayttoon;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aanet_kaytossa', kayttoon);
    notifyListeners();
  }

  void asetaAanenVoimakkuus(int uusiVoimakkuus) async {
    _aanenVoimakkuus = uusiVoimakkuus;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('aanen_voimakkuus', uusiVoimakkuus);
    notifyListeners();
  }

  // Uusi funktio kielen asettamiseen ja tallentamiseen
  void asetaKieli(String uusiKieli) async {
    _kieli = uusiKieli;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kieli', uusiKieli);
    notifyListeners();
  }
}