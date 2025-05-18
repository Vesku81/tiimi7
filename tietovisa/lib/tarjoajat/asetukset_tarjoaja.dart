// tarjoajat/asetukset_tarjoaja.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AsetuksetTarjoaja with ChangeNotifier {
  // Avaimet SharedPreferences varten
  static const String _kaytaOpenAIKey = 'kayta_openai_kysymyksia';
  static const String _valittuAihealueKey = 'valittu_aihealue'; // UUSI AVAIN
  static const String _aanetKaytossaKey = 'aanet_kaytossa';
  static const String _aanenVoimakkuusKey = 'aanen_voimakkuus';
  static const String _kaytaSpeechToTextKey = 'kayta_speech_to_text';
  static const String _ttsRateKey = 'tts_rate';
  static const String _ttsPitchKey = 'tts_pitch';
  static const String _kaytaKaannoksetKey = 'kayta_kaannokset';

  // Tilamuuttujat
  bool _kaytaOpenAIKysymyksia = false;
  String _valittuAihealue = 'yleistieto'; // UUSI MUUTTUJA, oletusaihe
  bool _aanetKaytossa = true;
  int _aanenVoimakkuus = 50;
  bool _kaytaSpeechToText = false;
  double _ttsRate = 0.5;
  double _ttsPitch = 1.0;
  bool _kaytaKaannokset = false;

  // Lista käytettävissä olevista aihealueista
  // Voit lisätä tai muokata näitä tarpeen mukaan
  final List<String> saatavillaOlevatAihealueet = [
    'yleistieto',
    'historia',
    'maantieto',
    'tiede',
    'viihde',
    'urheilu',
    'taide ja kirjallisuus',
    'musiikki',
    'elokuvat',
    'luonto',
  ];

  // Getterit
  bool get kaytaOpenAIKysymyksia => _kaytaOpenAIKysymyksia;
  String get valittuAihealue => _valittuAihealue; // UUSI GETTER
  List<String> get aihealueet => saatavillaOlevatAihealueet; // Getter aihealueille
  bool get aanetKaytossa => _aanetKaytossa;
  int get aanenVoimakkuus => _aanenVoimakkuus;
  bool get kaytaSpeechToText => _kaytaSpeechToText;
  double get ttsRate => _ttsRate;
  double get ttsPitch => _ttsPitch;
  bool get kaytaKaannokset => _kaytaKaannokset;

  AsetuksetTarjoaja() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _kaytaOpenAIKysymyksia = prefs.getBool(_kaytaOpenAIKey) ?? false;
    _valittuAihealue = prefs.getString(_valittuAihealueKey) ?? 'yleistieto'; // Ladataan valittu aihealue
    _aanetKaytossa = prefs.getBool(_aanetKaytossaKey) ?? true;
    _aanenVoimakkuus = prefs.getInt(_aanenVoimakkuusKey) ?? 50;
    _kaytaSpeechToText = prefs.getBool(_kaytaSpeechToTextKey) ?? false;
    _ttsRate = prefs.getDouble(_ttsRateKey) ?? 0.5;
    _ttsPitch = prefs.getDouble(_ttsPitchKey) ?? 1.0;
    _kaytaKaannokset = prefs.getBool(_kaytaKaannoksetKey) ?? false;
    notifyListeners();
  }

  // Metodit asetusten muuttamiseen ja tallentamiseen

  Future<void> asetaKaytaOpenAI(bool val) async {
    _kaytaOpenAIKysymyksia = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kaytaOpenAIKey, val);
    notifyListeners();
  }

  Future<void> asetaValittuAihealue(String? uusiAihealue) async { // UUSI METODI
    if (uusiAihealue != null && saatavillaOlevatAihealueet.contains(uusiAihealue)) {
      _valittuAihealue = uusiAihealue;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_valittuAihealueKey, uusiAihealue);
      notifyListeners();
    }
  }

  Future<void> asetaAanetKaytossa(bool val) async {
    _aanetKaytossa = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aanetKaytossaKey, val);
    notifyListeners();
  }

  Future<void> asetaAanenVoimakkuus(int val) async {
    _aanenVoimakkuus = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aanenVoimakkuusKey, val);
    notifyListeners();
  }

  Future<void> asetaKaytaSpeechToText(bool val) async {
    _kaytaSpeechToText = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kaytaSpeechToTextKey, val);
    notifyListeners();
  }

  Future<void> asetaTtsRate(double val) async {
    _ttsRate = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ttsRateKey, val);
    notifyListeners();
  }

  Future<void> asetaTtsPitch(double val) async {
    _ttsPitch = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ttsPitchKey, val);
    notifyListeners();
  }

  Future<void> asetaKaytaKaannokset(bool val) async {
    _kaytaKaannokset = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kaytaKaannoksetKey, val);
    notifyListeners();
  }
}