// tarjoajat/asetukset_tarjoaja.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vastaa sovelluksen asetusten hallinnasta ja
/// niiden pysyväistallennuksesta Shared Preferences -kirjaston avulla.
class AsetuksetTarjoaja with ChangeNotifier {
  // Avainmerkkijonot SharedPreferencesin kentille
  static const String _kaytaOpenAIKey         = 'kayta_openai_kysymyksia';
  static const String _valittuAihealueKey     = 'valittu_aihealue';
  static const String _valittuVaikeustasoKey  = 'valittu_vaikeustaso';
  static const String _aanetKaytossaKey       = 'aanet_kaytossa';
  static const String _aanenVoimakkuusKey     = 'aanen_voimakkuus';
  static const String _kaytaSpeechToTextKey   = 'kayta_speech_to_text';
  static const String _ttsRateKey             = 'tts_rate';
  static const String _ttsPitchKey            = 'tts_pitch';
  static const String _kaytaKaannoksetKey     = 'kayta_kaannokset';
  static const String _kaytaTtsKey            = 'kayta_tts'; // uusi asetustunniste

  // Sisäiset kenttämuuttujat
  bool    _kaytaOpenAIKysymyksia = false;      // Käytetäänkö OpenAI:ta
  String  _valittuAihealue       = 'yleistieto';// Valittu aihealue
  String  _valittuVaikeustaso    = 'Helppo';    // Valittu vaikeustaso
  bool    _aanetKaytossa         = true;        // Soitetaanko pelin äänet
  int     _aanenVoimakkuus       = 50;          // Äänen voimakkuus (0–100)
  bool    _kaytaSpeechToText     = false;       // Käytetäänkö puheentunnistusta
  double  _ttsRate               = 0.5;         // Tekstistä puheeksi -puhenopeus
  double  _ttsPitch              = 1.0;         // Tekstistä puheeksi -puhekorkeus
  bool    _kaytaKaannokset       = false;       // Käytetäänkö käännöksiä
  bool    _kaytaTts              = false;       // Lue kysymykset ääneen -asetus

  // Mahdolliset valinnat dropdowneihin
  final List<String> saatavillaOlevatAihealueet = [
    'yleistieto','historia','maantieto','tiede','viihde',
    'urheilu','taide ja kirjallisuus','musiikki','elokuvat','luonto',
  ];
  final List<String> vaikeustasot = ['Helppo','Keskitaso','Vaikea'];

  // --- GETTERIT asetusarvoille ---
  bool   get kaytaOpenAIKysymyksia => _kaytaOpenAIKysymyksia;
  String get valittuAihealue       => _valittuAihealue;
  String get valittuVaikeustaso    => _valittuVaikeustaso;
  List<String> get aihealueet     => saatavillaOlevatAihealueet;
  List<String> get kaikkiVaikeustasot => vaikeustasot;
  bool   get aanetKaytossa         => _aanetKaytossa;
  int    get aanenVoimakkuus       => _aanenVoimakkuus;
  bool   get kaytaSpeechToText     => _kaytaSpeechToText;
  double get ttsRate               => _ttsRate;
  double get ttsPitch              => _ttsPitch;
  bool   get kaytaKaannokset       => _kaytaKaannokset;
  bool   get kaytaTts              => _kaytaTts;

  /// Konstruktori lataa tallennetut arvot (asynkronisesti).
  AsetuksetTarjoaja() {
    _load();
  }

  /// Lataa kaikki asetukset SharedPreferencesista ja
  /// ilmoittaa kuuntelijoille notifyListeners().
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _kaytaOpenAIKysymyksia = prefs.getBool(_kaytaOpenAIKey) ?? false;
    _valittuAihealue       = prefs.getString(_valittuAihealueKey) ?? 'yleistieto';
    _valittuVaikeustaso    = prefs.getString(_valittuVaikeustasoKey) ?? vaikeustasot.first;
    _aanetKaytossa         = prefs.getBool(_aanetKaytossaKey) ?? true;
    _aanenVoimakkuus       = prefs.getInt(_aanenVoimakkuusKey) ?? 50;
    _kaytaSpeechToText     = prefs.getBool(_kaytaSpeechToTextKey) ?? false;
    _ttsRate               = prefs.getDouble(_ttsRateKey) ?? 0.5;
    _ttsPitch              = prefs.getDouble(_ttsPitchKey) ?? 1.0;
    _kaytaKaannokset       = prefs.getBool(_kaytaKaannoksetKey) ?? false;
    _kaytaTts              = prefs.getBool(_kaytaTtsKey) ?? false;
    notifyListeners();
  }

  // --- Asetusten asettavat metodit ---
  // Jokainen metodi päivittää sisäisen kentän, tallentaa arvon pysyvästi
  // ja kutsuu notifyListeners(), jotta UI päivittyy automaattisesti.

  Future<void> asetaKaytaOpenAI(bool val) async {
    _kaytaOpenAIKysymyksia = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kaytaOpenAIKey, val);
    notifyListeners();
  }

  Future<void> asetaValittuAihealue(String? uusiAihealue) async {
    if (uusiAihealue != null && saatavillaOlevatAihealueet.contains(uusiAihealue)) {
      _valittuAihealue = uusiAihealue;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_valittuAihealueKey, uusiAihealue);
      notifyListeners();
    }
  }

  Future<void> asetaValittuVaikeustaso(String? uusiTaso) async {
    if (uusiTaso != null && vaikeustasot.contains(uusiTaso)) {
      _valittuVaikeustaso = uusiTaso;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_valittuVaikeustasoKey, uusiTaso);
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

  Future<void> asetaKaytaTts(bool val) async {
    _kaytaTts = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kaytaTtsKey, val);
    notifyListeners();
  }
}
