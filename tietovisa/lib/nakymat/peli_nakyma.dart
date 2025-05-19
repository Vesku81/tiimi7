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
  State<PeliNakyma> createState() => _PeliNakymaTila();
}

class _PeliNakymaTila extends State<PeliNakyma> {
  late AudioPlayer _audioPlayer;
  late Puhepalvelu _puhe;
  Timer? _timer;
  int _aikaJaljella = 20;
  bool _kysymykseenVastattu = false;
  bool _isListening = false;
  Timer? _listeningStartTimer;
  Timer? _microphoneTimer;
  int _microphoneTimeLeft = 5;
  bool _showMicrophoneUI = false;

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
        if (!available && mounted) {
          debugPrint('Speech-to-Text ei ole saatavilla');
        }
      });

      Provider.of<TriviaTarjoaja>(context, listen: false)
          .haeKysymykset(5, 'easy', context)
          .then((_) {
        if (mounted) {
          _paivitaVastaukset();
          _aloitaAikalaskuri();
        }
      });
    });
  }

  Future<void> _soitaTaustamusiikki(int voimakkuus) async {
    try {
      await _audioPlayer.setVolume(voimakkuus / 100);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/background_music.mp3'));
    } catch (e) {
      debugPrint("Virhe taustamusiikin soitossa: $e");
    }
  }

  void _paivitaVastaukset() {
    final triviaTarjoaja = Provider.of<TriviaTarjoaja>(context, listen: false);
    if (triviaTarjoaja.kysymykset.isNotEmpty &&
        triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length) {
      final kysymys = triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];
      List<String> sekoitetut = List<String>.from(kysymys.vaaratVastaukset)
        ..add(kysymys.oikeaVastaus)
        ..shuffle();
      if (mounted) {
        setState(() {
          _vastaukset = sekoitetut;
        });
      }
    }
  }

  void _aloitaAikalaskuri() {
    _timer?.cancel();
    _aikaJaljella = 20;
    _kysymykseenVastattu = false;
    _stopListening(); // Varmistaa, että edellinen kuuntelu pysähtyy
    _hideMicrophoneUI(); // Piilottaa mikrofonin UI:n

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_aikaJaljella > 0) {
          _aikaJaljella--;
          if (_aikaJaljella == 10) {
            _startListeningWithDelay();
          }
        } else {
          timer.cancel();
          _lukitseKysymys();
        }
      });
    });
  }

  void _startListeningWithDelay() {
    if (!mounted) return;
    final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
    if (asetukset.kaytaSpeechToText && !_kysymykseenVastattu && !_isListening && _puhe.isInitialized) {
      _listeningStartTimer?.cancel();
      _listeningStartTimer = Timer(const Duration(seconds: 0), () {
        if (mounted) {
          _startListening();
          _showMicrophoneUIWithTimer();
        }
      });
    }
  }

  void _lukitseKysymys() {
    if (!_kysymykseenVastattu) {
      if (!mounted) return;
      final triviaTarjoaja = Provider.of<TriviaTarjoaja>(context, listen: false);
      String vastausKunAikaLoppuu = "_AIKA_LOPPUI_";
      if (triviaTarjoaja.kysymykset.isNotEmpty && triviaTarjoaja.nykyinenIndeksi < triviaTarjoaja.kysymykset.length) {
        final oikeaVastaus = triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi].oikeaVastaus;
        if (vastausKunAikaLoppuu == oikeaVastaus) {
          vastausKunAikaLoppuu = "__AIKA_LOPPUI_ERIKOISMERKKIJONO__";
        }
      }
      triviaTarjoaja.vastaaKysymykseen(vastausKunAikaLoppuu);
      naytaPisteetSnackBar(context, false);
      if (mounted) {
        setState(() {
          _kysymykseenVastattu = true;
        });
      }
      _stopListening();
      _hideMicrophoneUI();
    }
  }

  void _toggleListening() {
    if (!mounted) return;
    if (_isListening) {
      _stopListening();
      _hideMicrophoneUI();
    } else {
      final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
      if (asetukset.kaytaSpeechToText && !_kysymykseenVastattu &&_puhe.isInitialized) {
  _startListening();
  _showMicrophoneUIWithTimer();
  } else if (!asetukset.kaytaSpeechToText) {
  debugPrint("Puheentunnistus ei ole käytössä asetuksista.");
  // Voitaisiin näyttää SnackBar käyttäjälle
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text("Puheentunnistus ei ole käytössä asetuksista.")),
  );
  } else if (_kysymykseenVastattu) {
  debugPrint("Kysymykseen on jo vastattu, ei voida käynnistää puheentunnistusta.");
  } else if (!_puhe.isInitialized) {
  debugPrint("Puhepalvelu ei ole alustettu.");
  }
  }
}

