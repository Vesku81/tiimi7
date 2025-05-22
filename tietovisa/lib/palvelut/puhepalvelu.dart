// Tuodaan tarvittavat paketit.
import 'package:speech_to_text/speech_to_text.dart'; // Puheentunnistukseen (Speech-to-Text, STT).
import 'package:speech_to_text/speech_recognition_result.dart'; // STT:n tulosobjekti.
import 'package:speech_to_text/speech_recognition_error.dart'; // STT:n virheobjekti.
import 'package:flutter_tts/flutter_tts.dart'; // Puhesynteesiin (Text-to-Speech, TTS).
import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja työkalut (esim. debugPrint).
import 'package:permission_handler/permission_handler.dart'; // Käyttöoikeuksien hallintaan (esim. mikrofoni).

/// Palvelu, joka huolehtii puheentunnistuksesta (STT) ja puheen synteesistä (TTS).
/// Tämä luokka kapseloi STT- ja TTS-toiminnallisuudet yhteen paikkaan,
/// jotta niitä on helpompi käyttää ja hallita sovelluksessa.
class Puhepalvelu {
  // SpeechToText-instanssi puheentunnistusta varten.
  final SpeechToText _speechToText = SpeechToText();
  // FlutterTts-instanssi puhesynteesiä varten.
  final FlutterTts _tts = FlutterTts();

  // Lippu, joka kertoo, onko puheentunnistus onnistuneesti alustettu.
  bool _speechEnabled = false;
  // Lippu, joka kertoo, onko puheentunnistus tällä hetkellä aktiivisesti kuuntelemassa.
  bool _isListening = false;

  /// Getter: Palauttaa true, jos puheentunnistus on alustettu ja käytettävissä.
  /// Muualta koodista voidaan tarkistaa tämä ennen STT-toimintojen kutsumista.
  bool get isInitialized => _speechEnabled;

  /// Getter: Palauttaa true, jos puheentunnistus on tällä hetkellä käynnissä (kuuntelee).
  bool get isListening => _isListening;

  /// Alustaa puheentunnistuksen.
  /// Pyytää ensin mikrofonin käyttöoikeuden, jos sitä ei ole vielä myönnetty.
  /// Palauttaa Future<bool>, joka kertoo, onnistuiko alustus.
  Future<bool> initSpeech() async {
    // Tarkistetaan nykyinen mikrofonin käyttöoikeuden tila.
    var status = await Permission.microphone.status;
    // Jos oikeutta ei ole myönnetty (isDenied), pyydetään sitä käyttäjältä.
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    // Jos oikeutta ei vieläkään myönnetty (esim. käyttäjä kielsi),
    // tulostetaan virheilmoitus ja palautetaan false.
    if (!status.isGranted) {
      debugPrint('Mikrofonin käyttöoikeus evätty. Puheentunnistus ei käytössä.');
      _speechEnabled = false; // Merkitään, ettei STT ole käytettävissä.
      return false;
    }

    // Yritetään alustaa SpeechToText-kirjasto.
    // Annetaan callback-funktiot tilanmuutoksille (onStatus) ja virheille (onError).
    _speechEnabled = await _speechToText.initialize(
      onStatus: _onSpeechStatus, // Kutsutaan, kun kuuntelun tila muuttuu.
      onError: _onSpeechError,   // Kutsutaan, jos alustuksessa tai kuuntelussa tapahtuu virhe.
    );
    // Jos alustus epäonnistui, tulostetaan virheilmoitus.
    if (!_speechEnabled) debugPrint('Speech-to-Text alustus epäonnistui.');
    return _speechEnabled; // Palautetaan tieto alustuksen onnistumisesta.
  }

  // Callback-metodi, jota SpeechToText kutsuu, kun sen tila muuttuu.
  void _onSpeechStatus(String status) {
    debugPrint('Puheentunnistuksen tila: $status');
    // Päivitetään _isListening-lippu vastaamaan kirjaston todellista kuuntelutilaa.
    _isListening = _speechToText.isListening;
  }

