// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

// Kommentoidaan pois, jos ei enää tarvita suoraan tässä tiedostossa
// import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'nakymat/aloitus_nakyma.dart';
import 'tarjoajat/trivia_tarjoaja.dart';
import 'tarjoajat/asetukset_tarjoaja.dart';
import 'palvelut/puhepalvelu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ladataan asetukset ensin, jotta tiedetään, soitetaanko käynnistysääni
  final asetukset = AsetuksetTarjoaja();
  // Varmistetaan, että asetukset ladataan ennen kuin niitä käytetään.
  // AsetuksetTarjoajan konstruktori kutsuu _load(), joka on async.
  // Yksinkertainen odotus tai parempi tapa olisi käyttää FutureBuilderia tai vastaavaa
  // sovelluksen käynnistyksessä, jos käynnistysääni on kriittinen.
  // Tässä oletetaan, että _load() ehtii suorittua tai että oletusarvo on ok.
  // Parempi tapa olisi odottaa _load() valmistumista, jos se on mahdollista.
  // Esimerkiksi:
  // await asetukset._load(); // Jos _load() olisi julkinen tai kutsuttaisiin toisin.
  // Koska _load() on yksityinen ja kutsutaan konstruktorissa, meidän pitää luottaa,
  // että se ehtii tai käyttää oletusarvoa.
  // Tässä vaiheessa `asetukset.aanetKaytossa` voi palauttaa oletusarvon, jos lataus ei ole valmis.
  // Turvallisempi tapa olisi tehdä AsetuksetTarjoajan alustuksesta Future ja odottaa sitä.

  // Väliaikainen ratkaisu käynnistysäänen soittoon:
  // Odotetaan pieni hetki, jotta asetukset ehtivät mahdollisesti latautua. Ei ideaali.
  await Future.delayed(const Duration(milliseconds: 200));
  if (asetukset.aanetKaytossa) {
    await soitaKaynnistysaani();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => asetukset), // Käytetään jo luotua instanssia

        Provider<Puhepalvelu>(
          create: (_) => Puhepalvelu(),
          dispose: (_, palvelu) => palvelu.dispose(),
        ),

        // TriviaTarjoaja.
        // Jos TriviaTarjoaja tarvitsee AsetuksetTarjoajaa konstruktorissaan,
        // käytä ChangeNotifierProxyProvideria.
        // Tässä oletetaan, että TriviaTarjoaja hakee AsetuksetTarjoajan
        // Provider.of(context)-kutsulla tarvittaessa metodeissaan.
        ChangeNotifierProvider(
          create: (context) => TriviaTarjoaja(),
          // EI dispose-parametria ChangeNotifierProviderille tällä tavalla.
          // TriviaTarjoajan oma dispose() -metodi kutsutaan automaattisesti.
        ),
      ],
      child: const TriviaVisaSovellus(),
    ),
  );
}

Future<void> soitaKaynnistysaani() async {
  final audioPlayer = AudioPlayer();
  try {
    await audioPlayer.play(AssetSource('sounds/application_start.mp3'));
    await Future.delayed(const Duration(seconds: 2));
  } catch (e) {
    debugPrint("Virhe käynnistysäänen soitossa: $e");
  } finally {
    await audioPlayer.dispose();
  }
}

class TriviaVisaSovellus extends StatefulWidget {
  const TriviaVisaSovellus({super.key});

  @override
  State<TriviaVisaSovellus> createState() => _TriviaVisaSovellusState();
}

class _TriviaVisaSovellusState extends State<TriviaVisaSovellus> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Alustetaan Puhepalvelu
      // Varmistetaan, että context on saatavilla ja Provider on valmis
      if (mounted) { // Tarkistetaan, että widget on yhä puussa
        final puhepalvelu = Provider.of<Puhepalvelu>(context, listen: false);
        puhepalvelu.initSpeech().then((available) {
          if (!available && mounted) { // Tarkista mounted uudelleen asynkronisen kutsun jälkeen
            debugPrint('Speech-to-Text ei ole saatavilla sovelluksen käynnistyessä.');
            // Voit näyttää käyttäjälle ilmoituksen tässä, jos haluat
          }
        });
      }
      // TriviaTarjoajan kääntäjämallit ladataan sen konstruktorissa.
    });
  }

  // dispose-metodia ei tarvita tässä luokassa enää, koska Providerit hoitavat
  // TriviaTarjoajan ja Puhepalvelun dispose-kutsut.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TriviaVisa',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AloitusNakyma(),
    );
  }
}