import 'package:flutter/material.dart'; // Flutterin peruswidgetit ja tyylit
import 'package:provider/provider.dart'; // Provider-kirjasto tilanhallintaan
import 'package:audioplayers/audioplayers.dart'; // Audioplayer äänen toistamiseen
import 'nakymat/aloitus_nakyma.dart'; // Aloitusnäkymä
import 'tarjoajat/trivia_tarjoaja.dart'; // Trivia-pelin logiikan tila
import 'tarjoajat/asetukset_tarjoaja.dart'; // Asetusten tilanhallinta

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
class TriviaVisaSovellus extends StatelessWidget {
  const TriviaVisaSovellus({super.key});

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