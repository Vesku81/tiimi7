import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../tarjoajat/trivia_tarjoaja.dart';
import '../tarjoajat/asetukset_tarjoaja.dart';
import '../palvelut/puhepalvelu.dart';
import 'tulokset_nakyma.dart';

class PeliNakyma extends StatefulWidget {
  final String kayttajaNimi;

  const PeliNakyma({super.key, required this.kayttajaNimi});

  @override
  State<PeliNakyma> createState() => PeliNakymaTila();
}

class PeliNakymaTila extends State<PeliNakyma> {
  late AudioPlayer _audioPlayer;
  late final Puhepalvelu _puhe;
  Timer? _timer;
  int _aikaJaljella = 20;
  bool kysymykseenVastattu = false;
  bool _isListening = false;
  Timer? _listeningStartTimer; // Ajastin puheentunnistuksen käynnistämiselle
  Timer? _microphoneTimer;     // Ajastin mikrofonin kuvakkeen ja ajan näyttämiselle
  int _microphoneTimeLeft = 5; // Mikrofonin ajastimen jäljellä oleva aika
  bool _showMicrophoneUI = false; // Tila mikrofonin käyttöliittymän näyttämiselle


  List<String> _vastaukset = [];

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      if (asetukset.aanetKaytossa) {
        _soitaTaustamusiikki(asetukset.aanenVoimakkuus);
      }

      _puhe = Provider.of<Puhepalvelu>(context, listen: false);
      _puhe.initSpeech().then((available) {
        if (!available) {
          debugPrint('Speech-to-Text ei ole saatavilla');
        }
      });

