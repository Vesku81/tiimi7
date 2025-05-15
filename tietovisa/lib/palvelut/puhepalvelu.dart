import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Puhepalvelu {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts    = FlutterTts();

  /// Alusta puheentunnistus.
  Future<bool> initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error)   => print('Speech error: $error'),
    );
    return available;
  }

  /// Aloita kuuntelemaan puhetta.
  Future<void> startListening({
    required void Function(String recognized) onResult,
  }) async {
    await _speech.listen(onResult: (result) {
      if (result.finalResult) {
        onResult(result.recognizedWords);
      }
    });
  }

  /// Lopeta kuuntelu.
  Future<void> stopListening() async {
    await _speech.stop();
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
    _tts.stop();
    _tts.awaitSpeakCompletion(true);
  }
}
