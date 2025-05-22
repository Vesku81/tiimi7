import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../tarjoajat/trivia_tarjoaja.dart'; // Tarjoaja kysymysten ja pelilogiikan hallintaan
import '../tarjoajat/asetukset_tarjoaja.dart'; // Tarjoaja sovelluksen asetusten hallintaan
import '../palvelut/puhepalvelu.dart'; // Palvelu puheentunnistukselle (STT) ja puhesynteesille (TTS)
import 'tulokset_nakyma.dart'; // Näkymä pelin tulosten näyttämiseen

// PeliNakyma on StatefulWidget, koska sen sisältö (esim. aika, kysymykset) muuttuu pelin aikana.
class PeliNakyma extends StatefulWidget {
  final String kayttajaNimi; // Pelaajan nimi, joka välitetään tälle näkymälle

  // Konstruktori, joka vaatii käyttäjänimen.
  const PeliNakyma({super.key, required this.kayttajaNimi});

  @override
  State<PeliNakyma> createState() => PeliNakymaTila();
}

// PeliNakymaTila sisältää PeliNakyma-widgetin tilan ja logiikan.
class PeliNakymaTila extends State<PeliNakyma> {
  // Äänentoistoon käytettävä AudioPlayer-instanssi.
  late AudioPlayer _audioPlayer;
  // Puhepalvelun instanssi (STT/TTS).
  late final Puhepalvelu _puhe;
  // Ajastin kysymyksen aikarajalle.
  Timer? _timer;
  // Jäljellä oleva aika nykyiselle kysymykselle sekunteina.
  int _aikaJaljella = 20;
  // Lippu, joka kertoo, onko nykyiseen kysymykseen jo vastattu.
  bool kysymykseenVastattu = false;
  // Lippu, joka kertoo, onko puheentunnistus aktiivinen.
  bool _isListening = false;
  // Ajastin puheentunnistuksen käynnistämisen viiveelle.
  Timer? _listeningStartTimer;
  // Ajastin mikrofonin UI:n näyttämiselle.
  Timer? _microphoneTimer;
  // Jäljellä oleva aika mikrofonin UI:n näytölle.
  int _microphoneTimeLeft = 5;
  // Lippu, joka kertoo, näytetäänkö mikrofonin UI.
  bool _showMicrophoneUI = false;
  // Lista, joka sisältää nykyisen kysymyksen vastausvaihtoehdot sekoitetussa järjestyksessä.
  List<String> _vastaukset = [];

  @override
  void initState() {
    super.initState();
    // Alustetaan AudioPlayer.
    _audioPlayer = AudioPlayer();

    // Suoritetaan koodi vasta, kun ensimmäinen frame on piirretty.
    // Tämä on tärkeää, jotta context on varmasti saatavilla Provider-kutsuja varten.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Haetaan AsetuksetTarjoaja Providerin avulla. listen: false, koska emme tarvitse
      // tämän widgetin uudelleenrakentamista asetusten muuttuessa tässä kohtaa.
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);

      // Soitetaan taustamusiikki, jos se on asetuksissa päällä.
      if (asetukset.aanetKaytossa) {
        _soitaTaustamusiikki(asetukset.aanenVoimakkuus);
      }

      // Alustetaan Puhepalvelu.
      _puhe = Provider.of<Puhepalvelu>(context, listen: false);
      _puhe.initSpeech().then((available) {
        if (!available) debugPrint('Speech-to-Text ei ole saatavilla');
      });

      // Haetaan kysymykset käyttäjän valitsemalla vaikeustasolla.
      // Luetaan käyttäjän valitsema vaikeustaso asetuksista (esim. "Helppo").
      // Jos arvoa ei ole (esim. ensimmäinen käynnistys), käytetään oletuksena 'Helppo'.
      final String valittu = asetukset.valittuVaikeustaso ?? 'Helppo';
      String apiTaso; // Muuttuja API:lle sopivalle vaikeustasolle (esim. "easy").
      // Muunnetaan käyttäjälle näytettävä vaikeustaso API:n ymmärtämään muotoon.
      switch (valittu) {
        case 'Keskitaso':
          apiTaso = 'medium';
          break;
        case 'Vaikea':
          apiTaso = 'hard';
          break;
        case 'Helppo':
        default:
          apiTaso = 'easy';
      }

