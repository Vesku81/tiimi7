import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Palvelu, joka huolehtii puheentunnistuksesta (STT) ja puheen synteesistä (TTS).
class Puhepalvelu {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechEnabled = false;
  bool _isListening = false;

  /// True, kun puheentunnistus on alustettu ja käytettävissä.
  bool get isInitialized => _speechEnabled;

  /// True, kun puheentunnistus on käynnissä.
  bool get isListening => _isListening;

  /// Alustaa puheentunnistuksen ja pyytää mikrofonin käyttöoikeudet.
  Future<bool> initSpeech() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    if (!status.isGranted) {
      debugPrint('Mikrofonin käyttöoikeus evätty. Puheentunnistus ei käytössä.');
      _speechEnabled = false;
      return false;
    }
    _speechEnabled = await _speechToText.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    if (!_speechEnabled) debugPrint('Speech-to-Text alustus epäonnistui.');
    return _speechEnabled;
  }

  void _onSpeechStatus(String status) {
    debugPrint('Puheentunnistuksen tila: $status');
    _isListening = _speechToText.isListening;
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('Puheentunnistusvirhe: ${error.errorMsg}');
    _isListening = false;
  }

  /// Käynnistä puheen kuuntelu [listenFor] ajan ja palauta lopullinen tulos [onResult]-callbackiin.
  Future<void> startListening({
    required void Function(String recognized) onResult,
    Duration listenFor = const Duration(seconds: 5),
    String localeId = 'fi_FI',
  }) async {
    if (!_speechEnabled || _isListening) return;
    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) onResult(result.recognizedWords);
      },
      listenFor: listenFor,
      localeId: localeId,
    );
    _isListening = _speechToText.isListening;
  }

  /// Lopeta puheen kuuntelu.
  void stopListening() {
    _speechToText.stop();
    _isListening = false;
  }

  /// Puheen synteesi: lukee [text] ääneen käyttäen [rate], [pitch], [volume] ja [language]-asetuksia.
  Future<void> speak(
      String text, {
        double rate = 0.5,
        double pitch = 1.0,
        double volume = 1.0,
        String language = 'fi-FI',
      }) async {
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    await _tts.speak(text);
  }

  /// Vapauttaa resurssit.
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
    _tts.stop();
  }
}