  // Callback-metodi, jota SpeechToText kutsuu virhetilanteessa.
  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('Puheentunnistusvirhe: ${error.errorMsg}');
    // Virhetilanteessa oletetaan, ettei kuuntelu ole enää aktiivista.
    _isListening = false;
  }

  /// Käynnistää puheen kuuntelun.
  /// [onResult]: Callback-funktio, jota kutsutaan, kun lopullinen tunnistustulos on saatavilla.
  ///             Se saa parametrinaan tunnistetut sanat merkkijonona.
  /// [listenFor]: Kesto, kuinka kauan kuunnellaan puhetta. Oletus 5 sekuntia.
  /// [localeId]: Kieli/maa-asetus tunnistukselle (esim. 'fi_FI' suomelle). Oletus 'fi_FI'.
  Future<void> startListening({
    required void Function(String recognized) onResult,
    Duration listenFor = const Duration(seconds: 5),
    String localeId = 'fi_FI',
  }) async {
    // Ei aloiteta kuuntelua, jos STT ei ole alustettu tai jos se jo kuuntelee.
    if (!_speechEnabled || _isListening) return;

    // Aloitetaan kuuntelu SpeechToText-kirjaston avulla.
    await _speechToText.listen(
      // Kutsutaan tätä funktiota, kun tunnistustuloksia saadaan (myös väliaikaisia).
      onResult: (SpeechRecognitionResult result) {
        // Välitetään tunnistettu teksti eteenpäin onResult-callbackiin vain,
        // jos kyseessä on lopullinen (final) tunnistustulos.
        if (result.finalResult) onResult(result.recognizedWords);
      },
      listenFor: listenFor, // Kuuntelun kesto.
      localeId: localeId,   // Käytettävä kieli.
    );
    // Päivitetään _isListening-lippu vastaamaan kirjaston tilaa kuuntelun aloittamisen jälkeen.
    _isListening = _speechToText.isListening;
  }

  /// Lopettaa aktiivisen puheen kuuntelun.
  void stopListening() {
    _speechToText.stop(); // Kutsutaan kirjaston stop-metodia.
    _isListening = false; // Merkitään, ettei kuuntelu ole enää käynnissä.
  }

  /// Puheen synteesi: lukee annetun [text]-merkkijonon ääneen.
  /// Parametrit puheen ominaisuuksien säätämiseen:
  /// [rate]: Puhenopeus (esim. 0.5 on hitaampi, 1.0 normaali). Oletus 0.5.
  /// [pitch]: Äänenkorkeus (esim. 1.0 normaali). Oletus 1.0.
  /// [volume]: Äänenvoimakkuus (0.0 - 1.0). Oletus 1.0.
  /// [language]: Käytettävä kieli (esim. 'fi-FI'). Oletus 'fi-FI'.
  Future<void> speak(
      String text, {
        double rate = 0.5,
        double pitch = 1.0,
        double volume = 1.0,
        String language = 'fi-FI',
      }) async {
    // Asetetaan halutut puheparametrit FlutterTts-kirjastolle.
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    // Pyydetään kirjastoa lukemaan annettu teksti.
    await _tts.speak(text);
  }

  /// Vapauttaa STT- ja TTS-kirjastojen käyttämät resurssit.
  /// Tätä metodia tulisi kutsua, kun Puhepalvelua ei enää tarvita,
  /// esimerkiksi widgetin `dispose`-metodissa, jotta vältetään muistivuodot
  /// ja varmistetaan, että natiivit resurssit vapautetaan oikein.
  void dispose() {
    // Pysäytetään mahdollisesti käynnissä oleva puheentunnistus.
    _speechToText.stop();
    // Peruutetaan mahdolliset aktiiviset tai odottavat toiminnot SpeechToText-kirjastossa.
    // Tämä on tärkeää erityisesti, jos alustus on kesken tai jokin muu operaatio odottaa.
    _speechToText.cancel();
    // Pysäytetään mahdollisesti käynnissä oleva puhesynteesi.
    _tts.stop();
  }
}