      // Haetaan kysymykset TriviaTarjoajalta käyttäen valittua API-tasoa.
      // Tässä oletetaan, että halutaan 5 kysymystä.
      Provider.of<TriviaTarjoaja>(context, listen: false)
          .haeKysymykset(5, apiTaso, context)
          .then((_) async {
        // Kun kysymykset on haettu:
        await _paivitaVastaukset(); // Päivitetään vastausvaihtoehdot näytölle.
        _aloitaAikalaskuri();    // Käynnistetään aikalaskuri ensimmäiselle kysymykselle.
      });
    });
  }

  // Metodi taustamusiikin soittamiseen.
  Future<void> _soitaTaustamusiikki(int voimakkuus) async {
    await _audioPlayer.setVolume(voimakkuus / 100); // Asetetaan äänenvoimakkuus (0.0 - 1.0).
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Asetetaan musiikki looppaamaan.
    await _audioPlayer.play(AssetSource('sounds/background_music.mp3')); // Soitetaan musiikkitiedosto.
  }

  // Metodi vastausvaihtoehtojen päivittämiseen ja kysymyksen lukemiseen ääneen.
  Future<void> _paivitaVastaukset() async {
    final triviaTarjoaja = Provider.of<TriviaTarjoaja>(context, listen: false);
    // Varmistetaan, että kysymyksiä on ja nykyinen indeksi on validi.
    if (triviaTarjoaja.kysymykset.isNotEmpty &&
        triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length) {
      final kysymys = triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];
      // Luodaan lista vääristä vastauksista, lisätään oikea vastaus ja sekoitetaan lista.
      final sekoitetut = List<String>.from(kysymys.vaaratVastaukset)
        ..add(kysymys.oikeaVastaus)
        ..shuffle();
      // Päivitetään tila, jotta UI päivittyy uusilla vastausvaihtoehdoilla.
      setState(() => _vastaukset = sekoitetut);

      // Luetaan kysymys ääneen, jos TTS (Text-to-Speech) on asetuksissa päällä.
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      if (asetukset.kaytaTts) {
        await _puhe.speak(
          kysymys.kysymysTeksti,
          rate: asetukset.ttsRate,     // Puhenopeus asetuksista.
          pitch: asetukset.ttsPitch,   // Äänenkorkeus asetuksista.
          volume: asetukset.aanenVoimakkuus / 100, // Äänenvoimakkuus asetuksista.
        );
      }
    }
  }

  // Metodi aikalaskurin käynnistämiseen uudelle kysymykselle.
  void _aloitaAikalaskuri() {
    _timer?.cancel(); // Peruutetaan edellinen ajastin, jos sellainen on aktiivinen.
    _aikaJaljella = 20; // Asetetaan aika takaisin 20 sekuntiin.
    kysymykseenVastattu = false; // Merkitään, että uuteen kysymykseen ei ole vielä vastattu.
    _stopListening(); // Pysäytetään mahdollinen aiempi puheentunnistus.
    _hideMicrophoneUI(); // Piilotetaan mikrofonin UI.

    // Luodaan uusi periodinen ajastin, joka suoritetaan joka sekunti.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Päivitetään tila, jotta UI näyttää muuttuvan ajan.
      setState(() {
        if (_aikaJaljella > 0) {
          _aikaJaljella--; // Vähennetään jäljellä olevaa aikaa.
          // Kun aikaa on jäljellä 10 sekuntia, yritetään käynnistää puheentunnistus viiveellä.
          if (_aikaJaljella == 10) _startListeningWithDelay();
        } else {
          // Jos aika loppuu:
          timer.cancel(); // Pysäytetään ajastin.
          _lukitseKysymys(); // Lukitaan kysymys (merkitään väärin vastatuksi, jos ei vielä vastattu).
        }
      });
    });
  }

  // Metodi puheentunnistuksen käynnistämiseen pienen viiveen jälkeen.
  // Viive on tässä 0 sekuntia, eli käynnistyy heti, jos ehdot täyttyvät.
  void _startListeningWithDelay() {
    final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
    // Tarkistetaan, onko STT (Speech-to-Text) käytössä asetuksissa,
    // ei ole vielä vastattu, ei kuunnella jo, ja onko puhepalvelu alustettu.
    if (asetukset.kaytaSpeechToText &&
        !kysymykseenVastattu &&
        !_isListening &&
        _puhe.isInitialized) {
      _listeningStartTimer?.cancel(); // Peruutetaan aiempi kuuntelun aloitusajastin.
      // Ajastetaan kuuntelun aloitus (tässä tapauksessa välittömästi).
      _listeningStartTimer = Timer(const Duration(seconds: 0), () {
        _startListening(); // Käynnistetään varsinainen kuuntelu.
        _showMicrophoneUIWithTimer(); // Näytetään mikrofonin UI ajastimen kanssa.
      });
    }
  }

  // Metodi kysymyksen lukitsemiseen, jos aika loppuu tai pelaaja ei vastaa.
  void _lukitseKysymys() {
    if (!kysymykseenVastattu) { // Suoritetaan vain, jos kysymykseen ei ole vielä vastattu.
      // Merkitään kysymys väärin vastatuksi TriviaTarjoajassa.
      Provider.of<TriviaTarjoaja>(context, listen: false)
          .vastaaKysymykseen(false);
      naytaPisteetSnackBar(context, false); // Näytetään SnackBar miinuspisteistä.
      setState(() => kysymykseenVastattu = true); // Merkitään kysymykseen vastatuksi.
      _stopListening(); // Pysäytetään puheentunnistus.
      _hideMicrophoneUI(); // Piilotetaan mikrofonin UI.
    }
  }

  // Metodi puheentunnistuksen tilan vaihtamiseen (päälle/pois) mikrofoninappia painettaessa.
  void _toggleListening() {
    if (_isListening) {
      _stopListening(); // Jos kuunnellaan, lopetetaan kuuntelu.
      _hideMicrophoneUI(); // Piilotetaan mikrofonin UI.
    } else {
      _startListening(); // Jos ei kuunnella, aloitetaan kuuntelu.
      _showMicrophoneUIWithTimer(); // Näytetään mikrofonin UI ajastimen kanssa.
    }
  }

  // Metodi puheentunnistuksen aloittamiseen.
  void _startListening() async {
    final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
    // Tarkistetaan, onko STT käytössä, ei ole vastattu, eikä jo kuunnella.
    if (asetukset.kaytaSpeechToText &&
        !kysymykseenVastattu &&
        !_isListening) {
      if (_puhe.isInitialized) { // Varmistetaan, että puhepalvelu on alustettu.
        // Aloitetaan kuuntelu ja asetetaan callback-funktio tuloksille.
        _puhe.startListening(onResult: _onSpeechResult);
        setState(() => _isListening = true); // Päivitetään tila kuuntelun alkaneeksi.
      } else {
        debugPrint("Puhepalvelu ei ole alustettu.");
      }
    }
  }

  // Metodi puheentunnistuksen pysäyttämiseen.
  void _stopListening() {
    _puhe.stopListening(); // Pysäytetään puhepalvelun kuuntelu.
    _listeningStartTimer?.cancel(); // Peruutetaan mahdollinen kuuntelun aloitusajastin.
    _microphoneTimer?.cancel(); // Peruutetaan mikrofonin UI-ajastin.
    // Päivitetään tila, että kuuntelu on loppunut ja UI piilotetaan.
    setState(() {
      _isListening = false;
      _showMicrophoneUI = false;
    });
  }

  // Metodi mikrofonin käyttöliittymän näyttämiseen ajastimen kanssa.
  void _showMicrophoneUIWithTimer() {
    _microphoneTimer?.cancel(); // Peruutetaan aiempi mikrofonin UI-ajastin.
    _microphoneTimeLeft = 5; // Asetetaan mikrofonin UI:n näyttöaika.
    setState(() => _showMicrophoneUI = true); // Näytetään mikrofonin UI.

    // Ajastin, joka päivittää jäljellä olevaa aikaa mikrofonin UI:ssa.
    _microphoneTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_microphoneTimeLeft > 0) {
          _microphoneTimeLeft--; // Vähennetään aikaa.
        } else {
          timer.cancel(); // Aika loppui, peruutetaan ajastin.
          _hideMicrophoneUI(); // Piilotetaan mikrofonin UI.
        }
      });
    });
  }

  // Metodi mikrofonin käyttöliittymän piilottamiseen.
  void _hideMicrophoneUI() {
    _microphoneTimer?.cancel(); // Peruutetaan mikrofonin UI-ajastin.
    // Päivitetään tila piilottamaan UI ja nollaamaan sen aika.
    setState(() {
      _showMicrophoneUI = false;
      _microphoneTimeLeft = 5;
    });
  }

  // Callback-metodi, joka suoritetaan, kun puheentunnistus tuottaa tuloksen.
  void _onSpeechResult(String recognized) {
    final input = recognized.toLowerCase().trim(); // Muunnetaan tunnistettu teksti pieniksi kirjaimiksi ja poistetaan ylimääräiset välilyönnit.
    final trivia = Provider.of<TriviaTarjoaja>(context, listen: false);
    // Varmistetaan, ettei indeksi ylitä kysymysten määrää (turvatoimi).
    if (trivia.nykyinenIndeksi >= trivia.kysymykset.length) return;
    final kys = trivia.kysymykset[trivia.nykyinenIndeksi];
    final oikea = kys.oikeaVastaus.toLowerCase(); // Nykyisen kysymyksen oikea vastaus pieniksi kirjaimiksi.

    bool oikein = input == oikea; // Tarkistetaan, onko tunnistettu vastaus suoraan oikea.
    // Jos ei ollut suora osuma, tarkistetaan, vastaako tunnistettu teksti jotain
    // sekoitetuista vastausvaihtoehdoista (ja onko se nimenomaan oikea vastaus).
    if (!oikein) {
      // Käydään läpi näytöllä olevat vastausvaihtoehdot.
      for (var v in _vastaukset) {
        // Jos tunnistettu syöte vastaa jotain vastausvaihtoehtoa (pienillä kirjaimilla vertailu).
        if (input == v.toLowerCase()) {
          // Tarkistetaan, oliko tämä vastausvaihtoehto se oikea vastaus.
          oikein = v == kys.oikeaVastaus;
          break; // Lopetetaan silmukka, kun vastaavuus löytyi.
        }
      }
    }

    // Käsitellään vastaus vain, jos kysymykseen ei ole vielä vastattu.
    if (!kysymykseenVastattu) {
      trivia.vastaaKysymykseen(oikein); // Ilmoitetaan TriviaTarjoajalle, oliko vastaus oikein.
      naytaPisteetSnackBar(context, oikein); // Näytetään SnackBar pisteistä.
      // Päivitetään tila: kysymykseen on vastattu ja kuuntelu lopetetaan.
      setState(() {
        kysymykseenVastattu = true;
        _isListening = false;
      });
      _timer?.cancel(); // Pysäytetään aikalaskuri.
      _stopListening(); // Pysäytetään puheentunnistus.
      _hideMicrophoneUI(); // Piilotetaan mikrofonin UI.
    }
  }

  // Metodi SnackBarin näyttämiseen, joka kertoo saadut/menetetyt pisteet.
  void naytaPisteetSnackBar(BuildContext context, bool oikein) {
    final snackBar = SnackBar(
      content: Text(
        oikein ? '+20 pistettä!' : '-5 pistettä!', // Teksti riippuen siitä, oliko vastaus oikein.
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      backgroundColor: oikein ? Colors.green : Colors.red, // Väri riippuen siitä, oliko vastaus oikein.
      duration: const Duration(seconds: 1), // SnackBarin näkyvyysaika.
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar); // Näytetään SnackBar.
  }

  // Metodi siirtymiseen TuloksetNakymaan pelin päätyttyä.
  void siirryTuloksetNakymaan(TriviaTarjoaja triviaTarjoaja) {
    _timer?.cancel(); // Pysäytetään aikalaskuri.
    _stopListening(); // Pysäytetään puheentunnistus.
    _hideMicrophoneUI(); // Piilotetaan mikrofonin UI.
    // Korvataan nykyinen näkymä TuloksetNakyma-widgetillä.
    // Tämä estää käyttäjää palaamasta takaisin pelinäkymään.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TuloksetNakyma(
          kayttajaNimi: widget.kayttajaNimi, // Välitetään käyttäjänimi.
          pisteet: triviaTarjoaja.pisteet,   // Välitetään saadut pisteet.
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Vapautetaan resurssit, kun widget poistetaan puusta.
    _audioPlayer.dispose(); // Vapautetaan AudioPlayer.
    _timer?.cancel(); // Peruutetaan aikalaskuri.
    _puhe.dispose(); // Vapautetaan Puhepalvelu.
    _listeningStartTimer?.cancel(); // Peruutetaan kuuntelun aloitusajastin.
    _microphoneTimer?.cancel(); // Peruutetaan mikrofonin UI-ajastin.
    super.dispose(); // Kutsutaan yliluokan dispose-metodia.
  }

  @override
  Widget build(BuildContext context) {
    // Rakennetaan pelinäkymän käyttöliittymä.
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Keskitetään otsikko.
        title: const Text('Tietovisa'), // AppBarin otsikko.
        backgroundColor: Colors.grey[800], // AppBarin taustaväri.
        foregroundColor: Colors.white,   // AppBarin tekstien ja ikonien oletusväri.
        titleTextStyle: const TextStyle( // AppBarin otsikon tyyli.
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        actions: [
          // Näytetään mikrofoninappi vain, jos STT on käytössä asetuksissa.
          Consumer<AsetuksetTarjoaja>(
            builder: (_, aset, __) {
              if (!aset.kaytaSpeechToText) return const SizedBox(); // Jos STT ei ole käytössä, palautetaan tyhjä widget.
              // Palautetaan IconButton mikrofonin tilan vaihtamiseen.
              return IconButton(
                icon:
                Icon(_isListening ? Icons.mic_off : Icons.mic_none), // Ikoni muuttuu kuuntelun tilan mukaan.
                onPressed: _toggleListening, // Kutsutaan _toggleListening-metodia painettaessa.
              );
            },
          ),
        ],
      ),
      body: Stack( // Käytetään Stack-widgetiä elementtien pinoamiseen päällekkäin (esim. taustakuva ja sisältö).
        children: [
          // Taustakuva.
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/peli_background.jpg'), // Taustakuvan polku.
                fit: BoxFit.cover, // Skaalataan kuva täyttämään koko alue.
              ),
            ),
          ),
          // Trivia-sisältö, joka päivittyy TriviaTarjoajan tilan mukaan.
          Consumer<TriviaTarjoaja>(
            builder: (context, triviaTarjoaja, child) {
              // Näytetään latausindikaattori, jos kysymyksiä ladataan.
              if (triviaTarjoaja.onLataus) {
                return const Center(child: CircularProgressIndicator());
              }
              // Näytetään virheilmoitus, jos kysymysten haussa tapahtui virhe.
              if (triviaTarjoaja.virhe != null) {
                return Center(
                  child: Text(
                    triviaTarjoaja.virhe!,
                    style: const TextStyle(
                        fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              // Näytetään ilmoitus, jos kysymyksiä ei löytynyt.
              if (triviaTarjoaja.kysymykset.isEmpty) {
                return const Center(
                    child: Text("Kysymyksiä ei löytynyt."));
              }
              // Jos kaikki kysymykset on käyty läpi, siirrytään tulosnäkymään.
              // addPostFrameCallback varmistaa, että siirtymä tapahtuu vasta build-vaiheen jälkeen.
              if (triviaTarjoaja.nykyinenIndeksi >=
                  triviaTarjoaja.kysymykset.length) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) {
                  siirryTuloksetNakymaan(triviaTarjoaja);
                });
                return const SizedBox(); // Palautetaan tyhjä widget odotellessa siirtymää.
              }

              // Haetaan nykyinen kysymys TriviaTarjoajalta.
              final kysymys = triviaTarjoaja
                  .kysymykset[triviaTarjoaja.nykyinenIndeksi];

              // Palautetaan Column-widget, joka sisältää pelin elementit.
              return Column(
                children: [
                  const SizedBox(height: 50), // Tyhjää tilaa yläreunaan.

                  // Tervetuloteksti pelaajalle.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Tervetuloa, ${widget.kayttajaNimi}!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Näytetään nykyisen kysymyksen numero
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Kysymys ${triviaTarjoaja.nykyinenIndeksi + 1}/${triviaTarjoaja.kysymykset.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Näytetään jäljellä oleva aika.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Aikaa jäljellä: $_aikaJaljella sekuntia',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow, // Korostetaan aikaa keltaisella.
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20), // Tyhjää tilaa ennen kysymystekstiä.
                  Expanded( // Käytetään Expanded-widgetiä, jotta kysymys ja vastaukset täyttävät jäljellä olevan tilan.
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // Pehmustetta reunoille.
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center, // Keskitetään sisältö pystysuunnassa.
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch, // Venytetään lapset leveyssuunnassa.
                        children: [
                          // Nykyisen kysymyksen teksti.
                          Text(
                            kysymys.kysymysTeksti,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20), // Tyhjää tilaa vastausvaihtoehtojen yläpuolella.
                          // Luodaan lista vastausvaihtoehtopainikkeista.
                          // Käytetään spread-operaattoria (...) listan elementtien lisäämiseksi suoraan children-listaan.
                          ..._vastaukset.map((vastaus) {
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8.0), // Pystysuuntainen marginaali painikkeiden välillä.
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[800],   // Painikkeen taustaväri.
                                  foregroundColor: Colors.white, // Painikkeen tekstin väri.
                                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Tekstin tyyli.
                                ),
                                // onPressed on null, jos kysymykseen on jo vastattu, jolloin painike on pois käytöstä.
                                onPressed: kysymykseenVastattu
                                    ? null
                                    : () {
                                  // Tarkistetaan, onko valittu vastaus oikea.
                                  final oikein = vastaus ==
                                      kysymys.oikeaVastaus;
                                  naytaPisteetSnackBar(
                                      context, oikein); // Näytetään SnackBar pisteistä.
                                  // Ilmoitetaan TriviaTarjoajalle vastauksesta.
                                  triviaTarjoaja
                                      .vastaaKysymykseen(oikein);
                                  // Päivitetään tila: kysymykseen on vastattu.
                                  setState(() {
                                    kysymykseenVastattu =
                                    true;
                                  });
                                  _timer?.cancel(); // Pysäytetään aikalaskuri.
                                  _stopListening(); // Pysäytetään puheentunnistus.
                                  _hideMicrophoneUI(); // Piilotetaan mikrofonin UI.
                                },
                                child: Text(vastaus), // Painikkeen teksti (vastausvaihtoehto).
                              ),
                            );
                          }),
                          // Seuraava kysymys -painike.
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],   // Painikkeen taustaväri.
                              foregroundColor: Colors.white, // Painikkeen tekstin väri.
                              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Tekstin tyyli.
                            ),
                            // onPressed on null, jos kysymykseen ei ole vielä vastattu.
                            onPressed: kysymykseenVastattu
                                ? () {
                              // Nollataan vastaustila seuraavaa kysymystä varten.
                              setState(() {
                                kysymykseenVastattu =
                                false;
                              });
                              // Tarkistetaan, onko vielä kysymyksiä jäljellä.
                              if (triviaTarjoaja
                                  .nykyinenIndeksi <
                                  triviaTarjoaja.kysymykset
                                      .length -
                                      1) {
                                // Siirrytään seuraavaan kysymykseen.
                                triviaTarjoaja
                                    .seuraavaKysymys();
                                _paivitaVastaukset(); // Päivitetään vastausvaihtoehdot.
                                _aloitaAikalaskuri(); // Käynnistetään aikalaskuri uudelleen.
                              } else {
                                // Jos kysymykset loppuivat, siirrytään tulosnäkymään.
                                // Käytetään pushReplacement, jotta käyttäjä ei voi palata takaisin pelinäkymään.
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TuloksetNakyma(
                                          kayttajaNimi:
                                          widget.kayttajaNimi,
                                          pisteet:
                                          triviaTarjoaja
                                              .pisteet,
                                        ),
                                  ),
                                );
                              }
                            }
                                : null, // Painike pois käytöstä, jos ei ole vastattu.
                            child:
                            const Text('Seuraava kysymys'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Mikrofonin käyttöliittymäelementti, näytetään ehdollisesti.
          if (_showMicrophoneUI)
            Positioned( // Asetellaan UI näytön alareunaan keskelle.
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12.0), // Pehmustetta sisällölle.
                  decoration: BoxDecoration(
                    color: Colors.black54, // Puoliläpinäkyvä musta tausta.
                    borderRadius:
                    BorderRadius.circular(20.0), // Pyöristetyt kulmat.
                  ),
                  child: Row( // Asetellaan ikoni ja aika vierekkäin.
                    mainAxisSize: MainAxisSize.min, // Vie vain tarvittavan tilan.
                    children: [
                      Icon(
                        _isListening
                            ? Icons.mic_off // Ikoni, kun kuuntelu on päällä (näyttää "sammuta mikrofoni").
                            : Icons.mic_none, // Ikoni, kun kuuntelu ei ole päällä.
                        color: _isListening
                            ? Colors.redAccent // Punainen väri, kun kuunnellaan.
                            : Colors.white, // Valkoinen väri muuten.
                        size: 30, // Ikonin koko.
                      ),
                      const SizedBox(width: 10), // Väliä ikonin ja tekstin välille.
                      Text(
                        '$_microphoneTimeLeft s', // Näytetään jäljellä oleva aika mikrofonin UI:lle.
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}