import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart'; // Tarvitaan SpeechRecognitionResult varten
import 'package:speech_to_text/speech_recognition_error.dart'; // Tarvitaan SpeechRecognitionError varten
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart'; // Tarvitaan debugPrint varten
import 'package:permission_handler/permission_handler.dart'; // Käyttöoikeuksien hallintaan

class Puhepalvelu {
  final SpeechToText _speechToText = SpeechToText(); // Muutettu nimeksi _speechToText selkeyden vuoksi
  final FlutterTts _tts    = FlutterTts();

  bool _speechEnabled = false; // Lisätty tila puheentunnistuksen saatavuudelle
  bool _isListening = false; // Lisätty tila kuuntelulle

  // Getter saatavuuden tarkistamiseen
  bool get isInitialized => _speechEnabled;

  // Getter kuuntelutilan tarkistamiseen
  bool get isListening => _isListening;


  /// Alustaa puheentunnistuksen. Tarkistaa saatavuuden ja pyytää luvan.
  Future<bool> initSpeech() async {
    // Tarkista ja pyydä mikrofonin käyttöoikeus
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      _speechEnabled = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      if (!_speechEnabled) {
        debugPrint('Speech-to-Text alustus epäonnistui.');
      }
      return _speechEnabled;
    } else {
      debugPrint("Mikrofonin käyttöoikeus evätty. Puheentunnistus ei käytössä.");
      _speechEnabled = false;
      return false;
    }
  }

  /// Käsittelee puheentunnistuksen tilan muutokset.
  void _onSpeechStatus(String status) {
    debugPrint('Puheentunnistuksen tila: $status');
    _isListening = _speechToText.isListening; // Päivitä kuuntelutila
    // Voit lisätä tässä logiikkaa ilmoittamaan tilan muutoksista (esim. StreamController)
  }

  /// Käsittelee puheentunnistuksen virheet.
  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('Puheentunnistusvirhe: ${error.errorMsg}');
    _isListening = false; // Lopeta kuuntelutila virheen sattuessa
    // Voit lisätä tässä logiikkaa virheiden ilmoittamiseen
  }


  /// Aloita kuuntelemaan puhetta määritellyn ajan.
  Future<void> startListening({
    required void Function(String recognized) onResult,
    Duration listenFor = const Duration(seconds: 5), // Asetettu oletusarvoksi 5 sekuntia
  }) async {
    if (_speechEnabled && !_isListening) {
      await _speechToText.listen(onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
        listenFor: listenFor, // Käytetään listenFor parametriä
        localeId: 'fi_FI', // Aseta kieli (esim. suomi)
      );
      _isListening = _speechToText.isListening; // Päivitä tila
    } else if (!_speechEnabled) {
      debugPrint("Puheentunnistus ei ole käytössä.");
    }
  }

  /// Lopeta kuuntelu.
  void stopListening() {
    _speechToText.stop();
    _isListening = false; // Päivitä tila
  }

  /// Lue teksti ääneen.
  Future<void> speak(String text) async {
    await _tts.setLanguage('fi-FI');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  /// Vapauta resurssit.
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel(); // Peruuta kaikki meneillään olevat toiminnot
    _tts.stop();
    // _tts.awaitSpeakCompletion(true); // Tätä ei yleensä tarvita dispose-metodissa
  }
}