void _startListening() async {
  // Tarkistukset on jo tehty _toggleListening tai _startListeningWithDelay -metodeissa,
  // mutta varmistetaan vielä tässäkin, erityisesti _kysymykseenVastattu.
  if (!mounted || _kysymykseenVastattu || _isListening || !_puhe.isInitialized) return;

  final asetukset = Provider.of<AsetuksetTarjoaja>(context, listen: false);
  if (asetukset.kaytaSpeechToText) {
    _puhe.startListening(onResult: _onSpeechResult);
    setState(() {
      _isListening = true;
    });
  }
}

void _stopListening() {
  if (!mounted) return;
  _puhe.stopListening();
  _listeningStartTimer?.cancel();
  _microphoneTimer?.cancel();
  // Varmistetaan, että setState kutsutaan vain, jos tila todella muuttuu
  if (_isListening || _showMicrophoneUI) {
    setState(() {
      _isListening = false;
      // _showMicrophoneUI piilotetaan _hideMicrophoneUI:ssa,
      // mutta voidaan varmistaa tässäkin, jos kutsutaan erikseen.
    });
  }
  // _hideMicrophoneUI(); // Yleensä kutsutaan erikseen, mutta voidaan lisätä tännekin tarvittaessa
}

void _showMicrophoneUIWithTimer() {
  if (!mounted) return;
  _microphoneTimer?.cancel();
  _microphoneTimeLeft = 5;
  setState(() {
    _showMicrophoneUI = true;
  });

  _microphoneTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    setState(() {
      if (_microphoneTimeLeft > 0) {
        _microphoneTimeLeft--;
      } else {
        timer.cancel();
        _hideMicrophoneUI();
        // Jos mikrofoniaika loppuu, eikä kuuntelu ole jo loppunut, lopetetaan se.
        if (_isListening) {
          _stopListening();
        }
      }
    });
  });
}

void _hideMicrophoneUI() {
  if (!mounted) return;
  _microphoneTimer?.cancel();
  if (_showMicrophoneUI) { // Päivitetään tila vain jos se muuttuu
    setState(() {
      _showMicrophoneUI = false;
    });
  }
  // _microphoneTimeLeft = 5; // Nollaus voidaan tehdä _showMicrophoneUIWithTimer:ssa
}

void _onSpeechResult(String recognized) {
  if (!mounted || _kysymykseenVastattu) return;

  final input = recognized.toLowerCase().trim();
  final trivia = Provider.of<TriviaTarjoaja>(context, listen: false);

  if (trivia.kysymykset.isEmpty || trivia.nykyinenIndeksi >= trivia.kysymykset.length) {
    debugPrint("Puheentunnistustulos, mutta kysymysdataa ei saatavilla.");
    _stopListening(); // Pysäytä kuuntelu, jos jotain meni pieleen
    _hideMicrophoneUI();
    return;
  }
  final kys = trivia.kysymykset[trivia.nykyinenIndeksi];
  final oikeaVastausTeksti = kys.oikeaVastaus;
  final oikeaNormalisoitu = oikeaVastausTeksti.toLowerCase();

  String valittuVastausPuheella = input;
  bool oliOikein = false;

  if (input == oikeaNormalisoitu) {
    oliOikein = true;
    valittuVastausPuheella = oikeaVastausTeksti;
  } else {
    for (var vaihtoehto in _vastaukset) {
      if (input == vaihtoehto.toLowerCase()) {
        valittuVastausPuheella = vaihtoehto;
        oliOikein = (vaihtoehto == oikeaVastausTeksti);
        break;
      }
    }
  }
  // Jos _kysymykseenVastattu on jo true (esim. käyttäjä ehti painaa nappia), älä tee mitään.
  // Tämä tarkistus on jo metodin alussa, mutta tuplavarmistus ei haittaa.
  if (!_kysymykseenVastattu) {
    trivia.vastaaKysymykseen(valittuVastausPuheella);
    naytaPisteetSnackBar(context, oliOikein);
    setState(() {
      _kysymykseenVastattu = true;
    });
    _timer?.cancel();
    _stopListening();
    _hideMicrophoneUI();
  }
}

