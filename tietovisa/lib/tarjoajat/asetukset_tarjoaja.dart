import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AsetuksetTarjoaja with ChangeNotifier {
  bool _aanetKaytossa = true;
  int _aanenVoimakkuus = 50;
  bool _kaytaSpeechToText = false;
  double _ttsRate = 0.5;
  double _ttsPitch = 1.0;
  bool _kaytaKaannokset = false;  // Käännösten käyttöasetus

  // Getterit
  bool get aanetKaytossa => _aanetKaytossa;
  int get aanenVoimakkuus => _aanenVoimakkuus;
  bool get kaytaSpeechToText => _kaytaSpeechToText;
  double get ttsRate => _ttsRate;
  double get ttsPitch => _ttsPitch;
  bool get kaytaKaannokset => _kaytaKaannokset;  // Getter käännöksille

  // Setterit
  set kaytaSpeechToText(bool val) => _setSpeechToText(val);
  set ttsRate(double val) => _setTtsRate(val);
  set ttsPitch(double val) => _setTtsPitch(val);
  set kaytaKaannokset(bool val) => _setKaytaKaannokset(val);  // Setter käännöksille

  AsetuksetTarjoaja() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _aanetKaytossa = prefs.getBool('aanet_kaytossa') ?? true;
    _aanenVoimakkuus = prefs.getInt('aanen_voimakkuus') ?? 50;
    _kaytaSpeechToText = prefs.getBool('kayta_speech_to_text') ?? false;
    _ttsRate = prefs.getDouble('tts_rate') ?? 0.5;
    _ttsPitch = prefs.getDouble('tts_pitch') ?? 1.0;
    _kaytaKaannokset = prefs.getBool('kayta_kaannokset') ?? false;
    notifyListeners();
  }

  Future<void> muutaAanetKayttoon(bool val) async {
    _aanetKaytossa = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aanet_kaytossa', val);
    notifyListeners();
  }

  Future<void> asetaAanenVoimakkuus(int val) async {
    _aanenVoimakkuus = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('aanen_voimakkuus', val);
    notifyListeners();
  }

  Future<void> _setSpeechToText(bool val) async {
    _kaytaSpeechToText = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kayta_speech_to_text', val);
    notifyListeners();
  }

  Future<void> _setTtsRate(double val) async {
    _ttsRate = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_rate', val);
    notifyListeners();
  }

  Future<void> _setTtsPitch(double val) async {
    _ttsPitch = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_pitch', val);
    notifyListeners();
  }

  // Uusi metodi käännösten asetukselle
  Future<void> _setKaytaKaannokset(bool val) async {
    _kaytaKaannokset = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kayta_kaannokset', val);
    notifyListeners();
  }
}