      Provider.of<TriviaTarjoaja>(context, listen: false)
          .haeKysymykset(5, 'easy', context)
          .then((_) {
        _paivitaVastaukset();
        _aloitaAikalaskuri();
        // Puheentunnistus käynnistetään nyt _aloitaAikalaskuri:n sisällä viiveellä
      });
    });
  }

  Future<void> _soitaTaustamusiikki(int voimakkuus) async {
    await _audioPlayer.setVolume(voimakkuus / 100);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/background_music.mp3'));
  }

  void _paivitaVastaukset() {
    final triviaTarjoaja = Provider.of<TriviaTarjoaja>(context, listen: false);
    if (triviaTarjoaja.kysymykset.isNotEmpty &&
        triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length) {
      final kysymys = triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];
      List<String> sekoitetut = List<String>.from(kysymys.vaaratVastaukset)
        ..add(kysymys.oikeaVastaus)
        ..shuffle();
      setState(() {
        _vastaukset = sekoitetut;
      });
    }
  }

  void _aloitaAikalaskuri() {
    _timer?.cancel();
    _aikaJaljella = 20;
    kysymykseenVastattu = false; // Nollataan vastattu tila uuden kysymyksen alkaessa
    _stopListening(); // Varmistetaan, että edellinen kuuntelu on lopetettu
    _hideMicrophoneUI(); // Piilotetaan mikrofonin käyttöliittymä

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_aikaJaljella > 0) {
          _aikaJaljella--;
          // Käynnistetään puheentunnistus ja mikrofonin ajastin 10 sekunnin kuluttua
          if (_aikaJaljella == 10) { // Kun 10 sekuntia on kulunut (20 - 10 = 10)
            _startListeningWithDelay();
          }
        } else {
          timer.cancel();
          _lukitseKysymys();
        }
      });
    });
  }

  // Käynnistää puheentunnistuksen 5 sekunnin viiveellä
  void _startListeningWithDelay() {
    final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
    if (asetukset.kaytaSpeechToText && !kysymykseenVastattu && !_isListening && _puhe.isInitialized) {
      _listeningStartTimer?.cancel(); // Peruutetaan mahdollinen edellinen ajastin
      _listeningStartTimer = Timer(const Duration(seconds: 0), () { // 0 sekunnin viive, koska käynnistetään kun aikaa on 10s
        _startListening(); // Käynnistetään varsinainen kuuntelu
        _showMicrophoneUIWithTimer(); // Näytetään mikrofonin käyttöliittymä ajastimella
      });
    }
  }


  void _lukitseKysymys() {
    if (!kysymykseenVastattu) {
      Provider.of<TriviaTarjoaja>(context, listen: false).vastaaKysymykseen(false);
      naytaPisteetSnackBar(context, false);
      setState(() {
        kysymykseenVastattu = true;
      });
      _stopListening();
      _hideMicrophoneUI(); // Piilotetaan mikrofonin käyttöliittymä
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
      _hideMicrophoneUI(); // Piilotetaan käyttöliittymä, jos kuuntelu lopetetaan manuaalisesti
    } else {
      // Manuaalinen käynnistys käynnistää heti
      _startListening();
      _showMicrophoneUIWithTimer(); // Näytetään käyttöliittymä manuaalisessa käynnistyksessä
    }
  }

  // Käynnistää puheentunnistuksen (kesto määritelty Puhepalvelu-luokassa)
  void _startListening() async {
    final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
    if (asetukset.kaytaSpeechToText && !kysymykseenVastattu && !_isListening) {
      if (_puhe.isInitialized) {
        // Käytetään Puhepalvelu-luokan listenFor-parametria keston määrittämiseen
        _puhe.startListening(onResult: _onSpeechResult);
        setState(() {
          _isListening = true;
        });
      } else {
        debugPrint("Puhepalvelu ei ole alustettu.");
      }
    } else if (!asetukset.kaytaSpeechToText) {
      debugPrint("Puheentunnistus ei ole käytössä asetuksissa.");
    } else if (kysymykseenVastattu) {
      debugPrint("Kysymykseen on jo vastattu.");
    } else if (_isListening) {
      debugPrint("Puheentunnistus on jo käynnissä.");
    }
  }

  // Lopettaa puheentunnistuksen
  void _stopListening() {
    _puhe.stopListening();
    _listeningStartTimer?.cancel(); // Peruuta käynnistysajastin, jos se on aktiivinen
    _microphoneTimer?.cancel(); // Peruuta mikrofonin ajastin
    setState(() {
      _isListening = false;
      _showMicrophoneUI = false; // Piilotetaan käyttöliittymä kuuntelun lopetuksessa
    });
  }

  // Näyttää mikrofonin käyttöliittymän ja käynnistää ajastimen
  void _showMicrophoneUIWithTimer() {
    _microphoneTimer?.cancel(); // Peruutetaan mahdollinen edellinen ajastin
    _microphoneTimeLeft = 5; // Asetetaan ajastimen alkuarvo
    setState(() {
      _showMicrophoneUI = true;
    });

    _microphoneTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_microphoneTimeLeft > 0) {
          _microphoneTimeLeft--;
        } else {
          timer.cancel();
          _hideMicrophoneUI(); // Piilotetaan käyttöliittymä, kun ajastin loppuu
        }
      });
    });
  }

  // Piilottaa mikrofonin käyttöliittymän
  void _hideMicrophoneUI() {
    _microphoneTimer?.cancel(); // Varmistetaan, että ajastin on peruutettu
    setState(() {
      _showMicrophoneUI = false;
      _microphoneTimeLeft = 5; // Nollataan ajastimen arvo
    });
  }


  // Vaiheet 3 & 4: käsittelee tunnistetun puhetekstin ja rekisteröi vastauksen
  void _onSpeechResult(String recognized) {
    final input = recognized.toLowerCase().trim();
    final trivia = Provider.of<TriviaTarjoaja>(context, listen: false);
    final kys = trivia.kysymykset[trivia.nykyinenIndeksi];
    final oikea = kys.oikeaVastaus.toLowerCase();

    bool oikein = false;
    if (input == oikea) {
      oikein = true;
    } else {
      for (var v in _vastaukset) {
        if (input == v.toLowerCase()) {
          oikein = v == kys.oikeaVastaus;
          break;
        }
      }
    }

    if (!kysymykseenVastattu) {
      trivia.vastaaKysymykseen(oikein);
      naytaPisteetSnackBar(context, oikein);
      setState(() {
        kysymykseenVastattu = true;
        _isListening = false;
      });
      _timer?.cancel();
      _stopListening(); // Lopetetaan puheentunnistus vastauksen tunnistamisen jälkeen
      _hideMicrophoneUI(); // Piilotetaan käyttöliittymä vastauksen jälkeen
    }
  }

  void naytaPisteetSnackBar(BuildContext context, bool oikein) {
    final snackBar = SnackBar(
      content: Text(
        oikein ? '+20 pistettä!' : '-5 pistettä!',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      backgroundColor: oikein ? Colors.green : Colors.red,
      duration: const Duration(seconds: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void siirryTuloksetNakymaan(TriviaTarjoaja triviaTarjoaja) {
    _timer?.cancel();
    _stopListening();
    _hideMicrophoneUI(); // Piilotetaan käyttöliittymä siirryttäessä
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TuloksetNakyma(
          kayttajaNimi: widget.kayttajaNimi,
          pisteet: triviaTarjoaja.pisteet,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _timer?.cancel();
    _puhe.dispose();
    _listeningStartTimer?.cancel(); // Peruuta käynnistysajastin dispose-metodissa
    _microphoneTimer?.cancel(); // Peruuta mikrofonin ajastin dispose-metodissa
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('TriviaVisa'),
        backgroundColor: Colors.deepPurpleAccent,
        actions: [
          Consumer<AsetuksetTarjoaja>(
            builder: (_, aset, __) {
              if (!aset.kaytaSpeechToText) return const SizedBox();
              return IconButton(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                onPressed: _toggleListening,
              );
            },
          ),
        ],
      ),
      body: Stack(
          children: [
      // Taustakuva
      Container(
      decoration: const BoxDecoration(
      image: DecorationImage(
          image: AssetImage('assets/images/background.jpg'),
      fit: BoxFit.cover,
    ),
    ),
    ),
    // Trivia-pelin sisältö
    Consumer<TriviaTarjoaja>(
    builder: (context, triviaTarjoaja, child) {
    if (triviaTarjoaja.onLataus) {
    return const Center(child: CircularProgressIndicator());
    }
    if (triviaTarjoaja.virhe != null) {
    return Center(
    child: Text(
    triviaTarjoaja.virhe!,
    style: const TextStyle(fontSize: 18, color: Colors.red),
    textAlign: TextAlign.center,
    ),
    );
    }
    if (triviaTarjoaja.kysymykset.isEmpty) {
    return const Center(child: Text("Kysymyksiä ei löytynyt."));
    }
    if (triviaTarjoaja.nykyinenIndeksi >= triviaTarjoaja.kysymykset.length) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
    siirryTuloksetNakymaan(triviaTarjoaja);
    });
    return const SizedBox();
    }

    final kysymys = triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];

    return Column(
    children: [
    const SizedBox(height: 50),
    Text(
    'Tervetuloa, ${widget.kayttajaNimi}!',
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
    textAlign: TextAlign.center,
    ),
    const SizedBox(height: 10),
    Text(
      'Kysymys ${triviaTarjoaja.nykyinenIndeksi + 1}/${triviaTarjoaja.kysymykset.length}',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      textAlign: TextAlign.center,
    ),
      const SizedBox(height: 10),
      Text(
        'Aikaa jäljellä: $_aikaJaljella sekuntia',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.yellow),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kysymys.kysymysTeksti,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Näytetään sekoitetut vastausvaihtoehdot
              ..._vastaukset.map((vastaus) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton(
                    onPressed: kysymykseenVastattu
                        ? null
                        : () {
                      bool oikein = vastaus == kysymys.oikeaVastaus;
                      naytaPisteetSnackBar(context, oikein);
                      triviaTarjoaja.vastaaKysymykseen(oikein);
                      setState(() {
                        kysymykseenVastattu = true;
                      });
                      _timer?.cancel();
                      _stopListening(); // Lopetetaan kuuntelu napin painalluksella
                      _hideMicrophoneUI(); // Piilotetaan käyttöliittymä napin painalluksella
                    },
                    child: Text(vastaus),
                  ),
                );
              }),
              // Seuraava kysymys -painike
              ElevatedButton(
                onPressed: kysymykseenVastattu
                    ? () {
                  setState(() {
                    kysymykseenVastattu = false;
                  });
                  if (triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length - 1) {
                    triviaTarjoaja.seuraavaKysymys();
                    _paivitaVastaukset();
                    _aloitaAikalaskuri();

                    // Vaihe 2 automaattisesti: aloitetaan puhekuuntelu
                    if (Provider.of<AsetuksetTarjoaja>(context, listen: false).kaytaSpeechToText) {
                      // Puheentunnistus käynnistetään nyt _aloitaAikalaskuri:n sisällä viiveellä
                    }
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TuloksetNakyma(
                          kayttajaNimi: widget.kayttajaNimi,
                          pisteet: triviaTarjoaja.pisteet,
                        ),
                      ),
                    );
                  }
                }
                    : null,
                child: const Text('Seuraava kysymys'),
              ),
            ],
          ),
        ),
      ),
    ],
    );
    },
    ),
            // Mikrofonin kuvake ja ajastin (Overlay)
            if (_showMicrophoneUI)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.redAccent : Colors.white,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$_microphoneTimeLeft s',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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