void naytaPisteetSnackBar(BuildContext context, bool oikein) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Poista edellinen, jos on
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
  if (!mounted) return;
  _timer?.cancel();
  _stopListening();
  _hideMicrophoneUI();
  // Varmistetaan, ettei yritetä navigoida, jos ollaan jo poistumassa
  if (ModalRoute.of(context)?.isCurrent ?? false) {
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

@override
void dispose() {
  _audioPlayer.dispose();
  _timer?.cancel();
  _puhe.dispose();
  _listeningStartTimer?.cancel();
  _microphoneTimer?.cancel();
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
            if (!aset.kaytaSpeechToText) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              tooltip: _isListening ? "Lopeta kuuntelu" : "Aloita kuuntelu",
              onPressed: _toggleListening,
            );
          },
        ),
      ],
    ),
    body: Stack(
        children: [
    Container(
    decoration: const BoxDecoration(
    image: DecorationImage(
        image: AssetImage('assets/images/background.jpg'),
    fit: BoxFit.cover,
  ),
  ),
  ),

          Consumer<TriviaTarjoaja>(
            builder: (context, triviaTarjoaja, child) {
              if (triviaTarjoaja.onLataus) {
                return const Center(child: CircularProgressIndicator());
              }
              if (triviaTarjoaja.virhe != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      triviaTarjoaja.virhe!,
                      style: const TextStyle(
                          fontSize: 18,
                          color: Colors.red,
                          backgroundColor: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (triviaTarjoaja.kysymykset.isEmpty) {
                return const Center(
                    child: Text("Kysymyksiä ei löytynyt.",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            backgroundColor: Colors.black54)));
              }
              if (triviaTarjoaja.nykyinenIndeksi >=
                  triviaTarjoaja.kysymykset.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    siirryTuloksetNakymaan(triviaTarjoaja);
                  }
                });
                return const Center(
                    child: Text("Ladataan tuloksia...",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            backgroundColor: Colors.black54)));
              }

              final kysymys =
              triviaTarjoaja.kysymykset[triviaTarjoaja.nykyinenIndeksi];

              return Column(
                children: [
                  const SizedBox(height: 50),
                  Text(
                    'Tervetuloa, ${widget.kayttajaNimi}!',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Kysymys ${triviaTarjoaja.nykyinenIndeksi + 1}/${triviaTarjoaja.kysymykset.length}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aikaa jäljellä: $_aikaJaljella sekuntia',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow),
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
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Text(
                              kysymys.kysymysTeksti,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ..._vastaukset.map((vastausTeksti) {
                            return Container(
                              margin:
                              const EdgeInsets.symmetric(vertical: 8.0),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15.0),
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                                onPressed: _kysymykseenVastattu
                                    ? null
                                    : () {
                                  triviaTarjoaja.vastaaKysymykseen(
                                      vastausTeksti);
                                  bool oliOikein = vastausTeksti ==
                                      kysymys.oikeaVastaus;
                                  naytaPisteetSnackBar(
                                      context, oliOikein);

                                  setState(() {
                                    _kysymykseenVastattu = true;
                                  });
                                  _timer?.cancel();
                                  _stopListening();
                                  _hideMicrophoneUI();
                                },
                                child: Text(vastausTeksti),
                              ),
                            );
                          }),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15.0),
                              textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            onPressed: _kysymykseenVastattu
                                ? () {
                              if (triviaTarjoaja
                                  .onkoViimeinenKysymys()) {
                                siirryTuloksetNakymaan(triviaTarjoaja);
                              } else {
                                triviaTarjoaja.seuraavaKysymys();
                                _paivitaVastaukset();
                                _aloitaAikalaskuri();
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
                        color:
                        _isListening ? Colors.redAccent : Colors.white,
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