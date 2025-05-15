import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import 'package:provider/provider.dart'; // Provider-kirjasto tilanhallintaan
import 'package:audioplayers/audioplayers.dart'; // Audioplayer äänen toistamiseen
import 'package:google_mlkit_translation/google_mlkit_translation.dart'; // ML Kit -kääntäjä

import 'nakymat/aloitus_nakyma.dart'; // Aloitusnäkymä
import 'tarjoajat/trivia_tarjoaja.dart'; // Trivia-pelin logiikan tila
import 'tarjoajat/asetukset_tarjoaja.dart'; // Asetusten tilanhallinta
import 'palvelut/puhepalvelu.dart'; // Puhepalvelu (STT & TTS)

void main() async {
  // Tarvitaan ennen asynkronisia operaatioita, kuten audioplayerin alustamista
  WidgetsFlutterBinding.ensureInitialized();

  // Soitetaan sovelluksen käynnistysääni ennen varsinaisen sovelluksen käynnistymistä
  await soitaKaynnistysaani();

  runApp(
    MultiProvider(
      providers: [
        // Trivia-pelin tilan tarjoaja, joka on käytössä koko sovelluksessa
        ChangeNotifierProvider(create: (_) => TriviaTarjoaja()),
        // Asetusten tilan tarjoaja, joka on käytössä koko sovelluksessa
        ChangeNotifierProvider(create: (_) => AsetuksetTarjoaja()),
        // Puhepalvelu tarjoaa STT- ja TTS-toiminnot
        Provider(create: (_) => Puhepalvelu()),
      ],
      child: const TriviaVisaSovellus(), // Sovelluksen pääkomponentti
    ),
  );
}

// Funktio, jolla soitetaan sovelluksen käynnistysääni
Future<void> soitaKaynnistysaani() async {
  final audioPlayer = AudioPlayer(); // Luodaan audioplayer-objekti äänen toistamiseen
  await audioPlayer.play(AssetSource('sounds/application_start.mp3')); // Soitetaan käynnistysääni
  await Future.delayed(const Duration(seconds: 2)); // Odotetaan äänen loppuminen
}

// TriviaVisaSovellus vastaa koko sovelluksen rakenteesta ja ulkoasusta
class TriviaVisaSovellus extends StatefulWidget {
  const TriviaVisaSovellus({super.key});

  @override
  State<TriviaVisaSovellus> createState() => _TriviaVisaSovellusState();
}

class _TriviaVisaSovellusState extends State<TriviaVisaSovellus> {
  late final Puhepalvelu _puhepalvelu; // Puhepalvelun instanssi
  late final OnDeviceTranslator _translator; // ML Kit -kääntäjä
  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();

  @override
  void initState() {
    super.initState();
    // ML Kit Translator: luodaan kääntäjä
    _translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: TranslateLanguage.finnish,
    );
    // Mallien lataus
    _modelManager.downloadModel(TranslateLanguage.english.bcpCode);
    _modelManager.downloadModel(TranslateLanguage.finnish.bcpCode);

    // Haetaan Puhepalvelu Providerista ja alustetaan puheentunnistus
    _puhepalvelu = Provider.of<Puhepalvelu>(context, listen: false);
    _puhepalvelu.initSpeech().then((available) {
      if (!available) {
        debugPrint('Speech-to-Text ei ole saatavilla');
      }
    });
  }

  @override
  void dispose() {
    _translator.close(); // Suljetaan ML Kit -kääntäjä resurssien vapauttamiseksi
    _puhepalvelu.dispose(); // Vapautetaan puhepalvelun resurssit
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Poistetaan banneri oikeasta yläkulmasta
      title: 'TriviaVisa', // Sovelluksen otsikko
      theme: ThemeData(
        primarySwatch: Colors.blue, // Teeman pääväri
      ),
      home: const AloitusNakyma(), // Pelin aloitusnäkymä
    );
  }
}
