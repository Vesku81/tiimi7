// Sovelluksen käynnistys ja providerien asetus
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Sovelluksenäkymät ja tarjoajat
import 'nakymat/aloitus_nakyma.dart';
import 'tarjoajat/trivia_tarjoaja.dart';
import 'tarjoajat/asetukset_tarjoaja.dart';
import 'palvelut/puhepalvelu.dart';

/// Pääfunktio, jossa alustetaan Flutter-sitoutuminen ja käynnistetään sovellus
void main() async {
  // Varmistetaan, että Flutterin widget-järjestelmä on alustettu
  WidgetsFlutterBinding.ensureInitialized();

  // Luodaan ja ladataan käyttäjän asetukset
  final asetukset = AsetuksetTarjoaja();
  // Lyhyt viive, jotta asetukset ehtivät latautua
  await Future.delayed(const Duration(milliseconds: 200));
  
  // Sovelluksen käynnistys, jossa alustetaan providerit ja siirrytään TriviaVisaSovellus-widgettiin
  runApp(
    MultiProvider(
      providers: [
        // AsetuksetTarjoaja tarjoaa sovelluksen äänija ja vaikeustasoasetukset
        ChangeNotifierProvider(create: (_) => asetukset),
        // Puhepalvelu hoitaa TTS ja STT -toiminnot
        Provider<Puhepalvelu>(
          create: (_) => Puhepalvelu(),
          dispose: (_, palvelu) => palvelu.dispose(),
        ),
        // TriviaTarjoaja hakee ja hallinnoi kysymyksiä ja pisteitä
        ChangeNotifierProvider(create: (_) => TriviaTarjoaja()),
      ],
      child: const TriviaVisaSovellus(),
    ),
  );
}

/// Päärakenteinen widget sovellukselle
class TriviaVisaSovellus extends StatefulWidget {
  const TriviaVisaSovellus({super.key});

  @override
  State<TriviaVisaSovellus> createState() => _TriviaVisaSovellusState();
}

class _TriviaVisaSovellusState extends State<TriviaVisaSovellus> {
  @override
  void initState() {
    super.initState();
    // Käynnistetään puheentunnistus ( STT = Speech-to-text ) ensimmäisen kehyksen renderöinnin jälkeen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Haetaan providerista puhepalvelu-instanssi
        final puhepalvelu = Provider.of<Puhepalvelu>(context, listen: false);
        // Alustetaan puheentunnistus ja käsitellään mahdollinen epäonnistuminen
        puhepalvelu.initSpeech().then((available) {
          if (!available && mounted) {
            debugPrint('Speech-to-Text ei ole saatavilla sovelluksen käynnistyessä.');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // MaterialApp asettaa teeman ja siirtyy aloitusnäkymään
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Poistetaan debug-lippu ruudulta
      title: 'Tietovisa', // Sovelluksen nimi
      theme: ThemeData(primarySwatch: Colors.blue), // Teeman värit
      home: const AloitusNakyma(), // Ensisijainen näkymä sovelluksen käynnistyessä
    );
  }
}
